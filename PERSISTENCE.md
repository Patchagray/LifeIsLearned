# Collection storage and recovery

The library uses native JSON and Files imports. Parsing, validation, image inspection, comparison, hashing, and disk writes run on a serial Swift actor. Published view state changes on the main actor. Image thumbnails decode on a separate cached actor. No account, backend, subscription, or new dependency is required.

## Transaction boundary

`Documents/Library-v2/CURRENT.json` points to a UUID snapshot directory and the previous committed snapshot. Each snapshot contains `collections.json` (all installed packages and the latest known revision/fingerprint for every seen idea), `progress.json` (all revision keys, including archived ones), and `cards.json` (earned card snapshots and favorites).

A commit completes all three files in a new directory before atomically replacing CURRENT. No in-memory import is published before that final write succeeds. An interruption before publication leaves the existing pointer authoritative. Unreferenced directories are never selected during load. After publication, all three new files belong to the same snapshot. This is a single publication boundary, not a claim that two unrelated atomic writes form a transaction. The prior pointer target remains available if a committed file cannot be decoded.

Unchanged collection files use filesystem hard links between progress snapshots, avoiding repeated copies of embedded artwork on each page change. Each new collection revision is a new file. Progress is saved after meaningful navigation/quiz actions, never on spoken-word callbacks. The saved practice position includes phase, question, selection, feedback through that selection, attempted flag, and first-attempt score. Audio never auto-starts on resume; reading restores the screen, not a word timestamp.

## Migration

The loader decodes `lessonProgress.v1` independently before reading content. The existing length-prefixed book/idea/revision keys are unchanged. It reads and validates installed `imported-books.json` packages with the legacy validator. It then commits content, progress, and derived cards to a new snapshot. Original legacy files and UserDefaults are retained; they are not overwritten or removed. New imports require format 2. The bundled demo is explicitly converted to format 2 with the original IDs/revision. Existing saved narration pauses are untouched; only fresh preferences default to 2 seconds.

Existing timestamps are not invented. For legacy progress without engagement dates, home can offer the first saved position in collection order until a real engagement is recorded. Merely opening the home or book detail never creates activity.

## Recovery

Progress, collections, and cards load independently from the committed snapshot. A bad content file cannot suppress valid progress. If a section is unreadable, the loader tries that section in the previous committed snapshot; it reports recovery and preserves damaged files. If neither committed copy is readable, the library enters read-only recovery mode and does not replace saved history with an empty dictionary. The demo may remain readable while recovery is required. No automatic cleanup deletes archived snapshots in this release.

For recovery, first copy the entire `Library-v2` directory and retained legacy files from the app's document container. The preserved UUID snapshots and original `lessonProgress.v1` can be inspected and restored by a developer. Do not delete/reset the app to resolve an import error. This release deliberately offers no destructive in-app reset.

A failed write leaves the old pointer and installed collection usable. The UI surfaces the failure. In-memory reading progress can be retried on the next action; only successfully written progress survives termination. Original snapshots are retained, so long-term snapshot compaction is future maintenance rather than an implicit history deletion.


## Handoff 003: import policy versus stored readability

`LessonPackage.validated(for:)` explicitly distinguishes `.newImport` from `.storedContent`. All selected files and confirmation-time revalidation use the new-import boundary: 1–12 ideas, a complete ordered manifest and unchanged revision/resource protections. Storage loading, recovery and legacy migration use stored-content validation, preserving previously valid format-2 collections of 13–100 ideas and format-1 installations. Lowering the new-import cap does not truncate, hide or force recovery for those books.

An over-cap installed collection can receive a complete compliant update. Omitted IDs must be in `removedLessonIDs`, the preview lists them, and publication requires acknowledgement. Unchanged idea progress remains active; removed/replaced revision keys stay archived. New or materially revised ideas never inherit a completed state from retired material.

