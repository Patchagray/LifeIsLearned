# Verification commands

Run at repository root. Xcode 26.5 (17F42). Raw logs, device copies and restore manifests are under ignored `LocalVerification/Handoff005/Recovery/`; result bundles are outside Git in `/tmp`.

## Simulator regression

```sh
xcodebuild test -project LifeIsLearned.xcodeproj -scheme LifeIsLearned \
  -destination 'platform=iOS Simulator,id=20E0C31B-8975-45A3-8E2C-B91BC6C64E66' \
  -derivedDataPath /tmp/LIL005-audio -resultBundlePath /tmp/LIL005-recovery.xcresult \
  -only-testing:LifeIsLearnedTests/LibraryV3Tests \
  -only-testing:LifeIsLearnedTests/CollectionTests \
  -only-testing:LifeIsLearnedTests/PackagedNarrationTests
```

## Physical build and tests

```sh
xcodebuild -project LifeIsLearned.xcodeproj -scheme LifeIsLearned \
  -destination 'platform=iOS,name=Patcha' -derivedDataPath /tmp/LIL005-recovery-patcha build
codesign --verify --deep --strict /tmp/LIL005-recovery-patcha/Build/Products/Debug-iphoneos/LifeIsLearned.app
```

The device `build-for-testing` used the same project/scheme/destination/DerivedData with `DEVELOPMENT_TEAM` set on the command line to the app's already configured team. This gave the test targets the existing identity without changing project signing. The first test build, without that override, failed because the test targets have no team configured; no signing identity was replaced and no provisioning-update flag was used.

A private copy of the generated `.xctestrun` was kept alongside its products as `Recovery-opt-in.xctestrun` to preserve `__TESTROOT__`. Only the UI test runner EnvironmentVariables received `LIL_VERIFY_EXISTING_LIBRARY=1`; no app reset/fixture environment variables were added.

```sh
xcodebuild test-without-building \
  -xctestrun /tmp/LIL005-recovery-patcha/Build/Products/Recovery-opt-in.xctestrun \
  -destination 'platform=iOS,name=Patcha' -resultBundlePath /tmp/LIL005-recovery-device.xcresult \
  -only-testing:LifeIsLearnedTests/LibraryV3Tests \
  -only-testing:LifeIsLearnedUITests/ExistingLibraryRecoveryUITests
```

## Data-preserving device repair

`xcrun devicectl device copy from` with appDataContainer domain copied Documents before repair. The private repair script required the live CURRENT pointer to still match the backup, and required each recovered payload's size and SHA-256 to match its installed record before calling `device copy to`. Only missing package files were copied. It did not replace CURRENT or learner-state files. Device paths and authored book payloads are intentionally excluded from public evidence.

```sh
xcrun devicectl device install app --device Patcha \
  /tmp/LIL005-recovery-patcha/Build/Products/Debug-iphoneos/LifeIsLearned.app
xcrun devicectl device process launch --device Patcha --terminate-existing com.mariosinclair.lifeislearned
```

Normal launch cleared inherited `DEVICECTL_CHILD_*` flags. Fresh Documents copies were compared against the preserved before-repair copy; payload size/checksums were checked against both current and previous installed records. No iPad install or automatic merge is part of this fix.

## Native read of the recovered data copy

The local `RecoveryCheck.swift` driver copied the recovered Documents directory to a new ignored directory, then called the actual `LibraryStorage.load` and `confirmLaunch` three times. It compiled these unchanged app sources with `swiftc`: `LessonPackage.swift`, `CollectionContract.swift`, `PackagedNarration.swift`, `LibraryState.swift`, `LessonProgress.swift`, `DiveDeeper.swift`, `LessonTiming.swift`, `IdeaCardRecord.swift`, `CollectionStorage.swift`, `IdeaCardStorage.swift`, `LibraryStorage.swift`, and `InstalledPayload.swift`. A no-op `AudioPreflight.importWarnings` shim only satisfied a compile-time production-import dependency; the stored-content load path does not call it. Full stored package validation, image decode, checksums and learner-state decoding used the app implementation. No device backup was modified by this check.

```sh
LocalVerification/Handoff005/Recovery/check-recovered \
  LocalVerification/Handoff005/Recovery/device-documents-restored
```

The sanitized result is `native-recovered-state.json`. The inputs and complete local driver/build artifacts are retained privately because they validate the owner's real library.
