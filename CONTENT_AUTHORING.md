# Authoring lesson packages

Start by reviewing actual source material. Keep the book/article's meaningful idea order; do not assume every chapter is exactly one idea. If only a prologue or excerpt is available, state that and limit coverage accordingly. The player is format-flexible: story, analogy, scenario, explanation and thought experiment can all fit the small-screen structure.

Use Example-Lesson-Package.json as the exact Codable shape. There is one book per package with 1–12 selected ideas, delivered together on every release. Twelve is a ceiling, never a quota. Handoff 003 supersedes older count and duration guidance.

## Lesson and book fields

| Object | Fields and rules |
|---|---|
| Package | `formatVersion: 2`, `collectionRevision`, `fullCollection`, ordered `manifest`, `removedLessonIDs`, shared `assets`, and `book` |
| Book | stable `id`, `title`, `author`, `synopsis`, `coverageNote`, `sources`, `lessons` |
| Source | unique `id`, `title`, valid HTTPS `url`, precise `locator`, `scope` describing what it supports and limits |
| Lesson | stable `id`, positive `revision`, `title`, `subtitle`, positive `estimatedMinutes`, `scopeNote`, 2–40 `pages`, exactly 2 `questions` for authored releases (runtime compatibility accepts 2–10) |
| Page | unique `id`, `kind`, `role`, `title`, `text`, optional `imageID`, optional `imageDescription`, `sourceIDs` |
| Question | unique `id`, `prompt`, 2–6 `choices`, `correctChoiceID` |
| Choice | unique `id`, `text`, `feedback` explaining why this answer is correct or tempting but wrong |

`kind` is `intro`, `story`, `explanation`, or `takeaway`. The first page must be `intro`, and the last must be `takeaway`. Intermediate teaching pages can be explanations; the app doesn't force fiction. `role` is `guide` or `storyteller`: normally guide for intro/explanation/takeaway and storyteller for the body. Every teaching screen needs at least one source ID; an original fictional story can use an empty array but must be explicitly labeled as fiction in lesson scope and introduction. A source reference is not automatic verification.

Optional fields can be null or omitted. `sourceIDs` is always present. Supply `imageDescription` when a page references artwork through `imageID`. Store each PNG/JPEG once in the package's shared `assets` table; repeated pages use the same ID. Optional `book.coverAssetID` requires `book.coverDescription`. Keep source limitations explicit and use original, licensed artwork. See the contract and size limits below.

## Editorial checks before import

- Teach one clear distinction with concise screens. Start around 350–450 total spoken words, including the quiz and feedback; an original example/story may be around 150–220 words. These are drafting guides, not quotas. Shorter is welcome. Do not pad or make prose unnaturally dense to reach a duration.
- Give the learner an accurate mental model. Distinguish an author's claim, evidence, uncertainty, and our proposed application.
- Do not invent statistics, chapter contents, quotes, page numbers, historical facts or research conclusions. Fictional data belongs only in clearly fictional scenarios.
- Avoid teaching “evidence never changes minds.” Prior beliefs are not inherently irrational, and disagreement is not always confirmation bias. Fair evidence assessment matters.
- Use a fresh situation for an application question rather than merely asking the learner to remember a character name.
- Make each answer choice defensible as right or wrong for a specific reason. If multiple answers could reasonably be correct, revise the question.
- Feedback should explain the distinction without shaming. A retry is practice, not a first-attempt success.
- Budget and measure the entire idea using the release gate below. Do not equate a four-minute story or estimatedMinutes: 5 with a five-minute learning experience.
- Increment the idea's `revision` for any change to the lesson content listed in the deterministic comparison rules below. Stable IDs and revision distinguish saved progress.

## Reusable content-authoring request

“Prepare one complete formatVersion-2 collection with 1–12 selected ideas and an honest coverage preface. Teach one clear idea per lesson with concise original examples, guide/storyteller roles, and exactly two application questions with individual feedback. Keep the entire reference first-pass idea at or below five minutes, including all narration, transitions, quiz choices, feedback and an answer allowance. Shorter is welcome. Include a timing report, stable IDs/revisions, shared original artwork, source references and the complete ordered manifest. Never invent unavailable book content or imply the author ranked our selection. Show the source material reviewed, and give me the content for review before import.”

## Handoff 002: complete collection contract (formatVersion 2)

