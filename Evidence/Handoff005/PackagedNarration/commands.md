# Audio addendum verification commands

Run from the repository root. Xcode 26.5 (17F42); simulator runtime iOS 26.3.1. Raw logs are in ignored `LocalVerification/Handoff005/PackagedNarration/`; large `.xcresult` bundles are under `/tmp/LIL005-audio-*.xcresult`.

## Native and journey regression

```sh
xcodebuild test -project LifeIsLearned.xcodeproj -scheme LifeIsLearned \
  -destination 'platform=iOS Simulator,id=20E0C31B-8975-45A3-8E2C-B91BC6C64E66' \
  -destination 'platform=iOS Simulator,id=B219EF2E-CFAA-43D2-8F69-804ED944F678' \
  -derivedDataPath /tmp/LIL005-audio \
  -resultBundlePath /tmp/LIL005-audio-verified.xcresult \
  -only-testing:LifeIsLearnedTests \
  -only-testing:LifeIsLearnedUITests/PackagedNarrationUITests \
  -only-testing:LifeIsLearnedUITests/SixStageReaderUITests \
  -only-testing:LifeIsLearnedUITests/LearningJourneyUITests
```

The real Files-import fixture was already present from prior H005 verification. On a fresh simulator, first run `python3 Tools/prepare_simulator_import.py SIMULATOR_UDID` for each booted destination.

Additional affected card/review/large-text journeys used the same command with result bundle `/tmp/LIL005-audio-cards.xcresult` and these selections instead:

```sh
-only-testing:LifeIsLearnedUITests/IdeaCollectionUITests/testTwentyCardsGridCarouselFlipFavoriteRelaunchAndReview
-only-testing:LifeIsLearnedUITests/IdeaCollectionUITests/testAccessibilityTextUsesOneColumnAndReadableCarousel
-only-testing:LifeIsLearnedUITests/IdeaCollectionUITests/testCompletionGoesDirectlyToSavedNextIdea
-only-testing:LifeIsLearnedUITests/DiveDeeperUITests
```

Final audio-only rerun (after tolerant optional cue decoding and a whitespace cleanup) used the same two destinations and DerivedData, result bundle `/tmp/LIL005-audio-final.xcresult`, with:

```sh
-only-testing:LifeIsLearnedTests/PackagedNarrationTests
-only-testing:LifeIsLearnedUITests/PackagedNarrationUITests
```

## Python, package and catalog

`LIL_FFMPEG` was set to the isolated authoring binary recorded in local `ffmpeg-path.txt` (imageio-ffmpeg 0.6.0). A normal installed `ffmpeg` on PATH also works. It is not bundled in the app.

```sh
python3 -m unittest discover -s Tools -p 'test_*.py' -v
python3 Tools/validate_package.py --report LocalVerification/Handoff005/PackagedNarration/portable-final.json
python3 Tools/validate_catalog.py
python3 Tools/validate_package.py Evidence/Handoff005/PackagedNarration/audio-tone-package-fixture.json \
  --audio-gate --report Evidence/Handoff005/PackagedNarration/audio-validation.json
python3 Tools/normalize_narration.py Tools/Fixtures/narration-tone.mp3 \
  LocalVerification/Handoff005/PackagedNarration/normalized-tone.mp3 \
  --report LocalVerification/Handoff005/PackagedNarration/normalization.json
```

Swift-emitted exact scripts were compared with Python `narration_audio.scripts()` for every ID, role, text and stage; every exported SHA was compared with the fixture bundle. `script-parity.json` records the result. The tone is a synthetic test signal, never speech/voice-quality evidence or a release approval.

## Device build and installation

```sh
xcodebuild -project LifeIsLearned.xcodeproj -scheme LifeIsLearned \
  -destination 'platform=iOS,name=Patcha' -derivedDataPath /tmp/LIL005-audio-patcha build
codesign --verify --deep --strict /tmp/LIL005-audio-patcha/Build/Products/Debug-iphoneos/LifeIsLearned.app
xcrun devicectl device install app --device Patcha \
  /tmp/LIL005-audio-patcha/Build/Products/Debug-iphoneos/LifeIsLearned.app \
  --json-output LocalVerification/Handoff005/PackagedNarration/patcha-delivery-install.json
xcrun devicectl device process launch --device Patcha com.mariosinclair.lifeislearned \
  --json-output LocalVerification/Handoff005/PackagedNarration/patcha-delivery-launch.json
```

Launch was invoked with all inherited `DEVICECTL_CHILD_*` environment flags removed; no fixture/reset flags were supplied. Installation is in-place. Device feature outcomes are separate from installation; see `deployment.json` and `physical-checks.md`. No physical iPad install was performed.

## Evidence extraction

```sh
xcrun xcresulttool get test-results summary --path /tmp/LIL005-audio-verified.xcresult --format json
xcrun xcresulttool export attachments --path /tmp/LIL005-audio-verified.xcresult \
  --output-path LocalVerification/Handoff005/PackagedNarration/attachments
```

Only relevant simulator screenshots and synthetic JSON attachments are checked in. Device identifiers, provisioning details, raw logs, DerivedData and result bundles remain local.
