# 005E — Optional earned reading

`Lesson.diveDeeper` is additive/optional and retains the exact baseline fingerprint when absent. Sections require unique identities, text and reviewed source references. Deeper text and referenced source definitions participate in deterministic revision comparison; the core narration script and 300-second timing calculation do not change.

Completion and selected Idea Card offer Dive deeper after the current revision is practiced. The reading surface is scrollable, with source disclosures and a clear optional-reading label; it adds no core progress stage or automatic narration. The card action is pinned below the carousel so nested card scrolling cannot hide it. On first UI testing, the initially proposed below-carousel action was hard to reach; it was corrected without weakening the UI assertion.

Only a lightweight availability flag accompanies a newly earned card snapshot. Deeper prose/sources remain package payload. Manual/remote offload offers re-import/download; updated uncompleted content remains locked and does not rewrite the earned snapshot.

## Commands

```sh
xcodebuild test -project LifeIsLearned.xcodeproj -scheme LifeIsLearned \
  -destination 'platform=iOS Simulator,id=20E0C31B-8975-45A3-8E2C-B91BC6C64E66' \
  -destination 'platform=iOS Simulator,id=B219EF2E-CFAA-43D2-8F69-804ED944F678' \
  -derivedDataPath /tmp/LIL005-derived -resultBundlePath /tmp/LIL005E-verified.xcresult \
  -only-testing:LifeIsLearnedTests/DiveDeeperTests -only-testing:LifeIsLearnedTests/Handoff005ATests \
  -only-testing:LifeIsLearnedTests/LibraryV3Tests -only-testing:LifeIsLearnedUITests/DiveDeeperUITests
python3 -m unittest discover -s Tools -p 'test_*.py'
python3 Tools/validate_package.py
python3 Tools/validate_catalog.py
```

Native tests cover legacy decode/fingerprint, valid/invalid sources, revision requirements, referenced source changes, unchanged timing/script, completion unlock, offload restore modes, reinstall and updated-revision lock. Existing completion/migration/offload tests run alongside them. UI tests exercise actual completion → Dive Deeper → collected card → Dive Deeper, at normal and accessibility XXXL text sizes on iPhone/iPad.

Screenshots are labeled synthetic interface fixtures, not new authored book content. Production content still requires review. Raw logs/results stay in ignored `LocalVerification/Handoff005/005E-*` and `/tmp/LIL005E-verified.xcresult`.

Final targeted result: 13 native tests + 2 UI journeys passed per device, no failures/skips. All 42 Python tests and 484 portable checks passed. The large-text UI helper now scrolls to realize lazy book rows before asserting visibility; no product check was removed.
