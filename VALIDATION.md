# Validation report

## Catalog 001 reviewer remediation — awaiting approval

On `feature/catalog-001-foundation`, the metadata integrity patch supports only catalog revision 1, locks the approved ordered 50 `(catalogOrder, id)` pairs independently of the manifest, and enforces physical shelf/book array order. Negative tests cover revision 2, every stable ID, swapped IDs, and swapped shelf/book entries. The Never Split reconciliation note now records its established ID. Canonical manifest SHA-256 is `7424b9d5deff4f1645ca112f1393bfafd84553a040593d53a6af35133826da68`.

The validator passed; all **18 catalog tests** and **12 existing Python authoring tests** passed. All **56 tracked files** across the five requested protected app/project/test/example paths were compared byte-for-byte with pre-remediation commit `02dea3f2667a5037188499a8dfe5870ec2fe1198` and are unchanged. No simulator/UI rerun was performed, as authorized. The manifest differs only in its reconciliation note. [Commands, source hashes and preservation evidence](Evidence/Catalog001/README.md) are recorded for reviewer approval before freeze. No merge was performed.

## Catalog 001 foundation — October 5, 2026

Implementation: `fb735c0f1bffb2f92f9c0cb6850624f3160771cc`, branch `feature/catalog-001-foundation`, based on the accepted Handoff 004 result `7f0146ae065d2e75917af88726be30484171fb5b`. See [Catalog 001 evidence, reconciliation and exact commands](Evidence/Catalog001/README.md).

The approved static editorial manifest contains 50 unique books, eight shelves, primary counts **10 / 7 / 8 / 7 / 7 / 4 / 3 / 4**, and authoring priorities exactly 1–50. It is separate from installed `CollectionCatalog`. The existing authored Never Split package uses `never-split-the-difference`, matching the approved manifest; `influential-mind` also matches. No reconciliation rename was needed. Future authoring now looks up exact catalog IDs before writing packages.

The read-only validator passed; all 13 catalog tests and 12 existing Python authoring tests passed. Xcode 26.5 (17F42) built/tested the selected iPhone 16e/iOS 26.3.1 regression suite: **32 passed, 0 failed, 1 explicit Reduce Motion skip** (25 native tests and 7 UI tests). This includes the import/recovery/revision/card/layout suites, all normal-motion Handoff 004 UI journeys, and actual Files import → retry/resume → completion. App sources, project/signing, native/UI tests, and example content remain byte-for-byte unchanged. No new runtime layout or physical-device verification is claimed for this static patch. Raw logs/results are retained in ignored `LocalVerification/Catalog001/`.

## Handoff 004 — October 5, 2026

Tested implementation: `7a31213bf574ba6540e663d5177ceb4f178371a7`, branch `feature/handoff-004-idea-collection`, based on accepted Handoff 003 head `0fd3ef261b275c7adffbba2575f468398f0f4146`. The follow-up evidence commit changes documentation and screenshots only. See [Handoff 004 commands, results, screenshots and limits](Evidence/Handoff004/README.md).

- Added direct sequential next-idea/resume/review navigation and final Finish book; no new autoplay.
- Earned idea cards survive imperfect practice, retries, review, revisions and removals. Atomic card persistence includes historical migration, preserved unknown dates, independent recovery, favorites and archived source review.
- Added Home Ideas, a staggered lazy grid, centered carousel, front/back cards, separate favorites, book filtering and sorting. Includes iPad, accessibility text, explicit accessibility order/actions, and visibility/Reduce Motion-aware favorite animation.
- SpeechPlayer, starter content and the example collection are byte-for-byte unchanged; signing and import format/limits are preserved.

| Destination / check | Result |
| --- | --- |
| iPhone 16e simulator, iOS 26.3.1 | Build/test succeeded: 52 passed, 0 failed, 2 explicit skips |
| iPad (A16) simulator, iOS 26.3.1 | Build/test succeeded: 52 passed, 0 failed, 2 explicit skips |
| iPad, actual system Reduce Motion enabled | 1 passed, 0 failed/skipped; prior setting restored |
| PATCHA, iPhone 15 Pro Max, iOS 27.2 | 6 H004 UI tests passed, 0 failed, 1 explicit Reduce Motion skip |
| Signed device build, in-place install, normal launch | All succeeded for the tested implementation |

