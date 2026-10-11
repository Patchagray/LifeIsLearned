import base64
import hashlib
import json
import tempfile
import unittest
from pathlib import Path
from extract_catalog_cover import extract

PNG = base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=')

class CatalogCoverTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.package = {'formatVersion': 2, 'book': {'id': 'thanks-for-the-feedback', 'coverAssetID': 'cover'},
                        'assets': {'cover': {'mediaType': 'image/png', 'data': base64.b64encode(PNG).decode()}}}
    def run_extract(self):
        path = self.root / 'book.json'
        path.write_text(json.dumps(self.package))
        return extract(path, self.root / 'covers')
    def test_exact_bytes_repeatable_and_no_approval_invented(self):
        entry = self.run_extract()
        self.assertEqual((self.root / entry['path']).read_bytes(), PNG)
        self.assertEqual(entry['sha256'], hashlib.sha256(PNG).hexdigest())
        self.assertEqual(entry, self.run_extract())
        self.assertFalse((self.root / entry['approvalRecord']).exists())
    def test_missing_cover_rejected(self):
        self.package['book'].pop('coverAssetID')
        with self.assertRaisesRegex(ValueError, 'no referenced cover'): self.run_extract()
    def test_unknown_identity_rejected(self):
        self.package['book']['id'] = '../unapproved'
        with self.assertRaisesRegex(ValueError, 'Unknown canonical'): self.run_extract()
    def test_budget_and_media_mismatch_rejected(self):
        self.package['assets']['cover']['mediaType'] = 'image/jpeg'
        with self.assertRaisesRegex(ValueError, 'media type'): self.run_extract()
        self.package['assets']['cover']['data'] = base64.b64encode(b'x' * (512 * 1024 + 1)).decode()
        with self.assertRaisesRegex(ValueError, '512 KiB'): self.run_extract()

if __name__ == '__main__': unittest.main()
