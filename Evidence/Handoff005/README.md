# Handoff 005 implementation evidence

Baseline: `74a18997dbf8931366ae5acd18f5a4a23ed8699d` on `feature/handoff-004-6-six-stage-lessons`.
Working branch: `feature/handoff-005-library-platform`.

Pre-audio 005A–F tested and installed implementation: `94707700805d79198156a685e6b4ea4911a1b673`. The following evidence-only commit records this SHA; its source files are identical to the tested implementation.

The root PDF and supplied Markdown were reviewed together and agree. Implementation proceeds in sequential green epics; this evidence is expanded after each epic. No merge, public release publication, endpoint deployment or production secret provisioning is authorized here.

[Requirement-to-test map](coverage-map.md) · [Machine-readable results](test-results.json) · [Final commands](final-commands.md) · [Pending device checks and fixture setup](physical-checks.md)

## Audio addendum — October 8, 2026

The subsequent [packaged narration implementation and evidence](PackagedNarration/README.md), source `60882b3807f8e91476bbe7f39bce3661ef53d950`, supersede the player/storage details and source SHA above. The results below remain the historical 005A–F baseline. The audio addendum records its own exact source commit, targeted regression, installation and pending hardware checks.

## Verification boundaries

Native compilation, deterministic tests, simulator rendering and physical-device checks are reported separately. Synthetic UI and network fixtures do not establish editorial accuracy, hardware voice quality, camera recognition quality or production network availability. Raw Xcode logs and result bundles remain local under ignored `LocalVerification/Handoff005/` (active build output may be in `/tmp`).

## 005A

- Reader: canonical short-stage art uses a clipped 16:10 window, capped at 368 points wide (230 points tall); Story preserves natural image proportions and optional second art after prose. Takeaway art is optional.
- Contract: secondary art bytes/descriptions and original-fiction marker participate in idea revisions; absent optional fields retain the exact pre-005 fingerprint. Canonical presentation requires correct stage **and** voice order.
- Authoring: five primary illustrations, explicit unsourced-fiction marker, distinct image bytes, existing stage/role/question/timing/resource gates. Legacy payloads are not rewritten.
- Feedback: one completion transition per idea revision, independently optional sound and haptics, one consumed visual event, reduced-motion glow/ring. Feedback failures cannot prevent completion or card earning.
- Audio: a short original synthesized PCM UI sound uses System Sound Services with `kAudioServicesPropertyIsUISound`. This avoids changing the narration player's shared audio session during completion narration. Apple documents that [UI sound services operate independently of the app audio session](https://developer.apple.com/library/archive/documentation/AudioVideo/Conceptual/MultimediaPG/UsingAudio/UsingAudio.html). Silent-switch behavior, perceived volume and haptic quality still need physical-device verification.

Before screenshots are the existing [004.6 simulator evidence](../Handoff004_6/screenshots/); no new before-device capture was performed. New screenshots are explicitly simulator captures. Physical before/after comparison remains a reviewer check.

## 005B

Library-v3, migration, History, real offload and retained revision checks are implemented. See [transaction details, state dumps, byte counts, exact commands and screenshots](005B-storage-offload/README.md). The art-heavy fixture measures 1,666,926 bytes installed, zero after offload, and 1,666,926 after reinstall, with learner state preserved.

## Release gates

Reviewer selected A — Idea Fold before final source production; the icon and its evidence are under [005F](005F-brand/README.md). Production catalog/assets/request endpoint and real-network smoke remain reviewer-controlled; fixture passes do not imply deployed services.

## 005C

Separate discovery metadata, offline cache, Add Books navigation and integrity-checked whole-book downloads are implemented. See [commands, test boundaries and simulator captures](005C-discovery-download/README.md). The shipped preview marks all 50 titles planned; no public release is claimed or published.

## 005D

Native book recognition, explicit metadata requests and an undeployed credential-safe backend reference are implemented. See [test commands, scanner boundaries and screenshots](005D-scanner-request/README.md). Camera recognition quality remains a physical-device check.

## 005E

Optional earned Dive Deeper content is revision-tracked, source-validated and excluded from core timing. See [tests, source/offload behavior and simulator captures](005E-dive-deeper/README.md).


## Final integration review

Cancellation is checked through package verification and import preparation; once the atomic commit begins the UI says Installing and removes Cancel. Native image validation protects remote thumbnails before UIKit renders them. Restore/scanner destinations resolve stable IDs rather than mutable display titles. Backend last-request dates remain monotonic when delayed requests arrive. Final UI coverage includes actually installing an available update and Add Books/request surfaces at accessibility XXXL size.

Both an unsigned device-SDK build and a signed build for Patcha succeeded; compilation does not represent installation or physical feature testing. Final regression results are recorded below; device installation is recorded separately in `deployment.json`. The frozen starter, example package and Catalog 001 remain byte-identical to baseline, recorded in `preserved-content.json`.

Final regression exposed an early-selection bug in the Ideas screen: when cards arrived in batches, the grid silently selected the first partial result before the learner opened the carousel. Later cards then appeared ahead of that unintended selection. The final fix preserves nil until the learner opens/chooses a card, retains real prior choices, and handles removed selections. A deterministic test covers staged arrivals. The original lazy carousel is retained with an explicit viewport width and seeded/captured scroll identity; experimental eager/measured scrolling changes were discarded. Existing identity/centering assertions are retained; manual swiping additionally checks the counter and centered card.

## 005F

The reviewer selected A — Idea Fold before production. Any/Dark/Tinted assets are integrated, compiled, and verified with actual installed icon captures/launch tests on iPhone and iPad simulators. See [brand evidence](005F-brand/README.md).

## Final regression — October 7, 2026

- iPhone 16e / iOS 26.3.1: **94 passed, 0 failed, 2 intentional skips**.
- iPad (A16) / iOS 26.3.1: **94 passed, 0 failed, 2 intentional skips**.
- **44 Python tests**, **4 backend tests**, **484 portable checks**, and Catalog 001 validation passed.
- Signed Patcha build and strict code-signature verification passed with existing signing unchanged.

The two simulator skips are physical premium-voice timing and the existing UI test requiring the actual system Reduce Motion setting. Deterministic reduced-motion rendering/policy checks passed. [All 192 destination/test outcomes](final-test-cases.txt) and [115 tested file hashes](tested-source-sha256.json) are included. All six exported final screenshots were visually inspected; accessibility XXXL captures intentionally show scrollable content, including controls reached and used by the tests. Raw logs/result bundles remain local.

No automatic merge or production deployment was performed. Physical feature verification and reviewer-controlled real-network smoke remain pending.

## Patcha installation

Installed and launched successfully on Patcha (iPhone 15 Pro Max, iOS 27.2), using existing signing and no fixture launch flags. [Sanitized deployment record](deployment.json). This records installation/launch only; the [physical feature checklist](physical-checks.md) remains pending.