The full simulator runs each include 43 passing unit/layout tests and 9 passing UI tests. Skips are physical premium-voice timing and the Reduce Motion-only check; the latter passed separately. Tests cover card ownership/recovery/revisions, 20 synthetic cards and 7 favorites, saved next-idea entry, existing playback boundaries, first-attempt scoring, incorrect-answer retry, and the actual Files import journey. Twenty-seven labeled simulator screenshots accompany sanitized results and hashes; raw logs and result bundles are retained in ignored `LocalVerification/Handoff004/`.

The device UI tests exercise earning, favorites across relaunch, grid/carousel/flip, direct next-idea resume and review. Pixel comparisons establish that favorite animation is active and ordinary cards stay still; they do not measure frame rate or establish subjective smoothness. Mario’s manual animation/haptic/VoiceOver checks remain pending. Premium voices, interruptions and background playback were not newly verified on hardware for H004; earlier H003 physical acceptance is preserved below as historical evidence.

## Handoff 003 — October 4–5, 2026

Implementation: `f78c7f1781b6fa2087559d138c2b4947b0dcfc52`, branch `feature/handoff-003-content-limits`, based on accepted Handoff 002 commit `d10a60f84b9921cd24a74666b5877359f0623090`. The follow-up evidence commit changes documentation and screenshots only. This section supersedes earlier import-count and duration guidance; historical results below remain unchanged. See [commands, hashes and screenshots](Evidence/Handoff003/README.md).

### Changes and preservation

- New imports and updates require 1–12 unique ideas. Stored-content loading separately preserves valid 13–100-idea format-2 collections and legacy format-1 content. Reducing an installed collection requires explicit removals and acknowledgement; all old progress remains archived.
- Removed the numerical image-count cap. Retained 64 MiB encoded packages, 2 MiB per image, 24 MiB combined base64-decoded image-file bytes, 2048 × 2048 dimensions, single-frame PNG/JPEG native decoding, unique nonempty IDs, references and cover checks.
- Added repeatable whole-idea timing and authoring/release gates, including options, feedback prefixes, completion, page pauses and answering allowance. The runtime never interrupts narration to meet a deadline. Selection and coverage appear before the first start; duration help explains individual variation.
- Shortened the separate demo update to six screens and two application questions, collection/idea revision 2. The startup seed remains byte-for-byte unchanged. Sources and original artwork are retained; full-book coverage is not claimed. The two larger companions are being curated externally for later import, as requested.
- The speech service is byte-for-byte unchanged. Session changes centralize the same spoken strings for playback/timing parity. Existing signing settings, manual Files picker, revision checks, recovery and user data are preserved.

### Actual results

| Destination / tool | Result |
| --- | --- |
| iPhone 16e simulator · iOS 26.3.1 | Build succeeded; 35 passed, 0 failed, 1 intentional physical-voice skip |
| iPad (A16) simulator · iOS 26.3.1 | Build succeeded; 35 passed, 0 failed, 1 intentional physical-voice skip |
| Python authoring tests | 12 passed |
| Portable package/project validation | 320 checks passed; structural/header checks only |
| Physical iPhone 15 Pro Max · iOS 27.2 | Premium narration timing: 1 passed, no skip |
| Signed device build / install / launch | All succeeded from the implementation commit; installed in place |

Each simulator run includes 32 passing unit/layout tests, one explicitly skipped hardware voice test, and three passing actual-app UI journeys. The UI tests cover the original lesson, first-start preface/duration help, and actual Files selection → update preview/confirmation → shortened lesson → wrong answer → terminate/relaunch → retry → completion with first-attempt score → return to book. Both portrait and landscape controls are exercised. Screenshots distinguish actual UI automation from injected large-text layout states.

Native tests accept 1/12 and reject 0/13; reject duplicate IDs, bad manifests, missing references, malformed images and oversized byte/dimension budgets; load and migrate a stored 100-idea book without recovery/truncation; then apply a reviewed 12-idea update while retaining all 100 progress records. Existing no-op, revision/downgrade, removal, failed-write recovery, voice-role, pause/resume, stale-callback, manual-navigation, reflection, retry, restoration and narration-follow tests pass.