There is no numerical image-count cap in either validation context. Both retain nonempty IDs, valid references/cover, 2 MiB per image, 24 MiB combined decoded image-file data, single-frame PNG/JPEG decoding and 2048-pixel dimensions. New files retain the 64 MiB encoded-package check before JSON decoding. Validation, hashing and disk work remain on the storage actor.

The revision-1 startup seed is deliberately unchanged. `Example-Lesson-Package.json` is the explicit shortened revision-2 update, selected through Files and confirmed in the normal preview. Loading a seed never supersedes a committed installed catalog. Tests cover a previously valid stored 100-idea library, its legacy-file migration path, and a confirmed reduction to 12 with all 100 progress records retained. There is no automatic demo replacement, destructive migration, signing change or playback-time cutoff.

## Handoff 004: earned idea cards

Snapshots now also contain `cards.json`, a dictionary keyed by the length-prefixed semantic book/lesson identity without its revision suffix. `CURRENT.json.cardStateVersion = 1` distinguishes card-aware snapshots from older installations. All three files finish before the single atomic pointer publication. Progress-only and favorite-only saves still hard-link the unchanged collection catalog. The card records contain compact text only: title, takeaway, application subtitle, source title/author, optional first earned date, last earned revision, and favorite. They contain no artwork or base64.

An idea earns its card when practice becomes complete, regardless of score. Completing a later revision refreshes text and the last-earned revision while preserving the original date and favorite. Metadata edits, reordering, and importing an uncompleted revision do not change earned text. Removed earned cards remain in the dictionary; unearned removed lessons create none. Reviewing/recompleting an already completed revision leaves its original first-attempt score and completion date intact.

On first card-aware launch, committed completed progress keys authorize backfill. Current/seed content is consulted first. For unresolved completed revisions, the storage actor can look up validated text in retained catalog history, deduplicating hard-linked catalog files. It never adopts an unreferenced catalog as the active library, and never reads orphan progress to grant ownership. Legacy snapshots lack a per-directory historical commit marker; retained content is used only when an exact revision has independent committed completion evidence. Unknown completion dates stay nil and display “Earned previously.” Existing legacy and snapshot files are preserved.

An archived card can review its exact last-earned revision when the matching retained source remains readable. If unavailable, the card stays readable/favoritable and the app explains why the full lesson cannot open. Active cards review current content; incomplete revised lessons resume saved progress, and completed lessons open at their introduction without starting narration.

Card recovery is independent of catalog/progress recovery and considers only CURRENT and its previous pointer target. When the previous card copy is usable, newer committed completion records can restore missing earned cards or completed-revision text without resetting recovered favorites or dates. The warning explains that very recent favorite changes may need repeating. Both unreadable card copies, or a newer unsupported card-state version, pause saving instead of replacing card history. As with progress, a failed disk write leaves the previous committed state intact and reports the error; the next action can retry pending in-memory state.

## Handoff 005 superseding storage contract

The sections above describe the v2 compatibility/migration source. Handoff 005 moves normal operation to `Library-v3` with separate removable package files and durable lightweight state snapshots. It intentionally ends permanent historical package retention and normal archived-source reconstruction. Earned card text/favorites and all revision progress remain durable. See [the v3 transaction, migration and byte-reclamation evidence](Evidence/Handoff005/005B-storage-offload/README.md).

V2 is untouched before verified v3 publication, then cleaned after a verified v3 launch. An explicit offload verifies v3 before cleanup and uses a recovery journal plus atomic single-file deletion. First-completion events survive later updates, including an unknown historical date without fabrication. Reinstall must pass retained collection and idea revision checks and any required removal acknowledgement. There is no UI-only offload.

### Handoff 005E optional reading

Dive Deeper stays in the removable package. A newly earned card snapshot can record `hasDiveDeeper: true`, a lightweight availability hint, with no deeper prose/source payload. Old snapshots omit it unchanged. Offloaded hints route to source-specific restoration; current updated content stays locked until its revision is practiced. Reinstallation reconnects the existing progress and card identity.
