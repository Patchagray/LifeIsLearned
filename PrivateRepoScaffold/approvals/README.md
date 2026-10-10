# Explicit book publication approvals

This directory starts EMPTY. The release pipeline must require an owner-issued, authenticated/traceable approval record for each exact book package and SHA-256. It is NOT acceptable for Codex to create or infer an approval from the existence of a package, a successful test, an old chat, or the fact that the owner requested the infrastructure.

Suggested minimal record:

```json
{
  "type": "life-is-learned-book-release-approval-v1",
  "approved": true,
  "bookID": "canonical-book-id",
  "collectionRevision": 4,
  "packageBytes": 123456,
  "speechAuditioned": true,
  "technicalGate": "all-idea-elevenlabs-passed",
  "preflightReportSHA256": "64 lowercase hex of passing local preflight",
  "packageSHA256": "64 lowercase hex",
  "audioQAReportSHA256": "64 lowercase hex",
  "approvedGuideVoiceID": "approved actual ElevenLabs voice ID",
  "approvedStorytellerVoiceID": "approved actual ElevenLabs voice ID",
  "approvedAt": "ISO-8601 UTC timestamp",
  "approvalReference": "Owner's explicit written approval for THIS hash/revision",
  "approvedBy": "owner"
}
```

Those strings are placeholders, NOT an approval. Never commit this example as a release approval. The authentic record belongs to the owner-controlled workflow; self-entered `approved:true` is not a cryptographic signature.

Separate cover records use type `life-is-learned-cover-preview-approval-v1`, approved true, exact bookID/sha256/bytes/mediaType plus approvedBy/approvedAt/approvalReference. They authorize previews only. Owner approval must be independently verified; never infer it.
