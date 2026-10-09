#!/usr/bin/env python3
"""Prepare exact public-release bytes; publish only with a matching owner approval file.

Publication approval is a human decision, never inferred from validator success.
This tool creates versioned draft releases then publishes after upload. It never
clobbers assets or pushes a catalog automatically.
"""
import argparse
import hashlib
import json
import re
import shutil
import subprocess
import tempfile
import urllib.request
from pathlib import Path
from distribution_catalog import REPOSITORY, ROOT, load, validate, require, url, audit_directory
from remote_catalog_metadata import metadata
from validate_package import read_package, content, authoring_art_and_stages
from lesson_timing import package_report, planning_errors


def run(*args):
    return subprocess.run(args, check=True, capture_output=True, text=True).stdout.strip()


def public_payload_check(package):
    require(set(package) <= {'formatVersion','book','collectionRevision','fullCollection','manifest','removedLessonIDs','assets','audioAssets'}, 'Remove unreviewed production fields before release review; never silently strip them')
    forbidden = {'apikey','token','password','secret','systemprompt','prompts','voiceconfig','researchdossier','productionnotes'}
    def inspect(value):
        if isinstance(value, dict):
            for key, child in value.items():
                require(re.sub(r'[^a-z]', '', key.lower()) not in forbidden, 'Potential private production/credential field; review required')
                # Approved embedded bytes are reviewed as assets; do not pattern-match base64.
                if key != 'data': inspect(child)
        elif isinstance(value, list):
            for child in value: inspect(child)
        elif isinstance(value, str):
            require(not re.search(r'(gh[pousr]_[A-Za-z0-9]{20,}|github_pat_|sk_[A-Za-z0-9]{20,}|https://(?:github.com|raw.githubusercontent.com)/Patchagray/(?:LifeIsLearned/|life-is-learned-books/))', value, re.I), 'Potential credential/private production URL; review required')
    inspect(package)


def prepare(package_file, output):
    package_file = Path(package_file)
    p, _ = read_package(package_file); content(p); public_payload_check(p)
    errors, _ = authoring_art_and_stages(p)
    errors += planning_errors(p, package_report(p))
    require(not errors, 'Authoring gate failed: ' + '; '.join(errors))
    if p.get('audioAssets') or any(l.get('narration') for l in p['book']['lessons']):
        from narration_audio import audio_report
        audio = audio_report(p)
        require(not audio['assetErrors'] and all(i['premiumNarration'] == 'complete' and i.get('measuredCoreSeconds', 0) <= 300 for i in audio['ideas']), 'Packaged narration is incomplete, invalid or over budget')
    book_id, revision = p['book']['id'], p['collectionRevision']
    tag = f'{book_id}-r{revision}'
    name = f'{tag}.json'
    result = metadata(package_file, f'https://github.com/{REPOSITORY}/releases/download/{tag}/{name}')
    # Refuse silent overwrite of review bytes. Internal output stays outside public repo.
    output = Path(output); output.mkdir(parents=True, exist_ok=False)
    target = output/name; shutil.copyfile(package_file, target)
    report = dict(repository=REPOSITORY, tag=tag, filename=name, title=p['book']['title'],
                  **result, images=len(p.get('assets', {})), audioAssets=len(p.get('audioAssets', {})),
                  publicExposure='All embedded lesson text, images and MP3 narration are publicly extractable.')
    (output/'release-manifest.json').write_text(json.dumps(report, indent=2)+'\n')
    return report


class PublicRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        from urllib.parse import urlsplit
        p = urlsplit(newurl)
        require(p.scheme == 'https' and p.hostname in ('release-assets.githubusercontent.com', 'objects.githubusercontent.com', 'github.com', 'raw.githubusercontent.com') and p.port in (None, 443) and not p.username and not p.password, 'Unsafe GitHub CDN redirect')
        if p.hostname in ('github.com', 'raw.githubusercontent.com'): url(newurl)
        return super().redirect_request(req, fp, code, msg, headers, newurl)


def verify_download(asset):
    url(asset['url'], release=True)
    request = urllib.request.Request(asset['url'], headers={'User-Agent': 'LifeIsLearned-Public-Verification'})
    # No auth headers or credentials; bounded streaming through approved HTTPS CDN.
    digest, count = hashlib.sha256(), 0
    with urllib.request.build_opener(PublicRedirect()).open(request, timeout=60) as response:
        while chunk := response.read(64*1024):
            count += len(chunk); require(count <= asset['bytes'], 'Download larger than manifest')
            digest.update(chunk)
    require(count == asset['bytes'] and digest.hexdigest() == asset['sha256'], 'Anonymous release checksum/size mismatch')


