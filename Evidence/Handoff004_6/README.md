# Handoff 004.6 verification

Baseline: `11742da7aa896ffb4ea77c5f2117d49fd93b5254` (`feature/catalog-001-foundation`).
Implementation: `dd193108db97166fdcd07cd047ae42ed4f030c3c` on `feature/handoff-004-6-six-stage-lessons`.
The subsequent evidence commit contains reports/screenshots only. Awaiting reviewer approval; no merge or content rebuild.

## Implemented contract

- Additive `application` page kind; formatVersion remains 2. Runtime imports/storage keep valid 2–40-page compatibility.
- New authoring/release gates require intro/explanation/story/story/application/takeaway and guide/guide/storyteller/storyteller/guide/guide, exactly two questions, six distinct referenced images with descriptions, and no repeated resolved bytes inside an idea. Across-idea reuse warns. Existing timing, source, manifest and resource checks remain.
- Canonical lessons show five progress stages with widths 1:1:2:1:1. Story A fills half of Story; Story B fills all of it. VoiceOver labels preserve physical screen counts. Large text uses the current stage above the same weighted track. Other sequences retain per-page capsules.
- Short canonical stages use compact artwork/spacing; Hook scope notes remain available in a disclosure. Every reader remains manually scrollable. Takeaway artwork is visible before and after revealing text; practice remains gated by reveal.
- Narration following is enabled only for Story pages. Highlighting remains available on other stages. Page changes still reset the scroll position; the former unconditional scroll-to-top on spoken title callbacks was removed so non-Story narration cannot drift and a callback cannot override a manual drag. TextKit following retains gesture, Reduce Motion, VoiceOver, pause and stale-operation guards.
- Source packages, IDs, revisions, narration scripts, card snapshots, storage and signing configuration were preserved. Handoff 005 offload is documented only.

## Final results — October 6, 2026

| Destination / check | Outcome |
| --- | --- |
| iPhone 16e simulator, full build + native/UI suites | **58 passed, 0 failed, 2 explicit skips** |
| iPad (A16) simulator, same build, native + UI suites | **58 passed, 0 failed, 2 explicit skips** |
| Python authoring suite | **18 passed** |
| Python catalog suite | **18 passed** |
| Portable package/project validation | **384 structural/header checks passed** |
| Synthetic canonical fixture, `--authoring-gate` | Passed; 240.62-second estimate, release not approved |
| Catalog 001 validator | Passed, revision 1; approved 50 books/eight shelves |

Each simulator has 48 passing native tests and ten passing actual-app UI tests. The two explicit skips are hardware premium-voice measurement and the existing H004 test conditional on the system Reduce Motion setting. H004.6 deterministic motion/VoiceOver/gesture guard tests pass. Full UI runs include the Files import, incorrect answer/relaunch/retry/first-attempt score, card/favorite persistence and direct next-idea journey. No new failure remains.

See [machine-readable results](test-results.json), [iPhone results](iphone-final-results.txt), [iPad native results](ipad-native-results.txt), [iPad UI results](ipad-ui-results.txt), [authoring output](authoring-tests.txt), and [catalog output](catalog-tests.txt).

## Reproducible commands

Run from the repository root with Xcode 26.5 (17F42). Both simulator destinations use iOS 26.3.1.

```sh
python3 Tools/validate_package.py
python3 -m unittest discover -s Tools -p 'test_authoring.py' -v
python3 Tools/validate_catalog.py
python3 -m unittest discover -s Tools -p 'test_catalog.py' -v
python3 Tools/prepare_simulator_import.py 20E0C31B-8975-45A3-8E2C-B91BC6C64E66
python3 Tools/prepare_simulator_import.py B219EF2E-CFAA-43D2-8F69-804ED944F678
xcodebuild test -project LifeIsLearned.xcodeproj -scheme LifeIsLearned -destination 'platform=iOS Simulator,id=20E0C31B-8975-45A3-8E2C-B91BC6C64E66' -derivedDataPath /tmp/LIL0046-derived -resultBundlePath /tmp/LIL0046-iphone-final.xcresult
xcodebuild test-without-building -project LifeIsLearned.xcodeproj -scheme LifeIsLearned -destination 'platform=iOS Simulator,id=B219EF2E-CFAA-43D2-8F69-804ED944F678' -derivedDataPath /tmp/LIL0046-derived -resultBundlePath /tmp/LIL0046-ipad-native.xcresult -only-testing:LifeIsLearnedTests
xcodebuild test-without-building -project LifeIsLearned.xcodeproj -scheme LifeIsLearned -destination 'platform=iOS Simulator,id=B219EF2E-CFAA-43D2-8F69-804ED944F678' -derivedDataPath /tmp/LIL0046-derived -resultBundlePath /tmp/LIL0046-ipad-ui.xcresult -only-testing:LifeIsLearnedUITests
```

