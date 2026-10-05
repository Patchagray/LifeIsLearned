# Collection storage and recovery

The library uses native JSON and Files imports. Parsing, validation, image inspection, comparison, hashing, and disk writes run on a serial Swift actor. Published view state changes on the main actor. Image thumbnails decode on a separate cached actor. No account, backend, subscription, or new dependency is required.

## Transaction boundary

`Documents/Library-v2/CURRENT.json` points to a UUID snapshot directory and the previous committed snapshot. Each snapshot contains `collections.json` (all installed packages and the latest known revision/fingerprint for every seen idea) and `progress.json` (all revision keys, including archived ones).

A commit completes both files in a new directory before atomically replacing CURRENT. No in-memory import is published before that final write succeeds. An interruption before publication leaves the existing pointer authoritative. Unreferenced directories are never selected during load. After publication, both new files belong to the same snapshot. This is a single publication boundary, not a claim that two unrelated atomic writes form a transaction. The prior pointer target remains available if a committed file cannot be decoded.

Unchanged collection files use filesystem hard links between progress snapshots, avoiding repeated copies of embedded artwork on each page change. Each new collection revision is a new file. Progress is saved after meaningful navigation/quiz actions, never on spoken-word callbacks. The saved practice position includes phase, question, selection, feedback through that selection, attempted flag, and first-attempt score. Audio never auto-starts on resume; reading restores the screen, not a word timestamp.

## Migration

The loader decodes `lessonProgress.v1` independently before reading content. The existing length-prefixed book/idea/revision keys are unchanged. It reads and validates installed `imported-books.json` packages with the legacy validator. It then commits both content and progress to a new snapshot. Original legacy files and UserDefaults are retained; they are not overwritten or removed. New imports require format 2. The bundled demo is explicitly converted to format 2 with the original IDs/revision. Existing saved narration pauses are untouched; only fresh preferences default to 2 seconds.

Existing timestamps are not invented. For legacy progress without engagement dates, home can offer the first saved position in collection order until a real engagement is recorded. Merely opening the home or book detail never creates activity.

## Recovery

Progress and collections load independently from the committed snapshot. A bad content file cannot suppress valid progress. If a section is unreadable, the loader tries that section in the previous committed snapshot; it reports recovery and preserves damaged files. If neither committed copy is readable, the library enters read-only recovery mode and does not replace saved history with an empty dictionary. The demo may remain readable while recovery is required. No automatic cleanup deletes archived snapshots in this release.

For recovery, first copy the entire `Library-v2` directory and retained legacy files from the app's document container. The preserved UUID snapshots and original `lessonProgress.v1` can be inspected and restored by a developer. Do not delete/reset the app to resolve an import error. This release deliberately offers no destructive in-app reset.

A failed write leaves the old pointer and installed collection usable. The UI surfaces the failure. In-memory reading progress can be retried on the next action; only successfully written progress survives termination. Original snapshots are retained, so long-term snapshot compaction is future maintenance rather than an implicit history deletion.
