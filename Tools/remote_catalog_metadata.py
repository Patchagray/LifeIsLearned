#!/usr/bin/env python3
"""Print verified release metadata; never publishes or edits package/identity IDs."""
import argparse
import hashlib
import json
from pathlib import Path
from urllib.parse import urlparse
from validate_package import content, read_package

ROOT = Path(__file__).resolve().parents[1]

def asset(path, url, limit):
    parsed = urlparse(url)
    if parsed.scheme != 'https' or not parsed.hostname or parsed.username or parsed.password:
        raise ValueError('Asset URL must use HTTPS without credentials')
    data = Path(path).read_bytes()
    if not 0 < len(data) <= limit:
        raise ValueError('Asset exceeds its byte budget')
    return dict(url=url, sha256=hashlib.sha256(data).hexdigest(), bytes=len(data))

def metadata(path, url, thumbnail=None, thumbnail_url=None):
    package, _ = read_package(Path(path))
    # Runtime-compatible validation; this helper does not certify editorial/release timing review.
    content(package)
    if package.get('formatVersion') != 2:
        raise ValueError('Remote distribution requires formatVersion 2')
    approved = json.loads((ROOT / 'Catalog/Catalog-001.json').read_text())
    book_id = package['book']['id']
    if book_id not in {book['id'] for book in approved['books']}:
        raise ValueError('Package ID is not in Catalog 001; IDs are never rewritten')
    result = {'id': book_id, 'package': dict(collectionRevision=package['collectionRevision'], **asset(path, url, 64 * 1024 * 1024))}
    if bool(thumbnail) != bool(thumbnail_url):
        raise ValueError('Supply both thumbnail file and URL')
    if thumbnail:
        result['thumbnail'] = asset(thumbnail, thumbnail_url, 512 * 1024)
    return result

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('package'); parser.add_argument('--url', required=True)
    parser.add_argument('--thumbnail'); parser.add_argument('--thumbnail-url')
    parser.add_argument('--verify-catalog', help='Require the matching catalog entry to equal generated package/thumbnail metadata')
    args = parser.parse_args()
    try:
        result = metadata(args.package, args.url, args.thumbnail, args.thumbnail_url)
        if args.verify_catalog:
            catalog = json.loads(Path(args.verify_catalog).read_text())
            matches = [book for book in catalog['books'] if book['id'] == result['id']]
            if len(matches) != 1 or any(matches[0].get(key) != value for key, value in result.items()):
                raise ValueError('Catalog metadata differs from the final local files')
        print(json.dumps(result, indent=2))
    except (ValueError, KeyError, OSError) as error:
        parser.exit(1, str(error) + '\n')
