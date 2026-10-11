import unittest
from copy import deepcopy
from publication_preflight import approval_errors, policy_errors, policy_warnings, digest

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
  def test_multiple_explicitly_approved_guide_voices_are_bound_to_package(self):
    p=deepcopy(BASE);p['book']['lessons'][1]['narration']=deepcopy(BUNDLE);p['book']['lessons'][1]['narration']['provenance']['guideVoiceID']='guide-two'
    a=deepcopy(APPROVAL);a.pop('approvedGuideVoiceID');a['approvedGuideVoiceIDs']=['approved-guide','guide-two']
    self.assertEqual([],policy_errors(p,a,RAW,QA))
    self.assertTrue(any('multiple Guide voices' in w for w in policy_warnings(p)))
  def test_unapproved_or_overbroad_guide_voice_set_fails(self):
    p=deepcopy(BASE);p['book']['lessons'][1]['narration']=deepcopy(BUNDLE);p['book']['lessons'][1]['narration']['provenance']['guideVoiceID']='guide-two'
    a=deepcopy(APPROVAL);a.pop('approvedGuideVoiceID');a['approvedGuideVoiceIDs']=['approved-guide']
    self.assertTrue(policy_errors(p,a,RAW,QA))
    a['approvedGuideVoiceIDs']=['approved-guide','guide-two','unused-guide']
    self.assertTrue(policy_errors(p,a,RAW,QA))
  def test_missing_produced_at_is_disclosed_not_fabricated(self):
    p=deepcopy(BASE);p['book']['lessons'][1]['narration']['provenance'].pop('producedAt')
    self.assertEqual([],policy_errors(p,APPROVAL,RAW,QA))
    self.assertTrue(any('producedAt is absent' in w for w in policy_warnings(p)))
  def test_owner_approval_binds_a_stable_technical_report_without_hash_cycle(self):
    preflight=b'{"result":"passed"}\n'
    a=deepcopy(APPROVAL);a['preflightReportSHA256']=digest(preflight)
    self.assertEqual([],approval_errors(BASE,a,RAW,QA,preflight))
    a['preflightReportSHA256']='0'*64
    self.assertTrue(any('technical preflight' in e for e in approval_errors(BASE,a,RAW,QA,preflight)))
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
