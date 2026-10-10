# Handoff 006B evidence

Implementation source and verification records accompany this directory. This is an infrastructure implementation with **live staging authentication pending**, not a claim of completed production rollout.

- Private GitHub origin: created, private visibility verified, canonical metadata copied exactly; zero books/covers/releases.
- Worker: Node mock tests, local workerd smoke and Wrangler dry-run. No live staging endpoint or configured secrets claimed.
- Publication policy: real authoring/audio validators and independent exact-byte approval checks, including synthetic-tone refusal. No authoring candidate books were moved or published.
- App: native regression plus affected iPhone/iPad simulator UI and Release build. Final chronological counts and source hashes are in `test-results.json`.
- Simulator screenshots use isolated fixture storage/networking. The cover-preview image is a reused starter fixture, not a separately approved public cover.

Raw logs, QA payloads, videos, credentials and test-result bundles stay in ignored LocalVerification/Handoff006B or /tmp/LIL006B*. Physical-device and real authenticated Worker/package checks remain pending. See the implementation report and Worker README for exact account steps.

## Source and results

Tested implementation: `30985dd98c1ba7898b546fc8cb0757ffee9af5cc`. Evidence-only commits do not change that implementation.

| Check | Outcome |
|---|---|
| Full native regression | 94 passed, 1 hardware timing skip |
| Final affected native | 14 passed |
| Affected UI | 9 iPad passed; iPhone 8 passed + fixture failure, then corrected check passed on both |
| Worker | 11 passed |
| Private publication guards | 12 passed |
| Python authoring/catalog/distribution | 61 passed |
| Release build / Worker dry-run / local runtime | Passed |
| Live staging / physical device | Pending |

See [chronological results](test-results.json), [commands and visual inspection](commands.md), [source hashes](tested-source-sha256.json), [preserved core](preserved-core.json), and [deployment status](deployment-status.json). The failed fixture run is retained rather than represented as a fully green run. Final affected checks passed after the deterministic fixture correction.
