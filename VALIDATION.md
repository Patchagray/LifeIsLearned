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
- Automated state tests exercise core lesson and practice transitions, but a complete tap-through of the user interface, iPad/landscape layouts, and large accessibility text has not been completed in this session.
- Physical-device narration voice audition and quality checks are **pending**. The connected device was not used for speech verification. No signing identity was changed.

## Portable checks

The supplied validation report stated that 87 portable checks passed before this Mac build. It checked starter content shape, sources, answer keys, assets, project references, and shared scheme structure. Those checks did not establish native compilation or runtime behavior.