New imports use **formatVersion 2**. Legacy installations remain readable; new exports replace the old `imageAsset` / `imageBase64` fields with `imageID`. Import the entire prepared release for a book, including all ordered idea IDs. Never export individual idea patches. “Full collection” describes the prepared, reviewed release, not proof that the complete source book was reviewed.

Required package fields:

```json
{
  "formatVersion": 2,
  "collectionRevision": 1,
  "fullCollection": true,
  "manifest": [{ "id": "priors", "revision": 1 }],
  "removedLessonIDs": [],
  "assets": {
    "scene-a": { "mediaType": "image/jpeg", "data": "BASE64_BYTES" }
  },
  "book": { "id": "stable-book-id", "lessons": [] }
}
```

This fragment illustrates the new fields; `book` still needs every documented metadata/source field and complete valid lessons. Use `Example-Lesson-Package.json` as the runnable example. Its one-idea demo is explicitly introductory coverage.

- `collectionRevision` is a positive integer, incremented for every changed release, including book metadata, ordering, and asset-table changes.
- `manifest` must exactly match every `book.lessons` ID/revision in order. IDs must be unique; ideas retain stable IDs across revisions.
- Pages reference `imageID` in `assets` and provide `imageDescription`. A shared illustration is encoded once. An optional `book.coverAssetID` references the same table and requires `book.coverDescription`. Omit both for the designed placeholder. `book.isDemo: true` labels demonstration content.
- `removedLessonIDs` explicitly identifies intentional omissions from the previously installed release. The learner sees their titles and must acknowledge removals. Removed progress remains archived; the app never silently discards it.
- Limits: 64 MiB encoded JSON, 1–12 ideas for new imports and updates, 2–40 pages/idea, exactly two questions per authored idea (runtime compatibility accepts 2–10), 2–6 choices/question, no asset-count ceiling, 2 MiB per image and 24 MiB total image-file bytes after base64 decoding, maximum 2048 × 2048 pixels, one frame per PNG/JPEG. The cover shares these budgets. PNG/JPEG signatures, dimensions, and native decoding are checked. No remote artwork is downloaded. Optimize to the actual reader size; the supplied converter exports JPEG at up to 1440 px and quality 82.

### Revision rules and deterministic comparison

The exact same collection revision/content is a no-op. Reusing a collection revision for different content, downgrading a collection or previously seen idea, omitting undeclared ideas, or changing an idea without increasing its revision is rejected. Reordering unchanged ideas and changing only book display metadata preserves idea progress. A revised idea gets a fresh active state, labeled “Updated · review again”; previous progress is retained under its original revision key.

Comparison decodes typed JSON, re-encodes with sorted object keys, and preserves ordered arrays. Whitespace, object-key order, and equivalent base64 encodings are irrelevant. A lesson comparison includes its prose, title, subtitle, estimate, scope, page order/roles, descriptions, questions/choices/feedback/answer keys, referenced source definitions, and resolved image bytes. Any change to these requires an idea revision increase. Merely changing a shared asset ID while keeping its bytes and description is not a content change. Editing an illustration's bytes requires increasing every affected idea's revision. Book title/author/synopsis/coverage/cover and collection ordering require a collection revision; unchanged idea state is kept. Referenced source corrections require both collection and affected idea revisions.

Legacy bundled image names are retained for installed format-1 packages. Converting/recompressing their images changes the content representation: for an update over an installed legacy collection, increment affected idea revisions before export. The bundled demo conversion is an explicit installation migration with unchanged stable progress keys.

### Convert a reviewed legacy collection

On the Mac:

```bash
python3 Tools/convert_package.py old-package.json complete-collection-v2.json --collection-revision 2 --reviewed-full-collection
python3 Tools/validate_package.py complete-collection-v2.json
```

The converter preserves the original file, refuses an existing output path, and blocks over-cap or over-budget draft exports. Shorten the reviewed source first; the converter never truncates ideas or prose. It requires macOS `sips`, uses no backend, and optimizes/deduplicates images. Inspect all idea revisions, declared removals, coverage, sources, and answer keys before import. Conversion and structural validation do not establish factual correctness or completeness. The current app keeps installed legacy content readable but rejects a newly selected legacy file with conversion guidance.

`Tools/make_starter.py` prepares the shortened revision-2 demo as a separate explicit update. It refuses to overwrite the frozen revision-1 startup seed. `Example-Lesson-Package.json` is the shorter review/update file; it is intentionally different from `Resources/starter.json`. `Tools/validate_package.py` is read-only and reports portable structural/image-header checks; it never replaces the verification report. Native image decoding and Swift compilation are separate checks.