The native stress fixture contains 12 ideas × 40 pages, 43 shared asset entries and a cover (25,317,046 encoded bytes). Every reference and image byte survives relaunch. iPhone validation/commit/relaunch took **8.51 s**, with **778 main-actor ticks** and sampled resident memory **172,425,216 → 259,862,528 peak → 211,230,720 bytes**. iPad took **6.78 s**, with **624 ticks** and **191,700,992 → 280,637,440 peak → 230,981,632 bytes**. These are Debug simulator process samples, not production-device performance guarantees. The 43 entries reuse original illustration bytes to test count removal; this synthetic stress collection intentionally exceeds the editorial timing budget and is not an authored release.

### Premium reference timing

The shortened `priors` revision 2 has **413 reference spoken words**. Planning at 130 words/minute gives **240.62 seconds** including five 2-second transitions and 40 seconds for answers. The displayed approximate plan is **About 5 min · whole idea**.

On PATCHA, the production speech player measured **175.17 seconds of actual narration** using **Jamie (Premium)** (`com.apple.voice.premium.en-GB.Malcolm`) as guide and **Serena (Premium)** (`com.apple.voice.premium.en-GB.Serena`) as storyteller, normal speed 1.0, 2-second page pauses. Adding 10 seconds of pauses and the 40-second answer allowance yields **225.17 seconds (3m45s)**. Observed script wall time was 225.50 seconds. No enhanced/compact fallback was used.

The [measurement](Evidence/Handoff003/premium-reference-timing.json) and [release-gate report](Evidence/Handoff003/short-demo-timing-report.json) match the exact ordered native and Python narration scripts. The physical run predates a word-count allocation optimization; the measured script and production speech service are identical to the final implementation. This is physical callback timing with a scripted answer allowance, not a human comprehension trial or subjective audition. Release-gate approval establishes timing/structure, not factual correctness.

Boundary tests demonstrate 299.692308 seconds passes planning and 300.153846 fails; synthetic measurement validation accepts exactly 300 and rejects 300.01. Missing measurements, non-premium voices, changed scripts/revisions or altered reference settings cannot approve a release.

### User-reported device acceptance — October 5, 2026

After the Handoff 003 build was installed and launched on PATCHA, Mario reported **“everything works.”** This is recorded as the user's overall physical-device acceptance of the delivered patch. The user did not enumerate individual voice, interruption, accessibility or background scenarios, so this statement does not independently document results for each one. The premium timing evidence above is the separately measured device result.

### Repairs, evidence and remaining scope

An initial new test failed Swift exclusivity checking; a local image value fixed the fixture. An initial Files UI test assumed a five-second provider startup; it now waits for actual provider readiness before choosing its navigation path. The final full suites pass without weakening acceptance assertions. Raw development logs, including failures, and the three principal result bundles are archived in the ignored local `LocalVerification/Handoff003/` folder. Published evidence excludes device identifiers, signing profiles and raw result bundles.

Xcode emitted debugger-version diagnostics, simulator voice fallback messages, and physical AVAudioSession/AudioQueue diagnostics. The recorded test/build/install/launch operations nevertheless completed successfully; these logs do not establish subjective audio quality. An early attachment export ran before Xcode finalized its result bundle; the subsequent completed-bundle export succeeded.

The user’s overall device acceptance is recorded above; detailed voice audition and individual interruption/audio-route, background/foreground, VoiceOver and Reduce Motion results were not enumerated. Prior Handoff 002 acceptance remains separately historical. No authentication or signing blocker remains. The two full companion collections, cloud distribution/catalog, release publication and default-branch merge are outside this patch.

To try the update: open `LifeIsLearned.xcodeproj`, select **LifeIsLearned → PATCHA** and press **⌘R** (the build is already installed). Save `Example-Lesson-Package.json` to the iPhone's Files app, then choose **+ / Import book → that file → Import complete update → Open book**. Import is intentionally not automatic; the old revision's progress remains archived.

---

## Handoff 002 — October 4, 2026

Implemented on `feature/handoff-002-ui-polish`, starting from the working narration-scroll branch at `7913c1d9af31ee457decf0a0efc8e6790cc43174`. The supplied PDF is preserved byte for byte at the repository root (SHA-256 `8cceffefa6a4d9f7fb4f64273ae5bca289fc3e67af47758fb614c5b6b482c012`). Existing signing-team settings and the native speech service were preserved. No default-branch merge was performed.

