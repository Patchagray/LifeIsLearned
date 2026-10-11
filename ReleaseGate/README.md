# Future private publication gate

H006B authorizes zero books and zero covers. These scripts perform local validation only. No upload command or inferred owner approval is provided. The former public publisher now refuses all publication attempts.

## Book review

```sh
python3 ReleaseGate/publication_preflight.py --package /private/final.json --output /private/new-review
```

Without owner approval this writes the technical QA reports and a denied `release-decision.json`. It runs the repository's exact authoring and audio gates in separate processes, preserving exit codes and deterministic JSON reports. Configure the existing `LIL_FFMPEG` authoring executable. No runtime app dependency is added.

Every exact idea must have complete, decodable mono MP3s bound to its scripts and roles, all feedback choices and all completion scores, within the core timing/resource budgets. Every provenance record must name ElevenLabs, model and voice IDs. `producedAt` is optional in formatVersion 2; when absent, the preflight reports a warning instead of inventing a timestamp. The owner approval must list every Guide voice ID used by the exact package (`approvedGuideVoiceIDs`; legacy single-voice `approvedGuideVoiceID` remains accepted) and its Storyteller voice. Known synthetic tones, demo content and identical MP3 bytes assigned to different scripts are refused. An owner must audition the actual speech: metadata cannot cryptographically prove which provider generated a recording, and these checks do not claim arbitrary acoustic forgery detection.

Preflight writes `preflight.json` as a deterministic technical report and `release-decision.json` as the owner-bound decision. This keeps the owner approval's `preflightReportSHA256` from forming a self-referential hash. After explicit owner approval of the exact package and audio report, create the owner record with that technical report hash, then rerun into a fresh directory with `--approval /private/owner-record.json`. Require `release-decision.json` to say passed. The owner record follows `PrivateRepoScaffold/approvals/README.md`, plus `packageBytes` and `speechAuditioned:true`. Every hash, revision, voice ID and report must match. The code cannot authenticate a human by reading `approved:true`; verify the record's explicit owner authorization before any later upload. Preflight always reruns the real validators and refuses a substitute `--validator`.

## Future publication transaction (separately authorized)

1. Recheck origin privacy and the exact local package against the owner approval.
2. Run preflight, require the technical `preflight.json` to say passed and both exit codes to be zero; bind that exact JSON SHA as `preflightReportSHA256` in the owner record. Rerun with that record and require `release-decision.json` to say passed.
3. Verify the proposed registry against the current remote registry using `validate_registry.py`. Changed releases need a newer collection revision and a fresh approval path. No silent downgrade, same-revision byte rewrite or deletion.
4. Enable GitHub immutable releases before the first approved release. Upload the approved exact bytes as a new versioned private immutable GitHub Release; verify downloaded bytes, asset ID, size and GitHub SHA-256 digest. Do not overwrite an existing asset.
5. Add the corroborating approval record with `technicalGate:"all-idea-elevenlabs-passed"`, `preflightReportSHA256`, every approved Guide voice ID, the approved Storyteller ID, audio QA hash, package hash/size/revision and traceable owner approval. Preserve any preflight warnings (such as absent optional production timestamps) for reviewer visibility.
6. Update `catalog/approved-packages.json` last. Until that commit, the Worker cannot advertise the release. Preserve the prior working entry if any step fails.

The two allowlists use `{ "schemaVersion": 1, "entries": [] }`. Each package entry contains `bookID`, `collectionRevision`, `releaseID`, `releaseAssetID`, `bytes`, `sha256`, `approvalRecord`, and `preflightReportRecord` (paths under approvals/, such as `approvals/book-r2.json`). Worker validates the private immutable release, its uploaded asset digest/size and matching owner record. The Worker also fetches the bound preflight JSON, verifies its hash, matching package identity and both passing validator exit codes. The trusted publication workflow certifies complete audio; the Worker does not download/FFmpeg-decode a whole book on catalog requests.

Each cover entry contains `bookID`, `path` (under covers/, PNG/JPEG), `mediaType`, `bytes`, `sha256`, and `approvalRecord`. Its separate record has `type:"life-is-learned-cover-preview-approval-v1"`, `approved:true`, exact `bookID`, `bytes`, `sha256`, `mediaType`, `approvedBy`, `approvedAt`, and `approvalReference`. A cover record cannot satisfy the book gate. Preview bytes are separately reviewed, <=512 KiB, and must pass the existing image decoder/dimension constraints before committing them. No example here represents an actual approval.

A deliberate revocation or rollback requires a separate reviewed procedure; do not bypass the monotonic update guard. No production books, voices, private QA reports or approval records belong in the public app-source repository. Synthetic unit fixtures remain local/test-only and are never uploaded to the publication repository.
