import unittest
from copy import deepcopy
from publication_preflight import policy_errors, digest

RAW=b'{"mock":true}'
QA=b'{"audioPass":true}'
ID='atomic-habits'
PROV={"provider":"elevenlabs","guideVoiceID":"approved-guide","storytellerVoiceID":"approved-story","modelID":"fixture-model","producedAt":"2026-10-10T00:00:00Z"}
BUNDLE={"schemaVersion":1,"segments":[{"id":"example"}],"provenance":PROV}
BASE={"book":{"id":ID,"lessons":[{"id":"idea-a","narration":BUNDLE},{"id":"idea-b","narration":BUNDLE}]},"collectionRevision":4,"audioAssets":{"track":{"data":"YXVkaW8="}}}
APPROVAL={"type":"life-is-learned-book-release-approval-v1","approved":True,"bookID":ID,"collectionRevision":4,
"packageSHA256":digest(RAW),"audioQAReportSHA256":digest(QA),"approvedAt":"2026-10-10T20:00:00Z",
"approvalReference":"owner approval of exact book and hash", "approvedBy":"owner",
"approvedGuideVoiceID":"approved-guide","approvedStorytellerVoiceID":"approved-story","packageBytes":len(RAW),"speechAuditioned":True}
class ReleaseGuardUnitTests(unittest.TestCase):
  def test_policy_layer_valid_inputs(self):
    self.assertEqual([],policy_errors(BASE,APPROVAL,RAW,QA))
  def test_fallback_only_rejected(self):
    p=deepcopy(BASE);p['book']['lessons'][1].pop('narration')
    self.assertTrue(policy_errors(p,APPROVAL,RAW,QA))
  def test_wrong_provider_rejected(self):
    p=deepcopy(BASE);p['book']['lessons'][0]['narration']['provenance']['provider']='device'
    self.assertTrue(policy_errors(p,APPROVAL,RAW,QA))
  def test_unapproved_rejected(self):
    a=deepcopy(APPROVAL);a['approved']=False
    self.assertTrue(policy_errors(BASE,a,RAW,QA))
  def test_hash_mismatch_rejected(self):
    self.assertTrue(policy_errors(BASE,APPROVAL,RAW+b'changed',QA))
  def test_audio_report_changed_rejected(self):
    self.assertTrue(policy_errors(BASE,APPROVAL,RAW,QA+b'changed'))
  def test_voice_change_requires_new_approval(self):
    p=deepcopy(BASE);p['book']['lessons'][1]['narration']['provenance']['storytellerVoiceID']='different'
    self.assertTrue(policy_errors(p,APPROVAL,RAW,QA))
if __name__=='__main__':unittest.main()

class RegistryTests(unittest.TestCase):
  def test_changed_release_cannot_downgrade_rewrite_or_reuse_approval(self):
    from validate_registry import validate_update
    old={'schemaVersion':1,'entries':[{'bookID':'atomic-habits','collectionRevision':2,'sha256':'a'*64,'approvalRecord':'approvals/old.json'}]}
    for revision,approval in [(1,'approvals/new.json'),(2,'approvals/new.json'),(3,'approvals/old.json')]:
      proposed=deepcopy(old);proposed['entries'][0].update(collectionRevision=revision,sha256='b'*64,approvalRecord=approval)
      with self.assertRaises(ValueError):validate_update(old,proposed)
    new=deepcopy(old);new['entries'][0].update(collectionRevision=3,sha256='b'*64,approvalRecord='approvals/new.json')
    self.assertEqual(validate_update(old,new),new)
