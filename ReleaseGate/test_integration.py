"""Synthetic fixtures exercise refusal only; these are never publication approvals."""
import base64, copy, hashlib, json, os, sys, tempfile, unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'Tools'))
import test_authoring
from package_narration import package_audio
from narration_audio import manifest, audio_report
from publication_preflight import policy_errors, report_errors, technical_reports, digest, ROOT

class PublicationIntegrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if 'LIL_FFMPEG' not in os.environ:
            candidate=ROOT/'LocalVerification/Handoff005/PackagedNarration/ffmpeg-path.txt'
            if candidate.exists(): os.environ['LIL_FFMPEG']=candidate.read_text().strip()
        test_authoring.AuthoringTests.setUpClass();p=test_authoring.AuthoringTests().canonical();p['book']['isDemo']=False
        p['book']['id']='atomic-habits'
        with tempfile.TemporaryDirectory() as d:
            directory=Path(d);m=manifest(p);tone=(ROOT/'Tools/Fixtures/narration-tone.mp3').read_bytes()
            for idea in m['ideas']:
                for s in idea['segments']:(directory/s['file']).write_bytes(tone)
            cls.package=package_audio(p,m,directory,p['collectionRevision']+1,provenance={'provider':'elevenlabs','guideVoiceID':'fixture-guide','storytellerVoiceID':'fixture-story','modelID':'fixture-model','producedAt':0})
    def approval(self,p,qa):
        raw=json.dumps(p).encode()
        return raw,{'type':'life-is-learned-book-release-approval-v1','approved':True,'bookID':p['book']['id'],'collectionRevision':p['collectionRevision'],'packageSHA256':digest(raw),'packageBytes':len(raw),'audioQAReportSHA256':digest(qa),'speechAuditioned':True,'approvedBy':'unit-test-only','approvalReference':'synthetic unit test, not an owner approval','approvedAt':'2026-10-10T00:00:00Z','approvedGuideVoiceID':'fixture-guide','approvedStorytellerVoiceID':'fixture-story'}
    def test_real_validator_reports_cannot_make_synthetic_audio_publishable(self):
        with tempfile.TemporaryDirectory() as d:
            output=Path(d);file=output/'synthetic-test-only.json';file.write_text(json.dumps(self.package))
            reports,exits=technical_reports(file,output)
            self.assertEqual(exits,{'authoring':0,'audio':0},reports)
            self.assertEqual(report_errors(reports,exits,self.package),[])
            qa=(output/'audio-qa.json').read_bytes();raw,a=self.approval(self.package,qa)
            errors=policy_errors(self.package,a,raw,qa)
            self.assertTrue(any('Synthetic tone' in e for e in errors))
            self.assertTrue(policy_errors(self.package,{},raw,qa))
    def test_missing_stale_corrupt_mp3_fail_even_with_exact_approval(self):
        for mutation in ['missing','stale','corrupt','fallback']:
            p=copy.deepcopy(self.package);bundle=p['book']['lessons'][0]['narration']
            if mutation=='missing':bundle['segments'].pop()
            elif mutation=='stale':bundle['segments'][0]['scriptSHA256']='0'*64
            elif mutation=='fallback':p['book']['lessons'][0].pop('narration')
            else:p['audioAssets'][bundle['segments'][0]['assetID']]['data']=base64.b64encode(b'corrupt').decode()
            a=audio_report(p)
            reports={'authoring':{'authoringGate':'passed','errors':[]},'audio':{'errors':[],'packages':[{'audio':a}]}}
            self.assertTrue(report_errors(reports,{'authoring':0,'audio':0},p),mutation)
    def test_ten_ideas_with_one_fallback_is_blocked_and_wrong_revision_rejected(self):
        p=copy.deepcopy(self.package);p['book']['lessons']=[dict(copy.deepcopy(p['book']['lessons'][0]),id=f'idea-{i}') for i in range(10)]
        p['book']['lessons'][-1].pop('narration');qa=b'fixture';raw,a=self.approval(p,qa)
        self.assertTrue(any('idea-9: no complete' in e for e in policy_errors(p,a,raw,qa)))
        a['collectionRevision']+=1
        self.assertTrue(any('different book ID or revision' in e for e in policy_errors(p,a,raw,qa)))
    def test_audio_success_never_substitutes_for_owner_approval(self):
        from test_policy import BASE, RAW, QA
        self.assertTrue(any('approval' in e.lower() for e in policy_errors(BASE,{},RAW,QA)))
