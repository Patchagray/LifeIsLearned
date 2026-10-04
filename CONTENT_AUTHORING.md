# Authoring lesson packages

Start by reviewing actual source material. Keep the book/article's meaningful idea order; do not assume every chapter is exactly one idea. If only a prologue or excerpt is available, state that and limit coverage accordingly. The player is format-flexible: story, analogy, scenario, explanation and thought experiment can all fit the small-screen structure.

Use Example-Lesson-Package.json as the exact Codable shape. There is one book per package; a book can have multiple lessons.

## Lesson and book fields

| Object | Fields and rules |
|---|---|
| Package | `formatVersion: 2`, `collectionRevision`, `fullCollection`, ordered `manifest`, `removedLessonIDs`, shared `assets`, and `book` |
| Book | stable `id`, `title`, `author`, `synopsis`, `coverageNote`, `sources`, `lessons` |
| Source | unique `id`, `title`, valid HTTPS `url`, precise `locator`, `scope` describing what it supports and limits |
| Lesson | stable `id`, positive `revision`, `title`, `subtitle`, positive `estimatedMinutes`, `scopeNote`, 2–40 `pages`, 2–10 `questions` |
| Page | unique `id`, `kind`, `role`, `title`, `text`, optional `imageID`, optional `imageDescription`, `sourceIDs` |
| Question | unique `id`, `prompt`, 2–6 `choices`, `correctChoiceID` |
| Choice | unique `id`, `text`, `feedback` explaining why this answer is correct or tempting but wrong |

`kind` is `intro`, `story`, `explanation`, or `takeaway`. The first page must be `intro`, and the last must be `takeaway`. Intermediate teaching pages can be explanations; the app doesn't force fiction. `role` is `guide` or `storyteller`: normally guide for intro/explanation/takeaway and storyteller for the body. Every teaching screen needs at least one source ID; an original fictional story can use an empty array but must be explicitly labeled as fiction in lesson scope and introduction. A source reference is not automatic verification.

Optional fields can be null or omitted. `sourceIDs` is always present. Supply `imageDescription` when a page references artwork through `imageID`. Store each PNG/JPEG once in the package's shared `assets` table; repeated pages use the same ID. Optional `book.coverAssetID` requires `book.coverDescription`. Keep source limitations explicit and use original, licensed artwork. See the contract and size limits below.

## Editorial checks before import

- Keep most screens around 60–120 words, but prefer a meaningful chunk over a rigid word quota. The example intro is shorter. Break large concepts into additional lessons rather than walls of text.
- Give the learner an accurate mental model. Distinguish an author's claim, evidence, uncertainty, and our proposed application.
- Do not invent statistics, chapter contents, quotes, page numbers, historical facts or research conclusions. Fictional data belongs only in clearly fictional scenarios.
- Avoid teaching “evidence never changes minds.” Prior beliefs are not inherently irrational, and disagreement is not always confirmation bias. Fair evidence assessment matters.
- Use a fresh situation for an application question rather than merely asking the learner to remember a character name.
- Make each answer choice defensible as right or wrong for a specific reason. If multiple answers could reasonably be correct, revise the question.
- Feedback should explain the distinction without shaming. A retry is practice, not a first-attempt success.
- Estimate narration time from text and audition it. If an estimate changes materially with pacing, present it as approximate.
- Increment the idea's `revision` for any change to the lesson content listed in the deterministic comparison rules below. Stable IDs and revision distinguish saved progress.

## Reusable content-authoring request

“Review the source material I supply and create a formatVersion 2 complete book collection matching Example-Lesson-Package.json. Preserve the source's idea order. Include every prepared idea in the ordered manifest, stable IDs/revisions, and shared artwork. Show what you reviewed and what remains uncertain. Teach one idea at a time with concise screens, original examples, source-linked explanations and a takeaway, guide/storyteller narration roles, and two transfer questions with feedback for every choice. State coverage limitations and label fictional examples. Do not fill unavailable parts of the source from guesses. Give me the content to review before I import it.”

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
- Limits: 64 MiB encoded JSON, 1–100 ideas, 2–40 pages/idea, 2–10 questions/idea, 2–6 choices/question, up to 32 PNG/JPEG assets, 2 MiB per image and 24 MiB total decoded image bytes, maximum 2048 × 2048 pixels, one frame per image. PNG/JPEG signatures, dimensions, and native decoding are checked. No remote artwork is downloaded. Optimize to the actual reader size; the supplied converter exports JPEG at up to 1440 px and quality 82.

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

The converter preserves the original file and refuses an existing output path. It requires macOS `sips`, uses no backend, and optimizes/deduplicates images. Inspect all idea revisions, declared removals, coverage, sources, and answer keys before import. Conversion and structural validation do not establish factual correctness or completeness. The current app keeps installed legacy content readable but rejects a newly selected legacy file with conversion guidance.

`Tools/make_starter.py` now creates format 2 and matching examples. `Tools/validate_package.py` is read-only and reports portable structural/image-header checks; it never replaces the verification report. Native image decoding and Swift compilation are separate checks.
