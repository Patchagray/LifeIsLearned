# 005F — reviewer-selected Idea Fold

The reviewer selected **A — Idea Fold** in the implementation conversation on 2026-10-07. Final production sources were created only after that selection. See [brand brief, editable sources and reproducible renderer](../../../Brand/README.md).

## Assets and verification

- Any, Dark and Tinted: opaque sRGB 1024×1024 PNGs, square outer bounds and generous mark margins.
- AppIcon is selected in both Debug and Release. Xcode 26.5 compiles all three appearances; no missing-icon warning was emitted.
- `BrandTests.testProductionIconIsCompiledIntoAppBundle` verifies the built bundle's AppIcon metadata and loads each declared icon file.
- `BrandUITests.testSelectedIconOnHomeScreenLaunchesApp` captures the **actual installed home-screen icon**, taps it and verifies the library opens. Two tests passed on each iOS 26.3.1 destination, zero failures/skips.
- [iPhone 16e home-screen icon](iphone-simulator-home-icon.png) and [iPad (A16) home-screen icon](ipad-simulator-home-icon.png) are simulator element screenshots, excluding unrelated apps. These are not physical-device captures. Source variants were also inspected at full resolution.
- The signed Patcha build with these assets succeeded using the existing signing configuration. Installation and manual device checks are recorded separately in the final evidence index.

```sh
swift Brand/render-icon.swift
sips -g pixelWidth -g pixelHeight -g hasAlpha LifeIsLearned/Resources/Assets.xcassets/AppIcon.appiconset/*.png
xcodebuild test -project LifeIsLearned.xcodeproj -scheme LifeIsLearned \
  -destination 'platform=iOS Simulator,id=20E0C31B-8975-45A3-8E2C-B91BC6C64E66' \
  -destination 'platform=iOS Simulator,id=B219EF2E-CFAA-43D2-8F69-804ED944F678' \
  -derivedDataPath /tmp/LIL005-derived -resultBundlePath /tmp/LIL005F-brand.xcresult \
  -only-testing:LifeIsLearnedTests/BrandTests \
  -only-testing:LifeIsLearnedUITests/BrandUITests
xcodebuild build -project LifeIsLearned.xcodeproj -scheme LifeIsLearned \
  -destination 'platform=iOS,name=Patcha' -derivedDataPath /tmp/LIL005-patcha
```

Raw logs: ignored `LocalVerification/Handoff005/brand.log`, `brand-export.log`, `patcha-icon-build.log`; result bundle `/tmp/LIL005F-brand.xcresult`. The final full regression included both tests again and passed on both simulators. Physical dark/tinted preference and home-screen appearance remain reviewer checks. Production endpoint publication and real-network smoke are separate release gates; no services were deployed.
