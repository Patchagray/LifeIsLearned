# Commands and environments

Commands ran from the application repository root. Xcode 26.5 (17F42); iPhone 16e and iPad (A16) simulators, iOS 26.3.1. Raw logs live in ignored `LocalVerification/Handoff006/`; result bundles and derived products remain under `/tmp/LIL006*`.

## Inspect and extract

```sh
git status --short
git branch --show-current
git log -5 --oneline
unzip -l ../LifeIsLearned_HANDOFF_006_Codex.zip
git switch -c feature/handoff-006-explore-distribution
unzip -n ../LifeIsLearned_HANDOFF_006_Codex.zip
pdftotext -layout HANDOFF_006_CODEX.pdf LocalVerification/Handoff006/handoff-pdf.txt
pdftoppm -f 1 -singlefile -scale-to 1200 -png HANDOFF_006_CODEX.pdf LocalVerification/Handoff006/handoff-page1
xcodebuild -version
xcrun simctl list devices booted
gh auth status
gh repo view --json visibility,defaultBranchRef,url
gh repo view Patchagray/LifeIsLearned-Catalog --json url,visibility
```

The source repo was clean at the exact supplied baseline. GitHub CLI was authenticated as Patchagray. The distribution repo did not exist. The existing app repo was public; visibility was not changed. Credential/status output stays local, not in evidence logs.

## Native tests and build

```sh
xcodebuild build-for-testing -project LifeIsLearned.xcodeproj -scheme LifeIsLearned -destination 'platform=iOS Simulator,id=20E0C31B-8975-45A3-8E2C-B91BC6C64E66' -derivedDataPath /tmp/LIL006-final
xcodebuild test -project LifeIsLearned.xcodeproj -scheme LifeIsLearned -destination 'platform=iOS Simulator,id=20E0C31B-8975-45A3-8E2C-B91BC6C64E66' -derivedDataPath /tmp/LIL006-final -resultBundlePath /tmp/LIL006-final-native.xcresult -parallel-testing-enabled NO -only-testing:LifeIsLearnedTests
xcodebuild build -project LifeIsLearned.xcodeproj -scheme LifeIsLearned -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/LIL006-release ARCHS=arm64 ONLY_ACTIVE_ARCH=YES
```

Initial targeted test run: `/tmp/LIL006-native.xcresult`, 35 passed. It covered DiscoveryTests, ExploreContractTests, LibraryV3Tests, PackagedNarrationTests and BookDiscoveryRequestTests. Final full native run supersedes it for acceptance.

## UI tests

Run once per destination below with the matching result name (`phone` / `pad`):

```sh
xcodebuild test-without-building -project LifeIsLearned.xcodeproj -scheme LifeIsLearned -destination 'platform=iOS Simulator,id=20E0C31B-8975-45A3-8E2C-B91BC6C64E66' -derivedDataPath /tmp/LIL006-final -resultBundlePath /tmp/LIL006-final-ui-phone.xcresult -parallel-testing-enabled NO -only-testing:LifeIsLearnedUITests/ExploreUITests -only-testing:LifeIsLearnedUITests/DiscoveryUITests -only-testing:LifeIsLearnedUITests/ScannerRequestUITests -only-testing:LifeIsLearnedUITests/LibraryHistoryUITests
xcodebuild test-without-building -project LifeIsLearned.xcodeproj -scheme LifeIsLearned -destination 'platform=iOS Simulator,id=B219EF2E-CFAA-43D2-8F69-804ED944F678' -derivedDataPath /tmp/LIL006-final -resultBundlePath /tmp/LIL006-final-ui-pad.xcresult -parallel-testing-enabled NO -only-testing:LifeIsLearnedUITests/ExploreUITests -only-testing:LifeIsLearnedUITests/DiscoveryUITests -only-testing:LifeIsLearnedUITests/ScannerRequestUITests -only-testing:LifeIsLearnedUITests/LibraryHistoryUITests
```

Initial UI runs are `/tmp/LIL006-ui-phone.xcresult` and `...ui-pad.xcresult`. They exposed a test assumption about a Cancel row (iOS uses an outside-dismissed popover) and an immediate iPad search-count assertion. Tests now handle the native dismiss interaction and wait for the expected filter count; search fields also disable autocorrection. Initial failures are retained locally. Final runs use the corrected tests and extend the download flow through offload/Restore/reinstall.

All UI runs use isolated UUID directories/defaults and URLProtocol fixtures, never personal Documents or live public package downloads.

## Portable gates

