# Handoff 003 — review evidence

Implementation commit: **`f78c7f1781b6fa2087559d138c2b4947b0dcfc52`**

Branch: **`feature/handoff-003-content-limits`**

Base: accepted Handoff 002, `d10a60f84b9921cd24a74666b5877359f0623090`. Evidence follow-up changes documentation/screenshots only. The app installed on PATCHA is built from the implementation commit.

## Results

- **iPhone 16e / iPad (A16), iOS 26.3.1:** build succeeded on both; each has 35 passed, 0 failed, 1 intentional hardware-voice skip. This comprises 32 passing unit/layout tests plus three actual-app UI tests.
- **Python:** 12 tests passed; 320 structural/header/project checks passed.
- **Physical iPhone 15 Pro Max, iOS 27.2 (24B5089g):** one premium narration test passed, no skips. Signed build, in-place install and foreground launch succeeded.
- **Demo timing:** 413 spoken words; 240.62-second whole-idea plan. Premium callback measurement: 175.17 seconds narration + 10 seconds pauses + 40 seconds answer allowance = **225.17 seconds**. Guide Jamie (Premium), storyteller Serena (Premium); normal speed 1.0 and 2-second page pause.
- **Preservation:** speech service and startup seed match the baseline byte for byte. Native stored-100 migration/update tests retain all progress. No signing-file changes or automatic content replacement.

[Machine-readable verification](verification.json) records source/log/screenshot SHA-256 hashes, exact simulator commands, destinations, stress memory observations and pending checks. [Premium measurement](premium-reference-timing.json) contains the actual voice IDs and segment durations; [release report](short-demo-timing-report.json) binds those observations to the exact revision and narration. Final native attachments on both simulators match every measured segment's ID, role and text. Timing/structure approval does not replace source and answer-key review.

The physical measurement ran before a word-count allocation optimization; exact narration and the speech service are unchanged. It measures production callback completion, with a fixed answer allowance, rather than a human's learning time. Overall physical-device acceptance is user-reported below; individual voice audition and interruption/audio-route/background/VoiceOver results were not itemized. The two complete companion books are curated externally for later import.

## Commands actually run

Xcode 26.5 (17F42), shared `LifeIsLearned` scheme. Run from the repository root. Result bundle paths must be new when reproducing a run. Before a full simulator UI suite, boot that simulator and prepare its Files-provider fixture:

```bash
python3 Tools/prepare_simulator_import.py 20E0C31B-8975-45A3-8E2C-B91BC6C64E66
python3 Tools/prepare_simulator_import.py B219EF2E-CFAA-43D2-8F69-804ED944F678
python3 Tools/test_authoring.py > /tmp/LifeIsLearned-h003-authoring-final.log 2>&1
python3 Tools/validate_package.py --report /tmp/LifeIsLearned-h003-structural-final.json > /tmp/LifeIsLearned-h003-structural-final.log 2>&1
python3 Tools/validate_package.py Example-Lesson-Package.json --approve-release --measurements Evidence/Handoff003/premium-reference-timing.json --report Evidence/Handoff003/short-demo-timing-report.json > /tmp/LifeIsLearned-h003-release-gate-final.log 2>&1
xcodebuild -project LifeIsLearned.xcodeproj -scheme LifeIsLearned -configuration Debug -destination 'platform=iOS Simulator,id=20E0C31B-8975-45A3-8E2C-B91BC6C64E66' -derivedDataPath /tmp/LifeIsLearned-H003-DerivedData -resultBundlePath /tmp/LifeIsLearned-h003-phone-final.xcresult -parallel-testing-enabled NO test > /tmp/LifeIsLearned-h003-phone-final.log 2>&1
xcodebuild -project LifeIsLearned.xcodeproj -scheme LifeIsLearned -configuration Debug -destination 'platform=iOS Simulator,id=B219EF2E-CFAA-43D2-8F69-804ED944F678' -derivedDataPath /tmp/LifeIsLearned-H003-iPad-DerivedData -resultBundlePath /tmp/LifeIsLearned-h003-ipad-final.xcresult -parallel-testing-enabled NO test > /tmp/LifeIsLearned-h003-ipad-final.log 2>&1
```

The device commands below redact the private UDID and existing signing team. The unredacted logs remain local. No signing identity was changed.

