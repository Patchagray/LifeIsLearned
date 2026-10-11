# Published catalog cover — 2026-10-10

The owner requested that published-book covers appear in Explore and be cached instead of bundled in the app. The existing app already implements SHA-256 image validation and disk caching; the published `approved-covers.json` was empty. No iOS implementation change was needed.

Published commit: `79caa6ff1f60bb5e80ac4ab36e234f4a254f9ff3` in private `Patchagray/LifeIsLearned-Published`.

- Book: `thanks-for-the-feedback`, collection revision 1.
- Cover: exact original package `coverAssetID` bytes, JPEG, 1024 × 1536, 477,447 bytes.
- SHA-256: `1bda194993a5f5ed35baca6ea842591dab44b8e9a3bf90b9959cc7259100a776`.
- Original source package hash matched the existing approved release registry before extraction.
- Owner request recorded as cover authorization in the private published repository. No private image bytes or approval record are copied into this app-source evidence.
- Live staging catalog returns the thumbnail URL/hash/size and retains available package metadata.
- Live `/v1/covers/thanks-for-the-feedback` returns exact expected bytes and hash. Image native dimensions checked with `sips`; cover visually inspected.
- 4 extraction-tool tests and 4 existing remote metadata tests passed.
- 2 existing simulator image integrity/cache tests passed, proving a second retrieval makes no network request even offline and rejecting tampered cached bytes.

Commands:

```sh
python3 -m unittest discover -s Tools -p test_catalog_cover.py -v
python3 -m unittest discover -s Tools -p test_remote_catalog.py -v
xcodebuild -project LifeIsLearned.xcodeproj -scheme LifeIsLearned -destination 'platform=iOS Simulator,id=20E0C31B-8975-45A3-8E2C-B91BC6C64E66' -derivedDataPath /tmp/LIL006B-config -resultBundlePath /tmp/LIL-cover-cache.xcresult -only-testing:LifeIsLearnedTests/DiscoveryTests/testApprovedThumbnailCacheWorksOfflineAndRejectsTampering -only-testing:LifeIsLearnedTests/DiscoveryTests/testThumbnailIntegrityAndNativeImageBudgets test-without-building
curl -fsS https://lifeislearned-catalog-staging.marioams2.workers.dev/v1/catalog -o /tmp/LIL-cover-live-catalog.json
curl -fsS https://lifeislearned-catalog-staging.marioams2.workers.dev/v1/covers/thanks-for-the-feedback -o /tmp/LIL-cover-live.jpg
```

Raw results remain in `/tmp/LIL-cover-*`. Tests use the existing unchanged iOS implementation built for the Coming Soon filter. No reinstallation or app rebuild is needed. Refresh Explore to receive the added cover metadata. Actual device observation of this newly published cover is pending; the owner already confirmed the book download itself works.

Future releases use `Tools/extract_catalog_cover.py` and the added cover-publication instructions in `ReleaseGate/README.md`. The helper emits registry metadata, never issues approval or publishes automatically. Covers reuse the disk cache while present; changed content hashes, cache eviction or OS cache cleanup can trigger another fetch.
