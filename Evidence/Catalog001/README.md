# Catalog 001 foundation — Handoff 004.5

Implementation: `fb735c0f1bffb2f92f9c0cb6850624f3160771cc` on `feature/catalog-001-foundation`, based on the accepted Handoff 004 result `7f0146ae065d2e75917af88726be30484171fb5b`. Review against `feature/handoff-004-idea-collection`. Evidence/documentation commits may follow without changing the validator, tests or canonical manifest.

## Scope and files

- `Catalog/Catalog-001.json`: the supplied approved schema-1/revision-1 manifest, copied unchanged. Exactly 50 unique books, eight shelves, primary counts **10 / 7 / 8 / 7 / 7 / 4 / 3 / 4**, and authoring priorities 1–50 exactly once.
- `Catalog/README.md`: supplied editorial rules plus validation commands, canonical hash, ID reconciliation and future authoring workflow.
- `Tools/validate_catalog.py`: deterministic read-only standard-library validator; precise field errors and nonzero exit on failure. Checks required fields/types, schema/revision/rules, declared/actual counts, unique IDs, shelf references/order/distribution, secondary classification, nonempty authors/tags, duplicate tags, queue/order, duplicate JSON keys and status values. Schema 1 rejects undeclared fields, including transport metadata.
- `Tools/test_catalog.py`: 13 tests with isolated negative manifests, including all five requested failure cases: duplicate book ID, unknown shelf, duplicate priority, wrong count, and primary repeated as secondary. Also verifies CLI exit behavior, deterministic output and no input mutation.
- `CONTENT_AUTHORING.md`, `AGENTS.md`, `README.md`: catalog lookup and exact stable `book.id` reuse before authoring. Titles outside the approved manifest require an approved later catalog revision. Whole-collection, 1–12 idea and ≤300-second reference gates continue to apply.
- Root `LifeIsLearned_Handoff_004_5_Catalog_Foundation.md`: supplied handoff copied unchanged. SHA-256 `3c9149a26643ee60c61bf77eb50246e867544f62d84091e4f79d2fd81f976f2c`; its three intentional Markdown hard-line-break spaces are preserved.

The catalog is an editorial source file, separate from installed `CollectionCatalog`. It is not bundled into the app. No runtime type has an immediate purpose in this patch. Existing app sources, Xcode project/signing, native tests, UI tests and example collection are byte-for-byte unchanged from Handoff 004. No new app screen, remote transport or import format is introduced.

## Authored ID reconciliation

The supplied `Never_Split_the_Difference_LifeIsLearned_Official.zip` contains `Never_Split_the_Difference_LifeIsLearned/Never_Split_the_Difference_LifeIsLearned_v2.json`. Its existing `book.id` is **`never-split-the-difference`**, format 2, collection revision 1, 10 ideas. It matches the proposed catalog identity, so no change to either package or manifest was needed. JSON SHA-256: `e8679c91da42f3e709f1568d5cb91f7bb45038ff65b54e676e727cdd7c8ce928`.

The supplied Influential Mind archive also uses **`influential-mind`**, format 2, collection revision 2, 10 ideas, matching the established identity. Only package identity/metadata was inspected for reconciliation. These archives were not imported, edited, republished or treated as newly verified authored releases here. Bibliographic/content accuracy, answer keys and premium narration timing are outside this identity check.

Canonical manifest SHA-256: `d99728adaab648b645915348ccba2f3c7e3ce6d4cf7c802af584e4b8ea92d7e2`, matching the supplied `LifeIsLearned_Catalog_001.json`. See [identity verification](identity-verification.json).

## Actual verification

Verification on October 5, 2026 (Eastern), against implementation commit `fb735c0f1bffb2f92f9c0cb6850624f3160771cc`:

| Check | Result |
| --- | --- |
| Canonical catalog validator | Valid: 50 books / 8 shelves / exact required distribution |
| Catalog validator negative/CLI tests | 13 passed |
| Existing Python authoring gates | 12 passed |
| Selected native import/policy/card/layout tests | 25 passed, 0 failed |
| Handoff 004 live UI + actual manual Files import | 7 passed, 0 failed, 1 explicit skip |
| LifeIsLearned simulator build/test | Succeeded |

The native selection includes all `CollectionTests`, `ContentPolicyTests`, `IdeaCardTests` and `IdeaCardPresentationTests`. UI checks cover earning after an incorrect first attempt, saved next-idea continuation, card front/back, separate favorites, 20-card browsing, favorite persistence across relaunch, review, filters/sort/accessibility order and large text. The actual Files-picker journey imports the explicit demo update, retries an incorrect answer, restores practice after relaunch and returns to the book at completion.

The only skipped case requires actual system Reduce Motion enabled. Its implementation is unchanged from the dedicated passing Handoff 004 run; the normal-motion favorite test passed here. No skip is counted as passing. See [native results](native-results.txt), [native summary](native-summary.json), [catalog tests](tests-results.txt), [authoring tests](authoring-results.txt), and [validator output](validator-results.txt).

Xcode 26.5 (17F42); iPhone 16e simulator, iOS 26.3.1. Commands run from the repository root:

```sh
python3 Tools/validate_catalog.py
python3 -m unittest discover -s Tools -p 'test_catalog.py' -v
python3 -m unittest discover -s Tools -p 'test_authoring.py' -v
python3 Tools/prepare_simulator_import.py 20E0C31B-8975-45A3-8E2C-B91BC6C64E66
xcodebuild -project LifeIsLearned.xcodeproj -scheme LifeIsLearned -configuration Debug -destination 'platform=iOS Simulator,id=20E0C31B-8975-45A3-8E2C-B91BC6C64E66' -derivedDataPath /tmp/LifeIsLearned-H004-DerivedData -resultBundlePath /tmp/LifeIsLearned-catalog001-regression.xcresult -parallel-testing-enabled NO -only-testing:LifeIsLearnedTests/CollectionTests -only-testing:LifeIsLearnedTests/ContentPolicyTests -only-testing:LifeIsLearnedTests/IdeaCardTests -only-testing:LifeIsLearnedTests/IdeaCardPresentationTests -only-testing:LifeIsLearnedUITests/IdeaCollectionUITests -only-testing:LifeIsLearnedUITests/LearningJourneyUITests/testManualFilesImportOfShortDemoAndJourney test > /tmp/LifeIsLearned-catalog001-regression.log 2>&1
```

Sanitized validator/tooling/native results are committed alongside this report. Full raw logs and the result bundle are retained locally in ignored `LocalVerification/Catalog001/`. The static patch adds no new layouts, so its evidence is metadata/tool output and regression results; Handoff 004 screenshots remain in their original report. This patch was not deployed or newly checked on a physical device. No hardware claims are added.

## Ready for authoring and Handoff 005

Authors can now look up stable identities and use the production queue. Handoff 005 can derive discovery/distribution data from this foundation through its own approved schema/transport work. No merge is performed automatically.
