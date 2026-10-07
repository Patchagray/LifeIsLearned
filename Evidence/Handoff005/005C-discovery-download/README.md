# 005C — Discovery and download evidence

Implementation: the commit containing this file, recorded by exact SHA in the following epic's `test-results.json` update (avoids a self-referential hash).

- All 50 approved identities retained, with planned availability. No public package URLs or unreviewed ISBNs invented.
- Discovery metadata, small integrity-checked thumbnails, cache and catalog identity validation are separate from installed packages.
- Native URLSession download tasks write staging files, report progress, cancel, retain usable system resume data in memory, and verify size/SHA before decoding. HTTPS redirect checks and package ID/revision checks precede existing atomic import.
- Remote source metadata survives install/offload; removed ideas still require acknowledgement.
- Add Books keeps manual Import File and the existing primary library. Scanner is implemented in the following epic.

## Deterministic tests

`DiscoveryTests`: schema/revision/ID/URL/ISBN validation; title/author and shelf search; metadata-only refresh; malformed/offline last-good cache; package byte size and checksum failure; actual URLProtocol download task and staging cleanup; partial progress and cancellation; failed download leaves empty library; successful native install/source; current/update/offloaded/planned/unavailable states; explicit removal acknowledgement.

URLProtocol fixtures never contact public GitHub. Cancellation may supply no resume data; that path is tested as safe cancellation/retry. Actual server interruption/resume remains a production-network release gate, not claimed here.

`DiscoveryUITests`: browse → visible progress → whole-book install → In Library → newer catalog Update → malformed/offline cached catalog, on iPhone 16e and iPad (A16), iOS 26.3.1. Screenshots use a clearly named synthetic interface fixture. The synthetic Update entry tests availability presentation; it is not an approved release package.

Two Python metadata-helper tests and all existing authoring/catalog tests are run. No public release or backend deployment occurred.

## Commands

```sh
xcodebuild test -project LifeIsLearned.xcodeproj -scheme LifeIsLearned \
  -destination 'platform=iOS Simulator,id=20E0C31B-8975-45A3-8E2C-B91BC6C64E66' \
  -destination 'platform=iOS Simulator,id=B219EF2E-CFAA-43D2-8F69-804ED944F678' \
  -derivedDataPath /tmp/LIL005-derived -resultBundlePath /tmp/LIL005C-verified.xcresult \
  -only-testing:LifeIsLearnedTests/DiscoveryTests -only-testing:LifeIsLearnedUITests/DiscoveryUITests
python3 -m unittest discover -s Tools -p 'test_*.py'
python3 Tools/validate_package.py
python3 Tools/validate_catalog.py
```

Raw logs: ignored `LocalVerification/Handoff005/005C-*`. First development run exposed a test fixture raw/canonical byte mismatch; the fixture was corrected to hash the exact bytes served. No integrity checks were weakened. Screenshot inspection found low-contrast button text; the final run uses the explicit on-teal text color. App endpoint values expand through the supplied Info.plist; defaults are empty. See `Catalog/REMOTE_LIBRARY.md` for reviewer configuration and publication steps.