**Source and evidence:** [Handoff 002 evidence](Evidence/Handoff002/README.md) identifies the exact tested commits, source hashes, simulator destinations, screenshots, timings, and sanitized results. This section supersedes the historical bootstrap status below.

### What changed

- Format-2 complete book collections: ordered manifests, collection/idea revisions, shared artwork, optional accessible covers, staged review, explicit removal acknowledgement, deterministic content comparison, and archived revision progress.
- Recoverable content/progress snapshots with one atomic publication point; independent recovery of progress, legacy migration, and read-only protection when saved data cannot be recovered. See [PERSISTENCE.md](PERSISTENCE.md).
- One learning home with honest first-use/resume/next/completed actions; ordered book details, library search, and restored practice selection/feedback/first-attempt scoring. Resume never starts audio. Completion returns to the book, including from a Home resume.
- A shared light/dark editorial design across home, books, reader, takeaway, practice, completion, import, source notes, and voice settings. Existing illustrations and clearly identified cover placeholders are used.
- A fresh preference now defaults to a 2.0-second reflection pause. Saved preferences are preserved. Pausing that delay retains the remaining time; resuming advances without replaying completed narration. The existing speech callbacks, roles, and foreground-only behavior remain.
- Authoring, conversion, fixture generation, example/starter packages, portable validation, and standing instructions now agree on complete collection imports. Starter prose, IDs, revisions, sources, questions, and answer keys were compared with the working baseline and are unchanged.

### Final build and test results

Tested source: `12ec69ad440384531e2ee9bad7c3b65a8ed0ea0a`. The final evidence commit adds only documentation and screenshots.

| Destination | Build | Tests |
| --- | --- | --- |
| iPhone 16e · iOS 26.3.1 | Succeeded | 29 passed, 0 failed, 0 skipped |
| iPad (A16) · iOS 26.3.1 | Succeeded | 29 passed, 0 failed, 0 skipped |

Each run includes 28 unit/layout tests and the actual app journey. The native maximum-count fixture was 21,792,441 bytes. Validation, confirmation, persistence, and relaunch took about 29.4 seconds in these Debug simulator tests; the main-actor heartbeat continued during import (2,590 ticks on iPhone, 2,584 on iPad). This demonstrates responsiveness during that workload, not production-device speed.

Original final/baseline result bundles and 20 development logs were archived locally at `~/Library/Logs/LifeIsLearned/Handoff002/`. Source and published screenshot hashes were checked against the tested commit and captured files.

### Automated acceptance coverage

| Area | Verification |
| --- | --- |
| Whole collection | Three-idea shared-artwork import, exact order, cancellation, identical no-op, relaunch |
| Updates | Added/revised/reordered/removed ideas; distinct acknowledgement; unchanged progress; revised current idea; archived history and reinstatement |
| Rejection | Same revision with different content, downgrades, undeclared omissions, incomplete manifests, duplicate IDs, missing assets, oversized bytes/pixels, malformed JSON, invalid source/answer references |
| Persistence | Injected failed write and relaunch; independent progress recovery with corrupt content; another save/relaunch after recovery; orphan snapshot ignored; unreadable progress preserved without empty overwrite |
| Migration | Existing demo progress keys and legacy installed content retained; newly selected legacy packages rejected with conversion guidance |
| Resume | Selected wrong answer, feedback, attempted state, second-question position, first-attempt score, and no automatic audio after restoration |
| Playback | Guide/storyteller roles, active-speech pause/resume, delayed-transition pause/resume, stale callback cancellation, manual navigation, stop/suspend paths, takeaway/practice boundaries |
| Narration following | Actual TextKit line geometry, Unicode offsets, narrow/tablet/landscape widths, Dynamic Type, pause/replay, queued-operation cancellation, stable text wrapping during emphasis |
| App journey | Actual simulator taps through book → screens → takeaway → wrong answer → terminate/relaunch → retry → second question → completion → book; portrait/landscape rotation |
| Layout | Simulator-hosted real SwiftUI views: one/multiple books, empty/no-results, missing cover, long title, large text, light/dark; semantic text contrast checks |
| Large collection | Native validation, confirmation/publication, and relaunch of 100 ideas × 40 pages with 32 shared assets; main-actor heartbeat during import. Measurements are in the evidence JSON, not a hardware performance guarantee. |

