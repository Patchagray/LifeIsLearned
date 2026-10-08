import base64
import copy
import json
import os
from pathlib import Path
import tempfile
import unittest
from narration_audio import audio_report, coarse_cues, ffmpeg, inspect_mp3, manifest, scripts, valid_cues, SEGMENT_BYTES
from package_narration import package_audio
from lesson_timing import narration_segments, plan

ROOT = Path(__file__).resolve().parents[1]

class NarrationScriptsTests(unittest.TestCase):
    def setUp(self):
        self.package = json.loads((ROOT/'Example-Lesson-Package.json').read_text())
    def test_scripts_share_existing_timing_strings_and_cover_all_branches(self):
        lesson = self.package['book']['lessons'][0]
        exported = scripts(lesson); lookup = {s['id']:s for s in exported}
        self.assertEqual(len(exported), len(lookup))
        for timed in narration_segments(lesson):
            if timed['id'].startswith('feedback:'):
                self.assertIn(timed['text'], [s['text'] for s in exported if s['id'].startswith(timed['id']+':')])
            elif timed['id']=='completion': self.assertEqual(timed['text'],lookup['completion:2']['text'])
            else: self.assertEqual(timed['text'],lookup[timed['id']]['text'])
        for q in lesson['questions']:
            for c in q['choices']: self.assertIn(f"feedback:{q['id']}:{c['id']}",lookup)
        self.assertTrue(all('completion:'+str(n) in lookup for n in range(3)))
    def test_cues_use_utf16_monotonic_boundaries_and_timing_is_unchanged(self):
        text='Hello 😀. Another sentence! Last phrase.'
        cues=coarse_cues(text,7000)
        self.assertTrue(valid_cues(cues,text,7000));self.assertEqual(cues[-1]['endMilliseconds'],7000)
        self.assertEqual(cues[1]['characterStart'],len('Hello 😀. '.encode('utf-16-le'))//2)
        lesson=self.package['book']['lessons'][0];before=plan(lesson)
        lesson['narration']={'schemaVersion':1,'segments':[{'durationMilliseconds':99999}]}
        self.assertEqual(plan(lesson),before)
    def test_legacy_audio_report_absent_requires_no_decoder(self):
        self.assertEqual(audio_report(self.package)['ideas'][0]['premiumNarration'],'absent')

class NarrationPackagingTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        try: ffmpeg()
        except ValueError as e: raise unittest.SkipTest(str(e))
    def setUp(self):
        self.package=json.loads((ROOT/'Example-Lesson-Package.json').read_text())
        self.expected=manifest(self.package)
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.clips=Path(self.temp.name)
        self.raw=(ROOT/'Tools/Fixtures/narration-tone.mp3').read_bytes()
        for idea in self.expected['ideas']:
            for s in idea['segments']: (self.clips/s['file']).write_bytes(self.raw)
    def package_audio(self, **kwargs):
        return package_audio(self.package,self.expected,self.clips,self.package['collectionRevision']+1,**kwargs)
    def test_complete_bundle_decodes_and_preserves_prose_and_revision(self):
        p=self.package_audio();report=audio_report(p)
        self.assertEqual(report['ideas'][0]['premiumNarration'],'complete',report)
        self.assertGreater(report['decodedAudioBytes'],0)
        for original,lesson in zip(self.package['book']['lessons'],p['book']['lessons']):
            lesson=copy.deepcopy(lesson);lesson.pop('narration')
            self.assertEqual(original,lesson)
        self.assertEqual(inspect_mp3(ROOT/'Tools/Fixtures/narration-tone.mp3'),1200)
    def test_missing_unknown_duplicate_or_changed_manifest_rejected(self):
        first=self.clips/next(iter(self.clips.iterdir())).name;first.unlink()
        with self.assertRaises(ValueError):self.package_audio()
        first.write_bytes(self.raw);(self.clips/'unknown.mp3').write_bytes(self.raw)
        with self.assertRaises(ValueError):self.package_audio()
        (self.clips/'unknown.mp3').unlink()
        self.expected['ideas'][0]['segments'].append(self.expected['ideas'][0]['segments'][0])
        with self.assertRaises(ValueError):self.package_audio()
        self.expected=manifest(self.package);self.expected['ideas'][0]['segments'][0]['text']+=' changed'
        with self.assertRaises(ValueError):self.package_audio()
    def test_corrupt_stale_missing_and_duplicate_report_invalid(self):
        p=self.package_audio()
        for change in ['stale','missing','duplicate','corrupt','invalid-asset-id','invalid-duration']:
            damaged=copy.deepcopy(p);segments=damaged['book']['lessons'][0]['narration']['segments']
            if change=='stale':segments[0]['scriptSHA256']='0'*64
            elif change=='missing':segments.pop()
            elif change=='duplicate':segments[1]=segments[0]
            elif change=='invalid-asset-id':segments[0]['assetID']={}
            elif change=='invalid-duration':segments[0]['durationMilliseconds']='invalid'
            else:damaged['audioAssets'][segments[0]['assetID']]['data']=base64.b64encode(b'not mp3').decode()
            self.assertEqual(audio_report(damaged)['ideas'][0]['premiumNarration'],'invalid')
    def test_corrupt_decode_budgets_and_collection_revision_enforced(self):
        clip=next(self.clips.iterdir());clip.write_bytes(b'invalid mp3')
        with self.assertRaises(ValueError):self.package_audio()
        clip.write_bytes(bytes(SEGMENT_BYTES+1))
        with self.assertRaises(ValueError):self.package_audio()
        clip.write_bytes(self.raw)
        with self.assertRaises(ValueError):package_audio(self.package,self.expected,self.clips,self.package['collectionRevision'])
    def test_missing_cues_allowed_but_bad_supplied_cues_and_credentials_rejected(self):
        p=self.package_audio()
        for segment in p['book']['lessons'][0]['narration']['segments']: segment.pop('cues')
        self.assertEqual(audio_report(p)['ideas'][0]['premiumNarration'],'complete')
        name=self.expected['ideas'][0]['segments'][0]['file']
        with self.assertRaises(ValueError):self.package_audio(cues={name:[{'characterStart':-1}]})
        with self.assertRaises(ValueError):self.package_audio(provenance={'provider':'elevenlabs','apiKey':'must-not-package'})

    def test_normalization_preserves_master_and_produces_decodable_mono_mp3(self):
        from normalize_narration import normalize
        master=ROOT/'Tools/Fixtures/narration-tone.mp3'
        output=self.clips/'normalized.mp3'
        report=normalize(master,output)
        self.assertEqual(master.read_bytes(),self.raw)
        self.assertEqual(inspect_mp3(output),1200)
        self.assertEqual(report['channels'],1)
        self.assertAlmostEqual(float(report['normalization']['output_i']),-16,delta=0.2)
        with self.assertRaises(ValueError):normalize(master,master)
        output.unlink()
        with self.assertRaisesRegex(ValueError,'producedAt'):self.package_audio(provenance={'provider':'elevenlabs','producedAt':float('nan')})
