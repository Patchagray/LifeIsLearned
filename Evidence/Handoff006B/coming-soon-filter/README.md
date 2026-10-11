# Explore Coming Soon filter

Tested implementation: `7ca06fd97d07a0c568a91c3cb07ab89e64d571c6`. The owner confirmed the prior catalog configuration fix allows the real published book to download on Patcha.

Explore now defaults to available releases. Show Coming Soon adds planned/unavailable titles and combines with title/author search and shelf selection. The switch is session state and resets off on a new app launch. Explicit scanner/restore focus still displays the requested title. Narrow/large-text layouts can place the switch below the shelf picker.

## Verification

- iPhone 16e simulator (iOS 26.3): 10 DiscoveryTests and 5 ExploreUITests passed.
- iPad (A16) simulator (iOS 26.3): default/toggle and accessibility-text Explore tests passed (2 tests).
- Physical-iPhone Debug build succeeded; staging catalog URL retained. Installed over the existing app and launched successfully on Patcha. No library data was deleted. Owner assessment of the new switch on hardware remains separate from simulator verification.
- Attached screenshots are simulator fixtures. Normal iPhone/iPad screenshots were visually inspected: switch and shelf filter fit together without clipping. Large-text interaction tests passed.

Commands (from repository root):

```sh
xcodebuild -project LifeIsLearned.xcodeproj -scheme LifeIsLearned -destination 'platform=iOS Simulator,id=20E0C31B-8975-45A3-8E2C-B91BC6C64E66' -derivedDataPath /tmp/LIL006B-config -resultBundlePath /tmp/LIL-coming-soon-phone.xcresult -only-testing:LifeIsLearnedTests/DiscoveryTests -only-testing:LifeIsLearnedUITests/ExploreUITests test
xcodebuild -project LifeIsLearned.xcodeproj -scheme LifeIsLearned -destination 'platform=iOS Simulator,id=B219EF2E-CFAA-43D2-8F69-804ED944F678' -derivedDataPath /tmp/LIL006B-config -resultBundlePath /tmp/LIL-coming-soon-pad.xcresult -only-testing:LifeIsLearnedUITests/ExploreUITests/testAvailableByDefaultAndComingSoonToggle -only-testing:LifeIsLearnedUITests/ExploreUITests/testExploreAtAccessibilityTextSize test-without-building
xcodebuild -project LifeIsLearned.xcodeproj -scheme LifeIsLearned -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /tmp/LIL006B-patcha build
xcrun devicectl device install app --device Patcha /tmp/LIL006B-patcha/Build/Products/Debug-iphoneos/LifeIsLearned.app
xcrun devicectl device process launch --device Patcha com.mariosinclair.lifeislearned
```

Raw logs, result bundles and device records remain at `/tmp/LIL-coming-soon-*`. Playback code was not modified; the full playback regression suite was not rerun for this filter change.
