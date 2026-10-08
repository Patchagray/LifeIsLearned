# Actual 005B verification

Xcode 26.5 (17F42), iOS Simulator 26.3.1. Working directory: repository root.

```sh
xcodebuild test -project LifeIsLearned.xcodeproj -scheme LifeIsLearned -destination 'platform=iOS Simulator,id=20E0C31B-8975-45A3-8E2C-B91BC6C64E66' -derivedDataPath /tmp/LIL005-derived -resultBundlePath /tmp/LIL005B-native-final.xcresult -only-testing:LifeIsLearnedTests/LibraryV3Tests -only-testing:LifeIsLearnedTests/CollectionTests -only-testing:LifeIsLearnedTests/IdeaCardTests -only-testing:LifeIsLearnedTests/ContentPolicyTests
xcodebuild test -project LifeIsLearned.xcodeproj -scheme LifeIsLearned -destination 'platform=iOS Simulator,id=20E0C31B-8975-45A3-8E2C-B91BC6C64E66' -derivedDataPath /tmp/LIL005-derived -resultBundlePath /tmp/LIL005B-ui-1.xcresult -only-testing:LifeIsLearnedUITests/LibraryHistoryUITests -only-testing:LifeIsLearnedUITests/IdeaCollectionUITests/testTwentyCardsGridCarouselFlipFavoriteRelaunchAndReview
xcodebuild test -project LifeIsLearned.xcodeproj -scheme LifeIsLearned -destination 'platform=iOS Simulator,id=B219EF2E-CFAA-43D2-8F69-804ED944F678' -derivedDataPath /tmp/LIL005-derived -resultBundlePath /tmp/LIL005B-final.xcresult -only-testing:LifeIsLearnedTests/LibraryV3Tests -only-testing:LifeIsLearnedUITests/LibraryHistoryUITests
xcodebuild test -project LifeIsLearned.xcodeproj -scheme LifeIsLearned -destination 'platform=iOS Simulator,id=20E0C31B-8975-45A3-8E2C-B91BC6C64E66' -destination 'platform=iOS Simulator,id=B219EF2E-CFAA-43D2-8F69-804ED944F678' -derivedDataPath /tmp/LIL005-derived -resultBundlePath /tmp/LIL005B-large.xcresult -only-testing:LifeIsLearnedUITests/LibraryHistoryUITests/testHistoryAtAccessibilityTextSize
```

Final iPhone native selection: **29 passed**. iPhone offload + existing card journey: **2 passed**. iPad storage/offload checkpoint: **5 native + 1 UI passed**. Large-text History: **1 UI passed on each destination**. No skipped tests in these selections.

The final native run adds an explicit unknown historical completion-date regression after code review; no earlier completion event/date is invented by later reinstall or revision completion. New state dumps include before, after offload and after reinstall; all three retained learner-state documents compare equally for the deterministic fixture. Physical-device behavior remains pending. Full milestone regression runs after the remaining epics.
