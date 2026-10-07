import json
import tempfile
import unittest
from pathlib import Path
from remote_catalog_metadata import metadata, ROOT

class RemoteMetadataTests(unittest.TestCase):
    def test_local_metadata_without_rewriting_source(self):
        path = ROOT / 'LifeIsLearned/Resources/starter.json'
        before = path.read_bytes()
        result = metadata(path, 'https://example.com/releases/book.json')
        self.assertEqual(result['id'], 'influential-mind')
        self.assertEqual(result['package']['bytes'], len(before))
        self.assertEqual(len(result['package']['sha256']), 64)
        self.assertEqual(path.read_bytes(), before)
    def test_rejects_unknown_id_http_and_incomplete_thumbnail(self):
        path = ROOT / 'LifeIsLearned/Resources/starter.json'
        for kwargs in [dict(url='http://example.com/book'), dict(url='https://example.com/book', thumbnail='cover.jpg')]:
            with self.assertRaises(ValueError): metadata(path, **kwargs)
        package = json.loads(path.read_text()); package['book']['id'] = 'new-unapproved-id'
        with tempfile.TemporaryDirectory() as directory:
            file = Path(directory) / 'book.json'; file.write_text(json.dumps(package))
            with self.assertRaisesRegex(ValueError, 'IDs are never rewritten'): metadata(file, 'https://example.com/book')

if __name__ == '__main__': unittest.main()
