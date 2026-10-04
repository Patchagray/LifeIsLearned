# Validation report

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
