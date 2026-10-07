import json
import tempfile
import subprocess
import sys
import unittest
from pathlib import Path
from remote_catalog_metadata import metadata, ROOT

class RemoteMetadataTests(unittest.TestCase):
    def test_discovery_and_backend_reuse_all_approved_ids(self):
        approved = [b['id'] for b in json.loads((ROOT/'Catalog/Catalog-001.json').read_text())['books']]
        remote = json.loads((ROOT/'Catalog/Remote-Catalog-001.json').read_text())
        self.assertEqual([b['id'] for b in remote['books']], approved)
        self.assertEqual(json.loads((ROOT/'Backend/RequestAPI/catalog-ids.json').read_text()), approved)
        self.assertTrue(all(b['availability'] == 'planned' and not b.get('package') for b in remote['books']))

    def test_verify_catalog_cli_accepts_exact_bytes_and_rejects_changed_hash(self):
        package = ROOT / 'LifeIsLearned/Resources/starter.json'
        url = 'https://example.com/book.json'
        entry = metadata(package, url)
        with tempfile.TemporaryDirectory() as directory:
            catalog = Path(directory) / 'catalog.json'
            catalog.write_text(json.dumps({'books': [entry]}))
            command = [sys.executable, str(ROOT/'Tools/remote_catalog_metadata.py'), str(package), '--url', url, '--verify-catalog', str(catalog)]
            self.assertEqual(subprocess.run(command, capture_output=True).returncode, 0)
            entry['package']['sha256'] = '0'*64
            catalog.write_text(json.dumps({'books': [entry]}))
            self.assertNotEqual(subprocess.run(command, capture_output=True).returncode, 0)

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