State tests use a controllable narrator. They verify sequencing and cancellation logic; they do not audition voices or simulate an actual telephone/audio interruption. Layout screenshots inject deterministic states. The separately labeled app-journey screenshots come from UI automation in the running app. UI tests use a Debug-only temporary document directory and random preferences suite, preserving the normal app's progress.

### Commands and limits

Xcode 26.5 (17F42), shared `LifeIsLearned` scheme; app, unit/layout, and UI-test targets. iPhone 16e and iPad (A16), both iOS 26.3.1. Exact commands and result-bundle names appear in the evidence report. `xcodebuild test` also compiles the app and both test targets.

```bash
python3 Tools/validate_package.py --report /tmp/LifeIsLearned-ui002-portable.json
python3 Tools/make_verification_fixture.py /tmp/LifeIsLearned-collection-verification.json
python3 Tools/validate_package.py /tmp/LifeIsLearned-collection-verification.json
python3 Tools/make_verification_fixture.py /tmp/LifeIsLearned-ui002-largest.json --largest
python3 Tools/validate_package.py /tmp/LifeIsLearned-ui002-largest.json --report /tmp/LifeIsLearned-ui002-largest-report.json
```

Portable checks: **311** for bundled/example collections and project structure; **157** for the three-idea fixture; **20,877** for the generated 100-idea fixture (22,221,977 bytes). These are structural/image-header checks, separate from native decoding and XCTest. Fixture generation refuses an existing destination; choose a new filename when reproducing it. Fixtures are explicitly synthetic repetitions of reviewed starter material, not new book summaries.

Supported limits: 64 MiB JSON, up to 100 ideas, 40 pages/idea, 32 shared assets, 2 MiB per image and 24 MiB total base64-decoded image-file bytes, maximum 2048 × 2048 pixels and one PNG/JPEG frame. Pixel dimensions separately bound decompression. The generated fixture covers maximum idea/page/asset counts, not every limit simultaneously. Native tests produce their own compact equivalent with the same maxima; exact byte counts differ from pretty-printed portable JSON.

### Design review and repairs

Before/after home, book, and reader captures and final import/practice captures are in the evidence gallery. Render review found stretched placeholder covers and clipped long titles; the cover canvas now preserves its ratio and text wraps. A narration-scrolling test exposed bold emphasis changing glyph widths and reflowing the final word beyond the measured container: color/background emphasis now preserves line geometry, with a new assertion. The app journey exposed the Home completion route; it now returns to the book. Navigation bars now remain opaque above scrolled content, and accessibility grid widths use consistent bounds. Landscape evidence uses full-screen capture and verifies orientation; an earlier app-element crop caused a test-harness assertion failure and was corrected.

During development, new test-file registration and an unsupported test-only environment assignment caused compilation failures; those were corrected. Failed runs were retained locally. Tests were not weakened to obtain passing results. Simulator voice-database fallback messages and UIKit test-host appearance messages occurred; these do not establish hardware voice quality. Raw logs and `.xcresult` bundles remain local; relevant sanitized summaries and compressed images are committed.

### Physical-device deployment and user acceptance — October 4, 2026

The app was built, installed, and launched on the connected **iPhone 15 Pro Max, iOS 27.2 (24B5089g)** from commit `f4a8693645c3e97a54567f1034f4d463b6506fb3`. Xcode 26.5 used the existing signing settings. The build succeeded, and both device installation and foreground launch returned success. The existing app was updated in place without uninstalling it. See the [sanitized device evidence](Evidence/Handoff002/DEVICE_VERIFICATION.md) for commands, outcomes, and local log hashes.

After taking responsibility for the physical checks and receiving that build, Mario reported **“All checks are good”** and authorized committing and pushing the accepted work. This records user-reported physical-device acceptance of the deployed Handoff 002 build. No remaining blocker was reported. The report is an overall acceptance result; individual voice, interruption, accessibility, and other scenario results were not separately enumerated or observed by the agent.

This acceptance supersedes the pending overall physical-device pass recorded before deployment. The simulator results above remain the automated evidence. This follow-up changes only documentation and evidence, so no new build or test run was performed after the accepted device build. Long-term snapshot compaction remains deferred; old recovery files are deliberately retained.