```bash
xcodebuild -project LifeIsLearned.xcodeproj -scheme LifeIsLearned -configuration Debug -destination 'platform=iOS,id=<PRIVATE_DEVICE_UDID>' -derivedDataPath /tmp/LifeIsLearned-H003-Device-DerivedData -resultBundlePath /tmp/LifeIsLearned-h003-premium-first.xcresult -parallel-testing-enabled NO -only-testing:LifeIsLearnedTests/PremiumNarrationTimingTests -allowProvisioningUpdates DEVELOPMENT_TEAM=<EXISTING_TEAM> test > /tmp/LifeIsLearned-h003-premium-first.log 2>&1
xcodebuild -project LifeIsLearned.xcodeproj -scheme LifeIsLearned -configuration Debug -destination 'platform=iOS,id=<PRIVATE_DEVICE_UDID>' -derivedDataPath /tmp/LifeIsLearned-H003-Device-DerivedData -allowProvisioningUpdates DEVELOPMENT_TEAM=<EXISTING_TEAM> build > /tmp/LifeIsLearned-h003-device-final-build.log 2>&1
xcrun devicectl device install app --device <PRIVATE_DEVICE_UDID> /tmp/LifeIsLearned-H003-Device-DerivedData/Build/Products/Debug-iphoneos/LifeIsLearned.app --json-output /tmp/LifeIsLearned-h003-device-install.json > /tmp/LifeIsLearned-h003-device-install.log 2>&1
xcrun devicectl device process launch --device <PRIVATE_DEVICE_UDID> com.mariosinclair.lifeislearned --json-output /tmp/LifeIsLearned-h003-device-launch.json > /tmp/LifeIsLearned-h003-device-launch.log 2>&1
```

## Simulator gallery

All images below are **simulator captures**, compressed to JPEG with a maximum dimension of 1600 pixels; no layout retouching. Source and published hashes are recorded in verification.json. The actual-app images come from UI automation. Large-text images come from hosted SwiftUI layout tests using the unchanged revision-1 lesson; they show a scrollable viewport, not the entire page or live premium speech.

The preface images show the preserved revision-1 seed. The update/reader/practice/completion images show revision 2 selected and confirmed through the real Files picker. Completion intentionally shows **1 of 2 first-try correct** after testing an incorrect response, relaunch and retry. The old seed's complete estimate is approximately eight minutes; the separately imported shortened update is approximately five. No legacy content is silently rewritten to change that number.

| View | iPhone simulator | iPad simulator |
| --- | --- | --- |
| Selection/coverage before start | [View](Screenshots/iphone-selection-preface.jpg) | [View](Screenshots/ipad-selection-preface.jpg) |
| Actual Files picker | [View](Screenshots/iphone-manual-files-picker.jpg) | [View](Screenshots/ipad-manual-files-picker.jpg) |
| Complete-update review | [View](Screenshots/iphone-short-demo-update-review.jpg) | [View](Screenshots/ipad-short-demo-update-review.jpg) |
| Shortened revision and duration | [View](Screenshots/iphone-short-demo-ready.jpg) | [View](Screenshots/ipad-short-demo-ready.jpg) |
| Shortened reader | [View](Screenshots/iphone-live-simulator-reader.jpg) | [View](Screenshots/ipad-live-simulator-reader.jpg) |
| Incorrect-answer feedback | [View](Screenshots/iphone-live-simulator-incorrect-feedback.jpg) | [View](Screenshots/ipad-live-simulator-incorrect-feedback.jpg) |
| Completion after retry | [View](Screenshots/iphone-live-simulator-completion.jpg) | [View](Screenshots/ipad-live-simulator-completion.jpg) |
| Large-text layout, legacy reader | [View](Screenshots/iphone-reader-large-text.jpg) | [View](Screenshots/ipad-reader-large-text.jpg) |

## User-reported device acceptance

After the committed Handoff 003 build was installed and launched on PATCHA, Mario reported **“everything works.”** This records overall user-reported device acceptance. Individual voice audition, interruption/audio-route, background/foreground and accessibility scenarios were not itemized; the statement is not presented as a separate measured result for each scenario.

## Local evidence and limits

Raw development logs (including failed attempts), final iPhone/iPad result bundles, the physical timing result bundle, and private install/launch JSON are archived in **`LocalVerification/Handoff003/`** at the repository root. This entire folder is Git-ignored. DerivedData stays outside the repository under `/tmp`. Raw attachment manifests can include device identifiers and are not published.

Native stress tests import, persist and reopen 12 ideas × 40 pages with 43 valid shared asset entries and a cover, validating every reference and byte. These entries deliberately reuse the original image bytes; this is count/resource verification, not 43 distinct illustrations. Main-actor heartbeats and sampled resident bytes are observations from Debug simulators, not device-performance guarantees. The synthetic stress fixture is not within the editorial timing budget and is never presented as an authored release.

Initial development failures were repaired: Swift exclusivity in a new test fixture and insufficient first-launch Files-provider waiting in the UI test. Tests were not weakened. A premature result-attachment export was retried after Xcode finalized the bundle. Xcode/AVAudioSession diagnostics are retained locally; successful completion is not a subjective audio-quality assertion. See [VALIDATION.md](../../VALIDATION.md) for acceptance coverage and remaining physical checks.

## Try the shortened update

1. Open `LifeIsLearned.xcodeproj` in Xcode, select **LifeIsLearned** and **PATCHA**, then **⌘R**. The committed build is already installed and launched.
2. Save the repository's `Example-Lesson-Package.json` to Files on the phone (for example, AirDrop it from Finder).
3. In Life Is Learned, tap **+ / Import book**, select the JSON, inspect the complete-update preview, then tap **Import complete update → Open book**.
4. Start **The Prior Problem**. The six-screen revision is unpracticed; the previous revision's history remains archived. The app does not automatically import this update over your current collection.
