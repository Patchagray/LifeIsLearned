# 005D — On-device recognition and reviewed requests

Implementation SHA is recorded by the following evidence update; this commit contains the source, test fixtures and captures.

Native VisionKit recognizes EAN-13 ISBN barcodes and cover text locally. Matching prioritizes a valid exact ISBN, then normalized title/author similarity. Results are always presented for learner selection, including ambiguous matches. Unknown metadata stays editable before an explicit Request action. Camera-unavailable/denied states retain typed title/ISBN search; denied permission also offers Open Settings. No image upload or lesson generation path exists.

Add Books now includes Scan a Book. Planned/unavailable discovery rows offer Request. The HTTP client is independent of backend implementation, validates bounded HTTPS responses and reports success, rate-limit and network/configuration errors. No request is sent from initialization or view appearance. A successful form cannot accidentally resubmit itself.

`Backend/RequestAPI/` contains the undeployed Worker/D1 reference, strict metadata boundary, alias deduplication, counts/dates, salted temporary rate limits, authenticated editorial query instructions and four local SQLite/HTTP tests. No production endpoint, database, route or secret was created.

## Commands

```sh
xcodebuild test -project LifeIsLearned.xcodeproj -scheme LifeIsLearned \
  -destination 'platform=iOS Simulator,id=20E0C31B-8975-45A3-8E2C-B91BC6C64E66' \
  -destination 'platform=iOS Simulator,id=B219EF2E-CFAA-43D2-8F69-804ED944F678' \
  -derivedDataPath /tmp/LIL005-derived -resultBundlePath /tmp/LIL005D-final.xcresult \
  -only-testing:LifeIsLearnedTests/BookDiscoveryRequestTests \
  -only-testing:LifeIsLearnedTests/DiscoveryTests \
  -only-testing:LifeIsLearnedUITests/ScannerRequestUITests
node --test Backend/RequestAPI/worker.test.mjs
```

Raw logs: ignored `LocalVerification/Handoff005/005D-*`. Simulator captures demonstrate manual ISBN input and title-text fallback, match review, metadata review, and accepted fixture response. The ISBN association is explicitly synthetic in the DEBUG-only fixture; it is not published metadata. No camera recognition performance is inferred from typed input. The first UI capture exposed a keyboard obscuring the match; Find matches now dismisses editing before showing results.

**Pending hardware:** real cover OCR/barcode accuracy, camera permission dialog/denial on a device, movement/lighting behavior. **Pending release:** actual backend deployment and real-network request smoke. Local SQL tests cover the reference contract, not Cloudflare production behavior.