## Handoff 003: selection, timing and release approval

### Select and explain the collection

Select for centrality in reviewed material, usefulness, distinctness and teachability; retain meaningful source order where supported. Show the actual number selected and explain that the companion is a curated selection, not an exhaustive summary or the author's ranking. The app shows this preface with `coverageNote` before the first start. The preface is visible text, not spoken narration in the current player. State explicitly when the full book was not reviewed. Public access does not grant redistribution rights; use original writing/art with attribution.

Do not auto-truncate thirteen ideas or split a book into disguised volumes. When consolidating ideas, retain an ID only if it represents the same core idea. Otherwise use a new stable ID, explicitly retire replaced IDs, and preserve their archived progress. Completion does not transfer to unpracticed material.

### Repeatable whole-idea timing

`Tools/lesson_timing.py` matches `LessonNarration` and `LessonTiming` in Swift. It includes page titles/prose, question prompts, numbered option labels and every choice, the longest single feedback response per question with its spoken prefix, and the completion announcement. It excludes source/interface text and the visible book preface because the player does not speak them. If playback adds speech, update both calculators and their script-parity tests.

Reference plan: spoken words × 60 / 130, plus **(page count − 1) × 2 seconds** of actual automatic page transitions, plus **40 seconds** of answering time (20 per question). No automatic pause is added after the takeaway, feedback, or completion because the player stops for learner control there. Use `ceil(totalSeconds / 60)` for `estimatedMinutes`; the UI calculates the same approximate whole-idea value independently. Slower voices, user-selected speed/pauses, longer deliberation, replays and retries may exceed five minutes. Nothing is interrupted to enforce an editorial budget.

```bash
python3 Tools/validate_package.py Example-Lesson-Package.json --authoring-gate --report /tmp/short-demo-plan.json
python3 Tools/test_authoring.py
# After the exact script is measured with installed premium voices:
python3 Tools/validate_package.py Example-Lesson-Package.json --approve-release --measurements /path/to/premium-reference-timing.json --report /tmp/short-demo-release.json
```

The planning gate fails totals above 300 seconds, authored question counts other than two, and inconsistent estimates. Structural validation alone intentionally accepts longer legacy content; runtime imports cannot prove elapsed learning time. `--approve-release` additionally requires one measured record per idea at normal speed, a 2-second pause, and actual premium guide/storyteller IDs and names. Measurements must match every narrated segment's text, order, role, idea revision and collection revision. Changed narration invalidates the old measurements. Positive speech-completion callback durations are summed with the pauses and answer allowance; totals above 300 seconds fail. A word-count estimate cannot approve a release.

Run `PremiumNarrationTimingTests` on a physical iPhone to measure the short demo using the production speech player. It uses the saved premium voice for each role when available, otherwise an installed premium voice for that role; it never falls back to enhanced/compact quality. A missing premium voice is an explicit skipped check. Temporary test preferences do not change the user's voice settings or library. The JSON attachment records the voices, settings, per-segment durations, and elapsed reference script. Subjective voice quality remains an audition, not an automated assertion.

### Existing books and the separate demo update

Stored format-2 books with 13–100 ideas remain readable. A new update must contain 1–12 ideas and declare every removed installed ID for acknowledgement. See `PERSISTENCE.md`.

The shorter demo keeps `influential-mind` / `priors`, increases both collection and idea revisions to 2, and preserves source definitions and shared image bytes. Review it, complete the premium-voice timing gate, then select `Example-Lesson-Package.json` through the app's **Import book** Files picker and confirm **Import complete update**. The old revision's progress stays archived; revision 2 starts unpracticed. Never silently install the demo over a larger user collection; compose a complete reviewed release with explicit removals if that is intentional.

Mario is preparing The Influential Mind (ten ideas) and Never Split the Difference (formerly fourteen) outside this engineering task. Earlier companion ZIPs are superseded drafts, not ready-to-import releases. Each later collection must satisfy these gates; Never Split the Difference requires an explained selection/consolidation to at most twelve. Artwork briefs require review against the shortened stories. No new book prose or bulk import is included here.

Distribution remains manual Files import. GitHub Releases and a small catalog, resumable/cancellable downloads, offline installation and storage reclamation that preserves progress are deferred; no release assets or catalog are published by this patch.
