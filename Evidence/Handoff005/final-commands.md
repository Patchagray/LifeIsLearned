# Final integration commands

Run from the repository root with Xcode 26.5 (17F42), Python 3 and Node 24.14. Simulator runtime: iOS 26.3.1. UUIDs below identify simulators, not physical devices. Final outcomes and exact source hashes are recorded in `test-results.json` and `tested-source-sha256.json` after successful execution.

## Complete regression and signed build

```sh
python3 -m unittest discover -s Tools -p 'test_*.py'
python3 Tools/validate_package.py
python3 Tools/validate_catalog.py
node --test Backend/RequestAPI/worker.test.mjs

xcodebuild test -project LifeIsLearned.xcodeproj -scheme LifeIsLearned \
  -destination 'platform=iOS Simulator,id=20E0C31B-8975-45A3-8E2C-B91BC6C64E66' \
  -destination 'platform=iOS Simulator,id=B219EF2E-CFAA-43D2-8F69-804ED944F678' \
  -derivedDataPath /tmp/LIL005-derived -resultBundlePath /tmp/LIL005-release-review.xcresult

xcodebuild build -project LifeIsLearned.xcodeproj -scheme LifeIsLearned \
  -destination 'platform=iOS,name=Patcha' -derivedDataPath /tmp/LIL005-patcha
```

Raw stdout/stderr stays under ignored `LocalVerification/Handoff005/`: `final-python.log`, `final-portable.log`, `full-catalog.log`, `final-backend.log`, `release-review.log`, `patcha-release-review-build.log`. The signed build uses the existing signing settings. Compilation is not installation or physical feature verification. The AppIntents metadata tool skips extraction because the app has no AppIntents dependency; Xcode also emits nonfatal debugger-version diagnostics. No failure or compiler error was suppressed.

An earlier unsigned device-SDK check also passed:

```sh
xcodebuild build -project LifeIsLearned.xcodeproj -scheme LifeIsLearned \
  -destination 'generic/platform=iOS' -derivedDataPath /tmp/LIL005-device \
  CODE_SIGNING_ALLOWED=NO
```

## Targeted final card regression

```sh
xcodebuild test -project LifeIsLearned.xcodeproj -scheme LifeIsLearned \
  -destination 'platform=iOS Simulator,id=B219EF2E-CFAA-43D2-8F69-804ED944F678' \
  -derivedDataPath /tmp/LIL005-derived -resultBundlePath /tmp/LIL005-selection-alignment.xcresult \
  -only-testing:LifeIsLearnedTests/IdeaCardPresentationTests/testArrivingCardsDoNotCreateAnUnrequestedSelection \
  -only-testing:LifeIsLearnedUITests/IdeaCollectionUITests/testCompletionGoesDirectlyToSavedNextIdea \
  -only-testing:LifeIsLearnedUITests/IdeaCollectionUITests/testVisibleFavoriteShimmersWhileUnfavoritedCardStaysStill \
  -only-testing:LifeIsLearnedUITests/IdeaCollectionUITests/testAccessibilityTextUsesOneColumnAndReadableCarousel
```

The deterministic selection test recreates staged card arrival: nil must remain nil until the learner opens/chooses a card; an actual prior choice remains selected; removed choices fall back safely. The lazy carousel retains an explicit viewport width, seeded/captured identity and recentering after sheet-width changes. Existing identity/centering assertions remain; manual swiping additionally checks the counter and centered card. Icon-specific compilation/home-screen launch commands and captures are in [005F](005F-brand/README.md).

## Investigation history — not final passing evidence

Earlier attempts remain locally, including their failures. Temporary eager-strip/geometry-selection experiments were discarded after the actual early-selection rule was identified. The grid had selected the first partial result while two fixture collections were still arriving; that unintended selection became card 11 of 20 once the second book arrived. An off-screen card then also caused the favorite-animation screenshot check to fail. A separate sheet-width alignment issue required explicit recentering.

| Local result bundle in `/tmp` | Outcome / purpose |
| --- | --- |
| `LIL005-regression.xcresult`, `LIL005-final-regression.xcresult` | Exposed large-text scanner keyboard reachability; fixed with explicit Done controls and interactive dismissal. |
| `LIL005-keyboard.xcresult` | Focused large-text scanner/request check passed on both simulators. |
| `LIL005-verified-regression.xcresult` | Exposed wrong initial iPad card and scanner test tapping while keyboard remained open. |
| `LIL005-selection.xcresult`, `LIL005-alignment.xcresult`, `LIL005-exact-cards.xcresult`, `LIL005-card-identity.xcresult` | Intermediate card attempts; at least one card alignment/identity failure remained. |
| `LIL005-measured-cards.xcresult` | Six repeated iPad checks passed, but later complete testing showed the attempted fix was insufficient. |
| `LIL005-accepted-regression.xcresult` | iPhone: 93 passed, two skips. iPad: 91 passed, two failures, two skips. |
| `LIL005-card-width.xcresult` | Three focused iPad checks passed; not a complete regression result. |
| `LIL005-complete-regression.xcresult` | iPhone: 93 passed, two skips. iPad: 92 passed, one failure, two skips. Video showed the earlier book's card retained by premature selection. |
| `LIL005-selection-rule.xcresult` | The new deterministic selection rule and grid/carousel/favorite checks passed; a remaining completion-sheet alignment failure led to restoring the explicit recenter step. |

The corresponding `.log` files remain in `LocalVerification/Handoff005/`. Previous failures are not omitted from the record or counted as final passes.

## Evidence extraction

```sh
xcrun xcresulttool get test-results summary --path /tmp/LIL005-release-review.xcresult --format json
xcrun xcresulttool get test-results tests --path /tmp/LIL005-release-review.xcresult --format json
xcrun xcresulttool export attachments --path /tmp/LIL005-release-review.xcresult --output-path /tmp/LIL005-accepted-shots
```

Selected simulator PNG attachments are converted with `sips -s format jpeg -s formatOptions 82 <attachment.png> --out <evidence.jpg>`. The actual icon crops retain their original PNGs. No personal device data, raw debug videos, DerivedData or result bundles are committed. Structured final test cases, source hashes, screenshots and exact implementation commits provide the reviewable evidence.

## Patcha installation and launch

```sh
xcrun devicectl device install app --device Patcha \
  /tmp/LIL005-patcha/Build/Products/Debug-iphoneos/LifeIsLearned.app \
  --json-output LocalVerification/Handoff005/patcha-install.json
```

For launch, the actual Python wrapper removed every `DEVICECTL_CHILD_` entry from the subprocess environment, then ran:

```sh
xcrun devicectl device process launch --device Patcha \
  com.mariosinclair.lifeislearned \
  --json-output LocalVerification/Handoff005/patcha-launch.json
```

Both commands succeeded. The first launch attempt used `--environment-variables '{}'`; this Xcode tool rejected the empty dictionary before launch. Retrying with the filtered subprocess environment above succeeded. Raw attempts are retained locally. No fixture flags, uninstall, data reset or signing changes were used. Physical feature checks remain pending.
