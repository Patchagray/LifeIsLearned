#!/usr/bin/env python3
"""Extract a package's existing cover and print registry metadata; never publish or approve."""
import argparse
import base64
import hashlib
import json
from pathlib import Path
from validate_package import ROOT, dimensions, read_package


def extract(package_path, output_directory):
    package, _ = read_package(Path(package_path))
    if package.get('formatVersion') != 2:
        raise ValueError('Catalog covers require a formatVersion 2 package')
    book = package['book']
    book_id = book['id']
    canonical = json.loads((ROOT / 'Catalog/Catalog-001.json').read_text())
    if book_id not in {b['id'] for b in canonical['books']}:
        raise ValueError('Unknown canonical book ID; IDs are never rewritten')
    asset = package.get('assets', {}).get(book.get('coverAssetID'))
    if not asset:
        raise ValueError('Package has no referenced cover asset')
    raw = base64.b64decode(asset['data'], validate=True)
    if not 0 < len(raw) <= 512 * 1024:
        raise ValueError('Catalog cover exceeds the 512 KiB budget; prepare a reviewed thumbnail')
    media_type, (width, height) = dimensions(raw)
    if media_type != asset['mediaType'] or not (0 < width <= 2048 and 0 < height <= 2048):
        raise ValueError('Cover media type or dimensions are invalid')
    digest = hashlib.sha256(raw).hexdigest()
    extension = 'png' if media_type == 'image/png' else 'jpg'
    filename = f'{book_id}-{digest}.{extension}'
    output = Path(output_directory) / filename
    if output.exists() and output.read_bytes() != raw:
        raise ValueError('Refusing to overwrite differing cover bytes')
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(raw)
    return dict(bookID=book_id, path='covers/' + filename, mediaType=media_type,
                bytes=len(raw), sha256=digest,
                approvalRecord=f'approvals/{book_id}-cover-{digest}.json')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('package', type=Path)
    parser.add_argument('--output-directory', type=Path, required=True)
    args = parser.parse_args()
    try:
        print(json.dumps(extract(args.package, args.output_directory), indent=2))
    except (ValueError, KeyError, TypeError, IndexError, OSError) as error:
        parser.exit(1, str(error) + '\n')


if __name__ == '__main__':
    main()
