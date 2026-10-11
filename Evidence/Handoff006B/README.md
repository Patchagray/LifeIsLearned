# Handoff 006B evidence

Implementation source and verification records accompany this directory. Authenticated Cloudflare staging is deployed and smoke-tested; this is not a claim of production rollout.

- Private GitHub origin: created, private visibility verified, canonical metadata copied exactly; zero books/covers/releases.
- Worker: 12 Node tests, authenticated local workerd smoke, authenticated live staging smoke and Wrangler deploy. All three secret names were verified present without revealing values.
- Publication policy: real authoring/audio validators and independent exact-byte approval checks, including synthetic-tone refusal. No authoring candidate books were moved or published.
- App: native regression plus affected iPhone/iPad simulator UI and Release build. Final chronological counts and source hashes are in `test-results.json`.
- Simulator screenshots use isolated fixture storage/networking. The cover-preview image is a reused starter fixture, not a separately approved public cover.

Raw logs, QA payloads, videos, credentials and test-result bundles stay in ignored LocalVerification/Handoff006B or /tmp/LIL006B*. No approved package exists, so real package streaming/playback remains untested; physical-device checks remain pending. See the implementation report for the staging endpoint and current deployment status.

## Source and results

Tested implementation: `c71e5eb` (H006B runtime fix and Debug staging URL). Evidence-only commits do not change that implementation.

| Check | Outcome |
|---|---|
| Full native regression | 94 passed, 1 hardware timing skip |
| Final affected native | 14 passed |
| Affected UI | 9 iPad passed; iPhone 8 passed + fixture failure, then corrected check passed on both |
| Worker | 12 passed, including Cloudflare Fetch runtime regression |
| Private publication guards | 12 passed |
| Python authoring/catalog/distribution | 61 passed |
| Release build / Worker dry-run / local runtime | Passed |
| Live staging catalog | 200, authenticated: 50 planned, 0 packages/covers; health 200; unapproved download and unknown path 404 |
| Physical-device checks | Pending |

See [chronological results](test-results.json), [commands and visual inspection](commands.md), [source hashes](tested-source-sha256.json), [preserved core](preserved-core.json), and [deployment status](deployment-status.json). The failed fixture run is retained rather than represented as a fully green run. Final affected checks passed after the deterministic fixture correction.

## Live staging

The scoped GitHub App is installed read-only on the private publication repository. All three Worker Secret names are present, and the live endpoint serves the authenticated planned catalog. The Debug build embeds the staging catalog URL; Release configuration leaves that setting empty. See live-staging-smoke.json.

## First published package: Thanks for the Feedback

Revision 1 was published as an immutable release at [thanks-for-the-feedback-r1](https://github.com/Patchagray/LifeIsLearned-Published/releases/tag/thanks-for-the-feedback-r1). The exact package hash, release IDs, preflight evidence, staging download verification, and owner-reported device observations are recorded in [thanks-for-the-feedback-r1-published.json](thanks-for-the-feedback-r1-published.json). The production device's only reported issue is synchronized highlights; the owner accepted that limitation for this release and plans to address it in a future update. Codex verified the staging catalog and full package download from the Mac; it did not perform a post-publication import on the iPhone.
