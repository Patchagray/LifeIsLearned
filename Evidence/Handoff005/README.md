# Handoff 005 implementation evidence

Baseline: `74a18997dbf8931366ae5acd18f5a4a23ed8699d` on `feature/handoff-004-6-six-stage-lessons`.
Working branch: `feature/handoff-005-library-platform`.

The root PDF and supplied Markdown were reviewed together and agree. Implementation proceeds in sequential green epics; this evidence is expanded after each epic. No merge, public release publication, endpoint deployment or production secret provisioning is authorized here.

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

Reviewer selects an icon direction before final source production. Production catalog/assets/request endpoint and real-network smoke remain reviewer-controlled; fixture passes do not imply deployed services.
