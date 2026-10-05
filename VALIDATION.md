# Validation report

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

### Mario's physical-device evidence and remaining checks

Handoff 002 records Mario's October 4 report that the lesson ran through completion, quizzes/explanatory feedback worked, and playback, progression, and pauses worked as expected. The pacing was acceptable; he preferred roughly another half-second between screens. These are **user-reported results on the earlier build**. Device model, OS, and installed build SHA were not supplied. Earlier premium-voice and read-along reports remain in the history below.

The new implementation still needs a physical-device pass for premium-voice audition/switching, active speech and reflection-delay pause/resume, manual navigation/scrolling while speaking, closure/reopen, real interruptions/audio-route changes, background/foreground, and VoiceOver/Reduce Motion interaction. Accessibility labels and motion guards were inspected; large text and contrast were tested on simulators. No new physical-device verification is claimed. Long-term snapshot compaction is deferred; old recovery files are deliberately retained.

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