```sh
python3 -m unittest discover -s Tools -p 'test_*.py' -v
python3 -m unittest discover -s Tools -p 'test_distribution.py' -v
python3 Tools/validate_catalog.py
python3 Tools/validate_package.py
python3 Tools/distribution_catalog.py Distribution/catalog.json --audit-directory Distribution
git diff --check
```

The Python suite uses `LIL_FFMPEG` pointing to the existing isolated authoring FFmpeg binary recorded in `LocalVerification/Handoff005/PackagedNarration/ffmpeg-path.txt`. No FFmpeg or ElevenLabs runtime dependency is shipped in the app. Release helper tests mock GitHub commands and anonymous downloads; they do not publish fixtures.

## Evidence export

```sh
xcrun xcresulttool get test-results summary --path /tmp/LIL006-final-native.xcresult --format json
xcrun xcresulttool export attachments --path /tmp/LIL006-final-ui-phone.xcresult --output-path LocalVerification/Handoff006/final-phone-attachments
xcrun xcresulttool export attachments --path /tmp/LIL006-final-ui-pad.xcresult --output-path LocalVerification/Handoff006/final-pad-attachments
```

Screenshots are exported test attachments, labeled simulator/synthetic; original recordings and `.xcresult` files remain local. Public release and anonymous production-download verification commands are documented in `Catalog/PUBLIC_DISTRIBUTION.md` and await owner approval of actual public assets.

## Final copy and accessibility refinements

The following are the actual logged invocations, in order. All completed successfully.

```sh
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild build-for-testing -project LifeIsLearned.xcodeproj -scheme LifeIsLearned -destination "platform=iOS Simulator,id=B219EF2E-CFAA-43D2-8F69-804ED944F678" -derivedDataPath /tmp/LIL006-polish
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild test-without-building -project LifeIsLearned.xcodeproj -scheme LifeIsLearned -destination "platform=iOS Simulator,id=20E0C31B-8975-45A3-8E2C-B91BC6C64E66" -derivedDataPath /tmp/LIL006-polish -resultBundlePath /tmp/LIL006-polish-phone.xcresult -parallel-testing-enabled NO "-only-testing:LifeIsLearnedTests/DiscoveryTests" "-only-testing:LifeIsLearnedTests/ExploreContractTests" "-only-testing:LifeIsLearnedUITests/DiscoveryUITests"
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild test-without-building -project LifeIsLearned.xcodeproj -scheme LifeIsLearned -destination "platform=iOS Simulator,id=B219EF2E-CFAA-43D2-8F69-804ED944F678" -derivedDataPath /tmp/LIL006-polish -resultBundlePath /tmp/LIL006-polish-pad.xcresult -parallel-testing-enabled NO "-only-testing:LifeIsLearnedUITests/DiscoveryUITests"
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild build-for-testing -project LifeIsLearned.xcodeproj -scheme LifeIsLearned -destination "platform=iOS Simulator,id=B219EF2E-CFAA-43D2-8F69-804ED944F678" -derivedDataPath /tmp/LIL006-final
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild test-without-building -project LifeIsLearned.xcodeproj -scheme LifeIsLearned -destination "platform=iOS Simulator,id=20E0C31B-8975-45A3-8E2C-B91BC6C64E66" -derivedDataPath /tmp/LIL006-final -resultBundlePath /tmp/LIL006-accessibility-phone.xcresult -parallel-testing-enabled NO "-only-testing:LifeIsLearnedUITests/ExploreUITests/testExploreAtAccessibilityTextSize" "-only-testing:LifeIsLearnedUITests/DiscoveryUITests"
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild test-without-building -project LifeIsLearned.xcodeproj -scheme LifeIsLearned -destination "platform=iOS Simulator,id=B219EF2E-CFAA-43D2-8F69-804ED944F678" -derivedDataPath /tmp/LIL006-final -resultBundlePath /tmp/LIL006-accessibility-pad.xcresult -parallel-testing-enabled NO "-only-testing:LifeIsLearnedUITests/ExploreUITests/testExploreAtAccessibilityTextSize" "-only-testing:LifeIsLearnedUITests/DiscoveryUITests"
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild build -project LifeIsLearned.xcodeproj -scheme LifeIsLearned -configuration Release -destination "generic/platform=iOS Simulator" -derivedDataPath /tmp/LIL006-release ARCHS=arm64 ONLY_ACTIVE_ARCH=YES
```

Final binary inspection checks the compiled Release executable for the public repository constant and verifies the synthetic discovery hostname/title are absent. `test-results.json` records the checks; raw executable/logs remain local.