Result paths must be new when reproducing. The iPhone `test` command compiles the universal simulator app and both test targets. iPad `test-without-building` runs those same compiled products. Files fixtures are synthetic and prepared in the simulators, never in the user's device library.

The passing authoring CLI fixture was generated in ignored `LocalVerification/Handoff004_6/synthetic-canonical.json` from `AuthoringTests.canonical()`, then checked using:

```sh
python3 Tools/validate_package.py LocalVerification/Handoff004_6/synthetic-canonical.json --authoring-gate --report LocalVerification/Handoff004_6/canonical-authoring-report.json
```

Its six distinct one-pixel PNGs verify only bytes/references/structure. They are not acceptable instructional artwork. The published CLI result therefore says release **not approved**, with premium measurement pending. Existing starter/example files remain valid runtime packages but intentionally do not pass the new authoring standard.

## Evidence and limits

`source-integrity.json` identifies every changed file and its tested hash, plus 21 protected files compared byte-for-byte to the baseline. Project edits register two focused source files and one test file; signing settings and the shared scheme are unchanged.

Native tests check application decoding/persistence, legacy 2/5/6/7/8/40-page acceptance, exact stage recognition/fallback and fills, long text geometry, no following on non-Story stages, gesture priority, simulated VoiceOver state and animated/nonanimated scroll requests. Actual-app UI automation checks accessible physical stage labels, visible takeaway artwork, reveal/practice boundaries, and no automatic playback. Existing regression tests cover imports, revisions, archived progress, favorites/cards, completion/next-idea behavior, pause/replay/cancelled callbacks, retry and first-attempt scoring.

Screenshots use synthetic fixture content and reused existing illustrations solely to test rendering; no book is re-authored or imported into the normal library. Canonical layout captures are native-hosted production ReaderView states. `story-long-follow` injects a spoken range into an overflowing Story at accessibility text size; it is deterministic scrolling evidence, not a recording of premium audio. The `live` screenshot is actual app UI automation. Legacy reader evidence retains the original per-page indicator. Labels and screenshot provenance are in the screenshot manifest.

Physical premium-voice timing was not rerun: production narration scripts and speech/session services are unchanged. System VoiceOver audition, real gestures during speech, device interruptions and subjective voice quality were not newly verified on hardware. The first rebuilt six-stage reference book still needs editorial artwork review, source/answer review and matching premium-voice timing before release.

Development logs retain the initial missing Xcode source registration, unsupported test-only environment assignment, safe-area test setup issue and unsuitable native accessibility lookup. These were corrected; artwork assertions run through actual XCUI accessibility. Visual inspection also led to a more compact takeaway layout. Raw logs remain local under ignored `LocalVerification/Handoff004_6/`; completed result bundles were archived into its `Results/` folder after export. Original attachment exports remain under `/tmp/LIL0046-*-attachments/`. Only focused sanitized results and relevant screenshots are published.

## Screenshot gallery

All 22 images are labeled simulator evidence, compressed as JPEG at quality 85 with a maximum 1600-pixel dimension; no depicted content was edited. Original and published hashes, source result bundle and test identifiers are recorded in [the screenshot manifest](screenshots/manifest.json).

| State | iPhone | iPad |
| --- | --- | --- |
| Hook | [View](screenshots/h0046-iphone-hook.jpg) | [View](screenshots/h0046-ipad-hook.jpg) |
| Explanation | [View](screenshots/h0046-iphone-explanation.jpg) | [View](screenshots/h0046-ipad-explanation.jpg) |
| Story A — half fill | [View](screenshots/h0046-iphone-story-a.jpg) | [View](screenshots/h0046-ipad-story-a.jpg) |
| Story B — full fill | [View](screenshots/h0046-iphone-story-b.jpg) | [View](screenshots/h0046-ipad-story-b.jpg) |
| Practical Application | [View](screenshots/h0046-iphone-application.jpg) | [View](screenshots/h0046-ipad-application.jpg) |
| Takeaway with artwork | [View](screenshots/h0046-iphone-takeaway-art.jpg) | [View](screenshots/h0046-ipad-takeaway-art.jpg) |
| Overflow Story following — accessibility text, injected range | [View](screenshots/h0046-iphone-story-long-follow.jpg) | [View](screenshots/h0046-ipad-story-long-follow.jpg) |
| Application — accessibility text, dark | [View](screenshots/h0046-iphone-application-large-dark.jpg) | [View](screenshots/h0046-ipad-application-large-dark.jpg) |
| Actual-app takeaway reveal | [View](screenshots/h0046-iphone-live-takeaway-art.jpg) | [View](screenshots/h0046-ipad-live-takeaway-art.jpg) |
| Legacy per-page fallback | [View](screenshots/iphone-reader.jpg) | [View](screenshots/ipad-reader.jpg) |
| Legacy fallback — dark | [View](screenshots/iphone-reader-dark.jpg) | [View](screenshots/ipad-reader-dark.jpg) |
