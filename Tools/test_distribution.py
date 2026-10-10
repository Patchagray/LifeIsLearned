import copy
import hashlib
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from distribution_catalog import ROOT, REPOSITORY, load, validate, audit_directory, url
from publish_distribution import publish, prepare, public_payload_check
from types import SimpleNamespace
import test_authoring

class DistributionTests(unittest.TestCase):
    def setUp(self): self.catalog = load(ROOT/'Distribution/catalog.json')
    def test_allowlisted_scaffold_and_planned_states(self):
        self.assertEqual(audit_directory(ROOT/'Distribution'), ['README.md','catalog.json','checksums.json'])
        self.assertEqual(len(validate(self.catalog)['books']), 50)
        self.assertTrue(all(b['availability']=='planned' and 'package' not in b for b in self.catalog['books']))
    def test_public_origins_reject_source_repo_and_credentials(self):
        url(f'https://github.com/{REPOSITORY}/releases/download/book-r1/book-r1.json', True)
        for value in ['http://github.com/a/b', 'https://github.com/Patchagray/LifeIsLearned/releases/download/book/book.json', f'https://user:secret@github.com/{REPOSITORY}/releases/download/book/book.json', f'https://raw.githubusercontent.com/{REPOSITORY}/main/../private', 'https://github.com.evil.test/Patchagray/LifeIsLearned-Catalog/releases/download/a/b']:
            with self.assertRaises(ValueError): url(value)
    def test_unknown_duplicate_order_shelves_and_status(self):
        for mutate in [lambda c:c.update(catalogRevision=2),lambda c:c['books'][0].update(id='unknown'),lambda c:c['books'].append(c['books'][0]), lambda c:c['books'].reverse(),lambda c:c['shelves'].reverse(),lambda c:c['books'][0].update(availability='available'),lambda c:c['books'][0].update(primaryShelfID='bad')]:
            value=copy.deepcopy(self.catalog);mutate(value)
            with self.assertRaises(ValueError):validate(value)
    def test_immutable_revisions_and_budgets(self):
        c=self.catalog; b=c['books'][0]
        b.update(availability='available',package=dict(collectionRevision=2,url=f'https://github.com/{REPOSITORY}/releases/download/book-r2/book-r2.json',sha256='a'*64,bytes=100))
        validate(c)
        for field,value in [('collectionRevision',1),('sha256','b'*64),('bytes',101),('bytes',64*1024*1024+1)]:
            revised=copy.deepcopy(c);revised['books'][0]['package'][field]=value
            with self.assertRaises(ValueError):validate(revised,c)
        revised=copy.deepcopy(c);revised['books'][0]['package'].update(collectionRevision=3,sha256='b'*64)
        validate(revised,c)
    def test_public_tree_rejects_extra_production_file(self):
        with tempfile.TemporaryDirectory() as d:
            for p in (ROOT/'Distribution').iterdir(): (Path(d)/p.name).write_bytes(p.read_bytes())
            (Path(d)/'voice-config.json').write_text('{}')
            with self.assertRaises(ValueError):audit_directory(d)
    def test_publication_requires_exact_human_approval_before_any_command(self):
        with tempfile.TemporaryDirectory() as d, patch('publish_distribution.run') as command:
            p=Path(d); (p/'release-manifest.json').write_text(json.dumps({'repository':REPOSITORY,'id':'atomic-habits','package':{'collectionRevision':1,'sha256':'a'*64,'bytes':10}}))
            (p/'approval.json').write_text(json.dumps({'repository':REPOSITORY,'publicRepositoryApproved':True,'books':[]}))
            with self.assertRaisesRegex(ValueError,'006B retired'):publish(p,p/'approval.json',ROOT/'Distribution')
            command.assert_not_called()

    def review_fixture(self, root):
        fixture = test_authoring.AuthoringTests()
        fixture.demo = load(ROOT/'Example-Lesson-Package.json')
        source = root/'book.json'; source.write_text(json.dumps(fixture.canonical()))
        manifest = prepare(source, root/'review')
        self.assertEqual((root/'review'/manifest['filename']).read_bytes(), source.read_bytes())
        self.assertEqual(manifest['package']['sha256'], hashlib.sha256(source.read_bytes()).hexdigest())
        with self.assertRaises(FileExistsError): prepare(source, root/'review')
        public = root/'public'; public.mkdir()
        for p in (ROOT/'Distribution').iterdir(): (public/p.name).write_bytes(p.read_bytes())
        approval = root/'approval.json'
        approval.write_text(json.dumps(dict(repository=REPOSITORY, publicRepositoryApproved=True, books=[dict(
            id=manifest['id'],collectionRevision=manifest['package']['collectionRevision'],sha256=manifest['package']['sha256'],bytes=manifest['package']['bytes'],
            publicRedistributionApproved=True,rightsIncludingImagesAndNarrationConfirmed=True,releaseQAApproved=True)])))
        return manifest, public, approval

    def test_production_material_and_credentials_cannot_enter_review(self):
        package=load(ROOT/'Example-Lesson-Package.json')
        public_payload_check(package)
        for mutate in [lambda p:p.update(productionNotes='draft'), lambda p:p['book'].update(api_key='private'), lambda p:p['book'].update(synopsis='ghp_'+'a'*30), lambda p:p['book'].update(synopsis='https://github.com/Patchagray/life-is-learned-books/private')]:
            candidate=copy.deepcopy(package);mutate(candidate)
            with self.assertRaises(ValueError):public_payload_check(candidate)

    def test_prepared_exact_bytes_cannot_enable_retired_public_publication(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);_,public,approval=self.review_fixture(root)
            before=(public/'catalog.json').read_bytes()
            with patch('publish_distribution.run') as command:
                with self.assertRaisesRegex(ValueError,'006B retired'):publish(root/'review',approval,public)
                command.assert_not_called()
            self.assertEqual((public/'catalog.json').read_bytes(),before)

if __name__=='__main__':unittest.main()
