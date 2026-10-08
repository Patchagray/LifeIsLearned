# 005A actual verification commands

Run from the repository root with Xcode 26.5 (17F42). Destinations: iPhone 16e and iPad (A16), iOS Simulator 26.3.1. The UUIDs below identify local simulators, not physical devices.

```sh
python3 -m unittest discover -s Tools -p test_authoring.py
python3 Tools/validate_package.py
xcodebuild test -project LifeIsLearned.xcodeproj -scheme LifeIsLearned -destination 'platform=iOS Simulator,id=20E0C31B-8975-45A3-8E2C-B91BC6C64E66' -derivedDataPath /tmp/LIL005-derived -resultBundlePath /tmp/LIL005A-3.xcresult -only-testing:LifeIsLearnedTests/Handoff005ATests -only-testing:LifeIsLearnedTests/SixStageLessonTests -only-testing:LifeIsLearnedTests/LessonSessionTests -only-testing:LifeIsLearnedTests/CollectionTests -only-testing:LifeIsLearnedUITests/SixStageReaderUITests
xcodebuild test -project LifeIsLearned.xcodeproj -scheme LifeIsLearned -destination 'platform=iOS Simulator,id=20E0C31B-8975-45A3-8E2C-B91BC6C64E66' -destination 'platform=iOS Simulator,id=B219EF2E-CFAA-43D2-8F69-804ED944F678' -derivedDataPath /tmp/LIL005-derived -resultBundlePath /tmp/LIL005A-reader-native.xcresult -only-testing:LifeIsLearnedTests/SixStageLessonTests -only-testing:LifeIsLearnedUITests/SixStageReaderUITests
```

Outcomes: 21 authoring tests; 400 portable checks; 27 native + 1 UI tests on iPhone. After fixing the iPad accessibility image bounds with a clipped native fill-image view, the affected five native reader tests + one live UI test passed on each device (12 final runs). No tests were skipped in these selections.

Earlier local attempts caught test compilation mistakes and an iPad accessibility frame mismatch (uncropped image bounds of 245 points vs displayed 230). The final native fill-image wrapper resolves that mismatch; height assertions remain unchanged. Raw failed and passing logs remain in `LocalVerification/Handoff005/`.

The frozen starter and example remain byte-for-byte unchanged. Their legacy timing/authoring status is not upgraded by this patch. New authored releases still need reviewed content and measured premium-voice timing.