### Earlier physical-device reports

Handoff 002 records Mario's October 4 report that the lesson ran through completion, quizzes/explanatory feedback worked, and playback, progression, and pauses worked as expected. The pacing was acceptable; he preferred roughly another half-second between screens. These are **user-reported results on the earlier build**. Device model, OS, and installed build SHA were not supplied. Earlier premium-voice and read-along reports remain in the history below.

Before the deployment and acceptance above, the requested physical pass covered premium-voice audition/switching, active speech and reflection-delay pause/resume, manual navigation/scrolling while speaking, closure/reopen, real interruptions/audio-route changes, background/foreground, and VoiceOver/Reduce Motion interaction. Accessibility labels and motion guards were inspected; large text and contrast were tested on simulators.

---

## Historical verification

The following reports are retained as the record of earlier builds and user observations.

## Mac verification

- Xcode: 26.5 (build 17F42), selected at `/Applications/Xcode.app/Contents/Developer`.
- Scheme: `LifeIsLearned` (shared scheme; targets `LifeIsLearned` and `LifeIsLearnedTests`).
- Git: Apple Git 2.50.1. GitHub CLI is authenticated to `Patchagray` over HTTPS with `repo` scope.
- Build destination: iPhone 17 simulator, iOS 26.3.1, UDID `79BA2BB6-62CA-432F-B18B-1C36289EDAC5`.
- Test destination: iPhone 16e simulator, iOS 26.3.1, UDID `20E0C31B-8975-45A3-8E2C-B91BC6C64E66`.

Commands run from the repository root:

```bash
xcodebuild -list -project LifeIsLearned.xcodeproj
xcodebuild -showdestinations -project LifeIsLearned.xcodeproj -scheme LifeIsLearned
xcodebuild -project LifeIsLearned.xcodeproj -scheme LifeIsLearned -destination 'platform=iOS Simulator,id=79BA2BB6-62CA-432F-B18B-1C36289EDAC5' -derivedDataPath /tmp/LifeIsLearned-DerivedData build
xcodebuild -project LifeIsLearned.xcodeproj -scheme LifeIsLearned -destination 'platform=iOS Simulator,id=20E0C31B-8975-45A3-8E2C-B91BC6C64E66' -derivedDataPath /tmp/LifeIsLearned-DerivedData -resultBundlePath /tmp/LifeIsLearned-tests-retry2.xcresult -parallel-testing-enabled NO test
```

The build succeeded. The first test attempt found that the app module had no Swift testability enabled. `SWIFT_ENABLE_TESTABILITY = YES` was added to the project Debug configuration. The next attempt compiled but its simulator test runner exited before connecting (signal 9). Retrying on iPhone 16e with parallel testing disabled succeeded: **8 tests passed, 0 failed**.

The passing tests cover guide-to-storyteller sequencing after the intro, stale callbacks after manual navigation, pause/resume, takeaway stopping before practice, wrong-answer retry and first-try score behavior, progress restoration, invalid-import safety, and source/answer-key validation.

Raw logs and result bundles are kept locally in `/tmp` and excluded from Git:

- `/tmp/LifeIsLearned-build.log`
- `/tmp/LifeIsLearned-test.log` (initial failed attempt)
- `/tmp/LifeIsLearned-test-fixed.log` (simulator bootstrap failure)
- `/tmp/LifeIsLearned-test-retry2.log` (passing run)
- `/tmp/LifeIsLearned-tests-retry2.xcresult`

## Simulator and device checks

- Installed and launched the built app on the iPhone 16e simulator.
- Visually inspected the library screen; it shows “The Influential Mind” and its available lesson. A screenshot is in `Evidence/iPhone16e-library.png`.
- During the original bootstrap, automated state tests exercised core transitions, but a complete UI tap-through and iPad/landscape/large-text layout checks were not completed. Later phone observations and narration-scrolling layout checks are recorded below.
- During the original bootstrap, physical-device speech was not verified by the agent. See the subsequent user-reported phone checks below. No signing identity was changed by the agent.

## Portable checks

The supplied validation report stated that 87 portable checks passed before this Mac build. It checked starter content shape, sources, answer keys, assets, project references, and shared scheme structure. Those checks did not establish native compilation or runtime behavior.


