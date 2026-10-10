# Actual verification commands

Tested implementation source: `30985dd98c1ba7898b546fc8cb0757ffee9af5cc`. Commands ran from the app repository unless stated. Raw logs stay local; their hashes are recorded alongside this file. Existing isolated FFmpeg was supplied through `LIL_FFMPEG` for Python audio validation; its private local path is recorded in the H005 audio verification folder.

## native

```sh
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild test -project LifeIsLearned.xcodeproj -scheme LifeIsLearned -destination "platform=iOS Simulator,id=20E0C31B-8975-45A3-8E2C-B91BC6C64E66" -derivedDataPath /tmp/LIL006B -resultBundlePath /tmp/LIL006B-native.xcresult -parallel-testing-enabled NO "-only-testing:LifeIsLearnedTests"
```

## final-build

```sh
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild build-for-testing -project LifeIsLearned.xcodeproj -scheme LifeIsLearned -destination "platform=iOS Simulator,id=20E0C31B-8975-45A3-8E2C-B91BC6C64E66" -derivedDataPath /tmp/LIL006B
```

## final-phone

```sh
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild test-without-building -project LifeIsLearned.xcodeproj -scheme LifeIsLearned -destination "platform=iOS Simulator,id=20E0C31B-8975-45A3-8E2C-B91BC6C64E66" -derivedDataPath /tmp/LIL006B -resultBundlePath /tmp/LIL006B-final-phone.xcresult -parallel-testing-enabled NO "-only-testing:LifeIsLearnedTests/DiscoveryTests" "-only-testing:LifeIsLearnedTests/ExploreContractTests" "-only-testing:LifeIsLearnedUITests/ExploreUITests" "-only-testing:LifeIsLearnedUITests/DiscoveryUITests" "-only-testing:LifeIsLearnedUITests/ScannerRequestUITests" "-only-testing:LifeIsLearnedUITests/LibraryHistoryUITests"
```

## final-pad

```sh
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild test-without-building -project LifeIsLearned.xcodeproj -scheme LifeIsLearned -destination "platform=iOS Simulator,id=B219EF2E-CFAA-43D2-8F69-804ED944F678" -derivedDataPath /tmp/LIL006B -resultBundlePath /tmp/LIL006B-final-pad.xcresult -parallel-testing-enabled NO "-only-testing:LifeIsLearnedUITests/ExploreUITests" "-only-testing:LifeIsLearnedUITests/DiscoveryUITests" "-only-testing:LifeIsLearnedUITests/ScannerRequestUITests" "-only-testing:LifeIsLearnedUITests/LibraryHistoryUITests"
```

## cover-build

```sh
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild build-for-testing -project LifeIsLearned.xcodeproj -scheme LifeIsLearned -destination "platform=iOS Simulator,id=20E0C31B-8975-45A3-8E2C-B91BC6C64E66" -derivedDataPath /tmp/LIL006B-cover
```

## cover-phone

```sh
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild test-without-building -project LifeIsLearned.xcodeproj -scheme LifeIsLearned -destination "platform=iOS Simulator,id=20E0C31B-8975-45A3-8E2C-B91BC6C64E66" -derivedDataPath /tmp/LIL006B-cover -resultBundlePath /tmp/LIL006B-cover-phone.xcresult -parallel-testing-enabled NO "-only-testing:LifeIsLearnedUITests/ExploreUITests/testPlannedCoverPreviewDoesNotEnableDownload"
```

## cover-pad

```sh
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild test-without-building -project LifeIsLearned.xcodeproj -scheme LifeIsLearned -destination "platform=iOS Simulator,id=B219EF2E-CFAA-43D2-8F69-804ED944F678" -derivedDataPath /tmp/LIL006B-cover -resultBundlePath /tmp/LIL006B-cover-pad.xcresult -parallel-testing-enabled NO "-only-testing:LifeIsLearnedUITests/ExploreUITests/testPlannedCoverPreviewDoesNotEnableDownload"
```

## release-build

```sh
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild build -project LifeIsLearned.xcodeproj -scheme LifeIsLearned -configuration Release -destination "generic/platform=iOS Simulator" -derivedDataPath /tmp/LIL006B-release ARCHS=arm64 ONLY_ACTIVE_ARCH=YES
```

## Worker and publication checks

```sh
node --test Backend/CatalogWorker/test/*.test.js
python3 -m unittest discover -s ReleaseGate -p 'test*.py' -v
python3 -m unittest discover -s Tools -p 'test_*.py' -v
python3 Tools/validate_catalog.py
python3 ReleaseGate/publication_preflight.py --package Example-Lesson-Package.json --output LocalVerification/Handoff006B/refused-legacy
```

The last command intentionally exits with denial: the legacy example has no complete studio bundle and no owner approval.

From `Backend/CatalogWorker/`:

```sh
wrangler deploy --env staging --dry-run
wrangler dev --env staging --port 8796
```

Local HTTP smoke exercised `/v1/catalog`, `/healthz`, an unavailable book download and an arbitrary route. Exact statuses/counts are in `local-runtime-smoke.json`. Dry-run bundles only; neither command deploys a live Worker.

## Access and private origin

Authenticated `gh repo view Patchagray/LifeIsLearned-Published --json nameWithOwner,isPrivate,url` and release listing confirmed the private zero-release scaffold. An anonymous GitHub API request returned 404. Cloudflare `wrangler whoami` failed with expired credentials; `wrangler login` timed out waiting for browser authorization. OAuth URLs and credentials are excluded from evidence.

## Screenshot inspection

Viewed phone/tablet Coming Soon previews and accessibility-size captures. The cover rendered, Download remained absent, and long text used vertical scrolling. The large-text captures are scroll positions, not complete-screen fit claims; the phone toolbar title truncates at this extreme size. No physical VoiceOver or camera pass is inferred.