def publish(review_directory, approval_file, public_directory):
    directory, public = Path(review_directory), Path(public_directory)
    manifest, approval = load(directory/'release-manifest.json'), load(approval_file)
    require(manifest['repository'] == REPOSITORY, 'Wrong distribution repository')
    require(approval.get('repository') == REPOSITORY and approval.get('publicRepositoryApproved') is True, 'Owner repository approval required')
    require(any(a.get('id') == manifest['id'] and a.get('collectionRevision') == manifest['package']['collectionRevision'] and
                a.get('sha256') == manifest['package']['sha256'] and a.get('bytes') == manifest['package']['bytes'] and
                a.get('publicRedistributionApproved') is True and a.get('rightsIncludingImagesAndNarrationConfirmed') is True and
                a.get('releaseQAApproved') is True for a in approval.get('books', [])), 'Exact-byte owner rights/publication and release QA approval required')
    filename = f"{manifest['id']}-r{manifest['package']['collectionRevision']}.json"
    require(manifest['filename'] == filename and manifest['tag'] == filename[:-5], 'Unexpected release filename/tag')
    source = directory/filename
    public_payload_check(read_package(source)[0])
    require(metadata(source, manifest['package']['url']) == {'id': manifest['id'], 'package': manifest['package']}, 'Review bytes changed')
    audit_directory(public)
    require(run('git', '-C', str(public), 'remote', 'get-url', 'origin') in (f'https://github.com/{REPOSITORY}.git', f'git@github.com:{REPOSITORY}.git'), 'Wrong public working copy')
    require(not run('git', '-C', str(public), 'status', '--porcelain'), 'Public worktree must be clean')
    old = load(public/'catalog.json'); revised = json.loads(json.dumps(old))
    book = next(b for b in revised['books'] if b['id'] == manifest['id'])
    from datetime import datetime, timezone
    now = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
    approved_package, _ = read_package(source)
    book.update(availability='available', package=manifest['package'], updatedAt=now, description=approved_package['book']['synopsis'])
    revised['updatedAt'] = now; validate(revised, old)
    visibility = json.loads(run('gh','repo','view',REPOSITORY,'--json','visibility'))['visibility']
    require(visibility == 'PUBLIC', 'Distribution repository must be public')
    immutable = json.loads(run('gh','api',f'repos/{REPOSITORY}/immutable-releases'))
    require(immutable.get('enabled') is True, 'Enable immutable releases in GitHub repository Settings first')
    # An existing tag/release is a hard stop. No --clobber, deletion, or force update.
    existing = subprocess.run(['gh','release','view',manifest['tag'],'--repo',REPOSITORY], capture_output=True)
    require(existing.returncode != 0, 'Release already exists; inspect it manually, never overwrite')
    notes = 'Approved prepared learning collection. Embedded text, illustrations and narration are publicly downloadable. SHA-256: ' + manifest['package']['sha256']
    with tempfile.TemporaryDirectory() as scratch:
        note = Path(scratch)/'notes.md'; note.write_text(notes+'\n')
        run('gh','release','create',manifest['tag'],str(source),'--repo',REPOSITORY,'--draft','--title',f"{manifest['title']} · collection {manifest['package']['collectionRevision']}",'--notes-file',str(note),'--target','main')
    run('gh','release','edit',manifest['tag'],'--repo',REPOSITORY,'--draft=false')
    verify_download(manifest['package'])
    raw = (json.dumps(revised,ensure_ascii=False,indent=2)+'\n').encode()
    (public/'catalog.json').write_bytes(raw)
    (public/'checksums.json').write_text(json.dumps({'catalog.json':hashlib.sha256(raw).hexdigest()},indent=2)+'\n')
    audit_directory(public)
    return {'published': manifest['package']['url'], 'catalog': 'Updated locally. Review, commit and push catalog.json/checksums.json explicitly.'}

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    p = commands.add_parser('prepare'); p.add_argument('package'); p.add_argument('--output', required=True)
    p = commands.add_parser('publish'); p.add_argument('review_directory'); p.add_argument('--approval', required=True); p.add_argument('--public-directory', required=True)
    args = parser.parse_args()
    try:
        result = prepare(args.package,args.output) if args.command == 'prepare' else publish(args.review_directory,args.approval,args.public_directory)
        print(json.dumps(result,indent=2))
    except (ValueError, OSError, KeyError, subprocess.CalledProcessError) as e: parser.exit(1, str(e)+'\n')
