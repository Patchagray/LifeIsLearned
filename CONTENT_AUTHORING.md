# Authoring lesson packages

Start by reviewing actual source material. Keep the book/article's meaningful idea order; do not assume every chapter is exactly one idea. If only a prologue or excerpt is available, state that and limit coverage accordingly. The player is format-flexible: story, analogy, scenario, explanation and thought experiment can all fit the small-screen structure.

Use Example-Lesson-Package.json as the exact Codable shape. There is one book per package; a book can have multiple lessons.

## Required fields

| Object | Fields and rules |
|---|---|
| Package | `formatVersion: 1`, `book` |
| Book | stable `id`, `title`, `author`, `synopsis`, `coverageNote`, `sources`, `lessons` |
| Source | unique `id`, `title`, valid HTTPS `url`, precise `locator`, `scope` describing what it supports and limits |
| Lesson | stable `id`, positive `revision`, `title`, `subtitle`, positive `estimatedMinutes`, `scopeNote`, 2–40 `pages`, 2–10 `questions` |
| Page | unique `id`, `kind`, `role`, `title`, `text`, optional `imageAsset`, optional `imageBase64`, optional `imageDescription`, `sourceIDs` |
| Question | unique `id`, `prompt`, 2–6 `choices`, `correctChoiceID` |
| Choice | unique `id`, `text`, `feedback` explaining why this answer is correct or tempting but wrong |

`kind` is `intro`, `story`, `explanation`, or `takeaway`. The first page must be `intro`, and the last must be `takeaway`. Intermediate teaching pages can be explanations; the app doesn't force fiction. `role` is `guide` or `storyteller`: normally guide for intro/explanation/takeaway and storyteller for the body. Every teaching screen needs at least one source ID; an original fictional story can use an empty array but must be explicitly labeled as fiction in lesson scope and introduction. A source reference is not automatic verification.

Optional fields can be null or omitted. `sourceIDs` is always present. Supply `imageDescription` when a page has artwork. Use `imageBase64` for your own PNG/JPEG as a raw base64 string (no data-URL prefix), maximum 2 MB decoded per image. Keep packages under 25 MB. The bundled `imageAsset` values are only `priors-setup`, `priors-conflict`, `priors-resolution`; do not reference nonexistent asset names. No remote images are fetched. Generate original illustrations with consistent characters, then embed or bundle them. Do not reuse the reference application's artwork.

## Editorial checks before import

- Keep most screens around 60–120 words, but prefer a meaningful chunk over a rigid word quota. The example intro is shorter. Break large concepts into additional lessons rather than walls of text.
- Give the learner an accurate mental model. Distinguish an author's claim, evidence, uncertainty, and our proposed application.
- Do not invent statistics, chapter contents, quotes, page numbers, historical facts or research conclusions. Fictional data belongs only in clearly fictional scenarios.
- Avoid teaching “evidence never changes minds.” Prior beliefs are not inherently irrational, and disagreement is not always confirmation bias. Fair evidence assessment matters.
- Use a fresh situation for an application question rather than merely asking the learner to remember a character name.
- Make each answer choice defensible as right or wrong for a specific reason. If multiple answers could reasonably be correct, revise the question.
- Feedback should explain the distinction without shaming. A retry is practice, not a first-attempt success.
- Estimate narration time from text and audition it. If an estimate changes materially with pacing, present it as approximate.
- Increment `revision` when content changes enough that prior completion should not carry over. Stable IDs and revision distinguish saved progress.

## Reusable content-authoring request

“Review the source material I supply and create a formatVersion 1 JSON lesson package matching Example-Lesson-Package.json. Preserve the source's idea order. Show what you reviewed and what remains uncertain. Teach one idea at a time with concise screens, original examples, source-linked explanations and a takeaway, guide/storyteller narration roles, and two transfer questions with feedback for every choice. State coverage limitations and label fictional examples. Do not fill unavailable parts of the source from guesses. Give me the content to review before I import it.”
