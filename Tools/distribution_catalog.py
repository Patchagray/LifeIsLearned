#!/usr/bin/env python3
"""Validate public catalog metadata and assemble an allowlisted distribution scaffold."""
import argparse
import hashlib
import json
import re
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlsplit, unquote
from validate_package import unique_object

ROOT = Path(__file__).resolve().parents[1]
REPOSITORY = 'Patchagray/LifeIsLearned-Catalog'
PUBLIC_FILES = {'README.md', 'catalog.json', 'checksums.json'}
BOOK_KEYS = {'id', 'title', 'authors', 'primaryShelfID', 'secondaryShelfIDs', 'tags', 'isbn13', 'availability', 'thumbnail', 'package', 'description', 'updatedAt'}

def require(value, message):
    if not value: raise ValueError(message)

def load(path):
    return json.loads(Path(path).read_text(), object_pairs_hook=unique_object)

def url(value, release=False):
    p = urlsplit(value)
    prefix = '/' + REPOSITORY + '/'
    require(p.scheme == 'https' and not p.username and not p.password and p.port in (None, 443) and not p.query and not p.fragment, 'Use HTTPS without credentials, queries or fragments')
    require(not any(c in ('.', '..') for c in unquote(p.path).split('/')), 'Unsafe URL path')
    allowed = p.hostname == 'github.com' and p.path.startswith(prefix + 'releases/download/')
    if not release: allowed |= p.hostname == 'raw.githubusercontent.com' and p.path.startswith(prefix)
    require(allowed, 'URL must point to the public distribution repository')

def timestamp(value):
    require(isinstance(value, str) and re.fullmatch(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z', value) is not None, 'updatedAt must be a UTC ISO-8601 timestamp')
    datetime.fromisoformat(value.replace('Z', '+00:00'))

def asset(value, limit, package=False):
    expected = {'url', 'sha256', 'bytes'} | ({'collectionRevision'} if package else set())
    require(set(value) == expected, 'Unexpected or missing public asset fields')
    url(value['url'], release=package)
    require(type(value['bytes']) is int and 0 < value['bytes'] <= limit, 'Invalid asset byte budget')
    require(re.fullmatch('[a-f0-9]{64}', value['sha256']) is not None, 'Invalid SHA-256')
    if package: require(type(value['collectionRevision']) is int and value['collectionRevision'] > 0, 'Invalid collection revision')

def validate(catalog, previous=None):
    identity = load(ROOT / 'Catalog/Catalog-001.json')
    require(set(catalog) == {'schemaVersion', 'catalogID', 'catalogRevision', 'updatedAt', 'shelves', 'books'}, 'Unexpected or missing catalog fields')
    require(catalog['schemaVersion'] == 1 and catalog['catalogID'] == 'catalog-001' and catalog['catalogRevision'] == 1, 'Unsupported catalog revision/schema')
    require(catalog['shelves'] == identity['shelves'], 'Canonical eight shelves and physical order must be preserved')
    timestamp(catalog['updatedAt'])
    require(len(json.dumps(catalog).encode()) <= 2 * 1024 * 1024, 'Catalog exceeds 2 MiB')
    approved = {b['id']: b for b in identity['books']}
    order = {b['id']: i for i, b in enumerate(identity['books'])}
    ids = [b['id'] for b in catalog['books']]
    require(len(ids) == len(set(ids)) and all(i in approved for i in ids), 'Unknown/duplicate stable book identity')
    require(ids == sorted(ids, key=order.get), 'Preserve canonical book order')
    for b in catalog['books']:
        require(set(b) <= BOOK_KEYS and {'id','title','authors','primaryShelfID','secondaryShelfIDs','tags','isbn13','availability','updatedAt'} <= set(b), 'Unexpected or missing book fields')
        for key in ('primaryShelfID', 'secondaryShelfIDs', 'tags'):
            require(b[key] == approved[b['id']][key], 'Do not change editorial shelves or tags')
        require(isinstance(b['title'], str) and b['title'].strip() and b['authors'] and all(isinstance(a, str) and a.strip() for a in b['authors']), 'Title and authors required')
        require(b['availability'] in ('available','planned','unavailable'), 'Invalid availability')
        require((b['availability'] == 'available') == ('package' in b), 'Only available titles have downloadable package metadata')
        for isbn in b['isbn13']:
            require(re.fullmatch(r'97[89]\d{10}', isbn) and sum(int(c)*(1 if i%2 == 0 else 3) for i,c in enumerate(isbn))%10 == 0, 'Invalid ISBN-13')
        timestamp(b['updatedAt'])
        if 'package' in b: asset(b['package'], 64*1024*1024, package=True)
        if 'thumbnail' in b: asset(b['thumbnail'], 512*1024)
    # Public metadata may not contain source-repository links or credential-shaped values.
    text = json.dumps(catalog)
    require(not re.search(r'(gh[pousr]_[A-Za-z0-9]{20,}|github_pat_|sk_[A-Za-z0-9]{20,}|api[_-]?key|/LifeIsLearned/|/life-is-learned-books)', text, re.I), 'Private-source URL or credential-shaped metadata')
    if previous:
        validate(previous)
        require(catalog['updatedAt'] >= previous['updatedAt'], 'Catalog timestamp regressed')
        old = {b['id']: b.get('package') for b in previous['books']}
        for b in catalog['books']:
            new, before = b.get('package'), old.get(b['id'])
            if new and before:
                require(new['collectionRevision'] >= before['collectionRevision'], 'Package revision downgrade')
                if new['collectionRevision'] == before['collectionRevision']:
                    require(new == before, 'Published revision is immutable; bump collection revision')
    return catalog

def audit_directory(directory):
    directory = Path(directory)
    files = {p.relative_to(directory).as_posix() for p in directory.rglob('*') if p.is_file() and '.git' not in p.relative_to(directory).parts}
    require(files == PUBLIC_FILES, 'Public scaffold allows only README.md, catalog.json, checksums.json')
    require(not any(p.is_symlink() for p in directory.rglob('*') if '.git' not in p.relative_to(directory).parts), 'No symlinks in public scaffold')
    validate(load(directory / 'catalog.json'))
    expected = {'catalog.json': hashlib.sha256((directory/'catalog.json').read_bytes()).hexdigest()}
    require(load(directory/'checksums.json') == expected, 'Catalog checksum mismatch')
    return sorted(files)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('catalog', type=Path)
    parser.add_argument('--previous', type=Path)
    parser.add_argument('--audit-directory', type=Path)
    args = parser.parse_args()
    try:
        value = validate(load(args.catalog), load(args.previous) if args.previous else None)
        files = audit_directory(args.audit_directory) if args.audit_directory else None
        print(json.dumps({'valid': True, 'titles': len(value['books']), 'available': sum(b['availability']=='available' for b in value['books']), 'publicFiles': files}, indent=2))
    except (ValueError, KeyError, TypeError, OSError) as e: parser.exit(1, str(e)+'\n')
