# Library-v3 and offload

## Disk contract

`Library-v3/CURRENT.json` publishes an immutable `StateSnapshots/<uuid>/` containing `library-state.json`, `progress.json`, `cards.json` and `history.json`. Library state contains installed references and version/identity metadata. Full packages live only under `Packages/<SHA256(bookID)>/<revision>-<SHA256(payload)>.json`. Hash-derived paths prevent book IDs from becoming filesystem paths. Loads check payload size, checksum, identity and existing native package validation.

Current and previous committed snapshots are recovery candidates. Uncommitted directories never supply progress or ownership. Damaged components recover independently; unrecoverable components pause saving and preserve files. Previous snapshots contain lightweight metadata, not duplicate prose/art. Garbage collection protects payloads referenced by current/previous installed state.

## Migration

The v2 reader completes any historical-card migration without saving or modifying v2. Only currently installed packages are written to v3. A full round-trip comparison of typed catalog, progress, cards and History precedes atomic CURRENT publication. A failed prepublication migration leaves v2 unchanged and readable. The first publication retains v2. A subsequent verified v3 launch removes obsolete v2 payloads and old `imported-books.json`; an explicit offload also verifies the already-published v3 state before cleanup. No permanent heavy backup is retained.

## Offload transaction

Old payload revisions for the selected book are deleted while the current installed file remains intact. Two new lightweight recovery snapshots exclude the book while preserving all learner state. An `OFFLOAD.json` journal records the old/new pointers and active payload path. The new pointer is published, then a single-file unlink makes the offload decision. The UI receives success only after payload deletion succeeds.

On interruption, presence of that file selects the old installed state; absence selects the new offloaded state. Failed unlink restores the old pointer. This process-crash journal needs no heavy rollback copy. Tests inject failures before/after publication and deletion. Other books' referenced package files are protected. Unlink success followed by a simulated process crash recovers as a successful offload, while learner state remains unchanged.

## Durable behavior

History retains stable book/idea ordering, source type and original completion date. New/revised releases show updates without erasing that event. Offloaded cards use earned snapshots. Full-lesson recovery offers manual re-import or remote download according to saved source; current lessons may differ from earned snapshots. Retained collection/idea fingerprints prevent offload/re-import from bypassing revision increases or removal acknowledgement.

Evidence uses isolated synthetic learner state and the bundled art-heavy package, never the user's documents. State dumps and exact byte counts are exported from deterministic tests. Device storage accounting, filesystem power-loss guarantees and physical UI testing are not inferred from simulator tests.