## User-reported phone verification

After installing and running the starter on their phone, the user reported:

- Installed premium voices were available for selection and sounded fine.
- Automatic progression between lesson pages and read-along highlighting worked.
- An intentionally incorrect answer showed the expected explanatory feedback and allowed a retry.
- A correct answer showed positive reinforcement.
- Text extending below the visible area required manual scrolling while narration continued. This prompted the narration-follow scrolling change.

These are the user's physical-device observations of the earlier build, not automated results or agent-observed hardware checks. After the scrolling update was delivered at `ead7e58b2d6fd55cf29d448128e9e94ac85894d6`, the user reported “Everything works fine” and requested that all changes be committed and submitted for review. This records user-reported acceptance of the updated phone experience. Device/OS version and the exact installed binary were not independently verified.

## Narration-follow scrolling

The reader now uses the actual spoken UTF-16 range and rendered text-line geometry to keep narration visible. It scrolls when the line approaches the bottom edge, placing it near the upper third of the reading area. Visible lines do not cause scrolling. The same behavior applies to a revealed takeaway; replay returns to the title. Following stops on pause/stop, yields during manual dragging/deceleration, honors Reduce Motion, and is disabled while VoiceOver is running.

The implementation uses native UIKit text layout inside the existing SwiftUI reader. No lesson content or speech sequencing changed. The user's existing Xcode project formatting and development-team selections were preserved during implementation. They are now included in the review branch at the user's request to commit all remaining changes. Semantic comparison confirms that the project changes add only the app target's existing development-team selection in Debug and Release; the remaining diff is Xcode formatting.

Commands (from the repository root; `test` builds the app and test targets):

```bash
xcodebuild -project LifeIsLearned.xcodeproj -scheme LifeIsLearned -destination 'platform=iOS Simulator,id=20E0C31B-8975-45A3-8E2C-B91BC6C64E66' -derivedDataPath /tmp/LifeIsLearned-Scroll-DerivedData -resultBundlePath /tmp/LifeIsLearned-scroll-final.xcresult -parallel-testing-enabled NO test
xcodebuild -project LifeIsLearned.xcodeproj -scheme LifeIsLearned -destination 'platform=iOS Simulator,id=B219EF2E-CFAA-43D2-8F69-804ED944F678' -derivedDataPath /tmp/LifeIsLearned-Scroll-DerivedData -resultBundlePath /tmp/LifeIsLearned-scroll-ipad-final.xcresult -parallel-testing-enabled NO test
```

- iPhone 16e / iOS 26.3.1: **11 tests passed, 0 failed** (8 existing playback/content tests and 3 new scrolling tests).
- iPad (A16) / iOS 26.3.1: **11 tests passed, 0 failed**, including the actual reader hosted at tablet width and accessibility text size. An earlier targeted iPad run also passed all 3 scrolling tests.
- Sanitized results with production-source hashes and a before/after iPad simulator image pair are in `Evidence/NarrationScrolling/`.
- New coverage: Unicode title/body offsets, invalid or stale ranges, actual line visibility in portrait/landscape/tablet-sized viewports, safe-area insets, pause/replay, Dynamic Type, the actual SwiftUI `ReaderView`, and cancellation of a queued follow operation when playback stops.
- The first new test run caught an incorrect test-fixture assumption that a scroll view always starts at offset zero. The fixture now explicitly sets and checks its insets. The corrected tests passed; production failures were not suppressed.
- Raw logs and `.xcresult` bundles remain in `/tmp/LifeIsLearned-scroll-*` and are not committed. App build products remain in `/tmp/LifeIsLearned-Scroll-DerivedData`.
- Reader screenshots are rendered by the simulator test with an injected spoken range at accessibility text size. They demonstrate layout and scroll movement, not a live speech/audio audition. The user subsequently confirmed the updated phone experience worked fine. This is user-reported functional acceptance; detailed device checks of VoiceOver, Reduce Motion, interruptions, and every manual-drag edge case were not separately documented.

## Review handoff

The review branch contains the narration-scrolling implementation, focused tests, sanitized evidence, user-reported phone acceptance, and the existing Xcode signing-team configuration. Application source is unchanged from the passing simulator runs recorded above. The handoff changes only project metadata and verification documentation, so the simulator tests were not repeated for this commit.
