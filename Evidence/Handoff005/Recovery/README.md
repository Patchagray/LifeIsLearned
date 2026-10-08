# Library recovery incident — October 8, 2026

Tested/installed source: **`3e591b664b96f79ed36abf6b86d1400acdf0cdb6`**, on `feature/handoff-005-library-platform`. Evidence follow-up changes documentation only.

## Verified outcome

- **28 native tests passed** on iPhone 16e simulator (iOS 26.3.1), including collection import, storage and packaged-audio regression.
- **9 storage tests passed on Patcha**, including the new aliased-path regression and failed/successful offloads.
- Signed build, strict signature check and in-place installation succeeded with existing signing. Three ordinary device cold launches succeeded. A fresh device copy after those launches still held both restored packages (5,495,961 bytes), matching both current and previous index records.
- All **68 prior immutable snapshot files** remain byte-for-byte unchanged. The live CURRENT pointer advanced with activity; current reading/practice state is identical except `lastEngagedAt`, cards are byte-identical, and History differs only in `lastOpenedAt`. No progress or completion reset occurred.
- Three reads of an isolated recovered-data copy through the actual native storage/model implementation returned **two books, no warnings, readOnly=false**. This is native data verification, not a claim of screen inspection.
- Xcode's separate physical UI inspection was **blocked before execution** by a timeout enabling UI automation. It is not counted as passed. The owner was asked to unlock the device/approve UI automation. Three normal device launches and post-launch checksums are verified independently.

[Exact commands](commands.md) · [Results](verification.json) · [Source hashes](tested-source-sha256.json) · [Post-launch integrity](post-cold-launch-integrity.json)

## Root cause

Library-v3 garbage collection built a package-relative filename by dropping a fixed number of characters from an enumerated absolute URL. Foundation resolves filesystem aliases: a Documents path using `/var/...` can enumerate as `/private/var/...`. The different prefixes made valid referenced packages appear unreferenced, so cleanup could unlink every installed payload. A similar raw URL inequality in offload could misidentify the active payload as an old revision.

The live app could continue displaying the in-memory book until reopening. Both CURRENT and its previous snapshot referred to the same deleted payloads, so neither could reload. Recovery mode then deliberately disabled writes/imports to protect learner state. An in-place Xcode installation preserves Documents, so installing a new build alone could preserve the broken state.

This was an implementation defect in the H005 storage cleanup, not a malformed imported book. Earlier simulator fixtures did not exercise a symlinked Documents root. The standalone synthetic reproduction below exercises the original collector's exact path calculation and demonstrates deletion of a referenced file; it touches only its own disposable temporary directory.

```sh
swift Evidence/Handoff005/Recovery/gc-reproduction.swift
```

## Fix

- Compare standardized, symlink-resolved file URLs for both cleanup and offload.
- Resolve and validate every committed reference before deleting anything.
- Reject unsupported state versions and invalid/traversing references; skip symlinks and verify enumerated files stay inside the package store.
- Retain both current and previous committed payload references; continue reclaiming genuinely unreferenced files.
- Add native regression tests with an explicitly symlinked Documents directory: current/previous payload preservation, repeated save/reopen, failed offload preserving active content, successful offload reclamation, and invalid-reference cleanup stopping before deletion.

No lesson, narration, schema, signing configuration or learner-state reset changed.

## Existing-device recovery

Before any repair, the complete app Documents directory was copied into ignored local verification storage. The saved index referenced two packages; both payloads were missing. All existing metadata was readable. Original local book sources were decoded/validated using the actual app models and serialized with the actual `canonicalData()` method. Both recovered byte counts and SHA-256 values matched the existing installed records exactly.

After installing the fixed build, only those two missing payload files were restored at their existing indexed paths. CURRENT, progress, cards, history and all prior state snapshots were not edited. The first post-launch comparison found every pre-existing file byte-for-byte unchanged and both restored package checksums valid. Private library backups, book contents, titles, reading history, raw device logs and XCTest artifacts remain local and are not included here.

An explicitly opted-in physical UI test opens the existing backed-up library three times, checks the expected two-collection state, no recovery banner/alert, and an enabled Add Books → Import File action. It does not import, open lessons, change progress or reset the library. Default test runs skip this inspection; it requires `LIL_VERIFY_EXISTING_LIBRARY=1` in the test runner environment. No synthetic app fixture flags are set.

See `verification.json` for final measured outcomes, exact source commit and post-test preservation checks. This repair does not claim recovery of any data previously removed by a true uninstall before the captured backup.
