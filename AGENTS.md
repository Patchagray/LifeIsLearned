# Life Is Learned — Standing Instructions

## Purpose and priorities

Build a native SwiftUI iPhone/iPad app primarily for my personal learning.

Prioritize:

1. Information quality and source fidelity.
2. Clear, manageable learning chunks.
3. High-quality, separately selectable narration voices.
4. Reliable automatic lesson progression and flexible manual controls.
5. UI polish after the core experience works.

Challenge weak assumptions and explain meaningful tradeoffs. Do not blindly agree, silently change requirements, or expand the product beyond the requested task.

## Core experience

Preserve this journey:

Book overview → ordered idea list → introduction → illustrated lesson screens → revealable takeaway → practice questions → explanatory feedback → completion → return to the book.

Use a guide voice for introductions, explanations, takeaways, and feedback; use a storyteller voice for the lesson body. My preference is an older, crisp male guide and a younger, softer female storyteller. Provide previews and choices; do not promise vocal characteristics that have not been auditioned.

Automatic progression must follow actual narration completion, with an adjustable pause between screens. Stop for reflection and questions. Support pause/resume, replay, back/next, and saved reading position.

## Information quality

Ground lessons in reviewed source material. Identify what was reviewed and what remains unavailable.

Distinguish the author's claims, supporting evidence, our explanations, and original fictional examples. Never invent quotes, statistics, chapter contents, page references, or research conclusions.

Do not present the starter priors lesson as a complete summary of Chapter 1 or the whole book. Review new lesson content and answer keys before importing it.

## Engineering

Keep models, persistence, playback, lesson state, and views in focused files. Avoid one enormous SwiftUI file.

Prefer native capabilities and minimal dependencies. Ask before adding paid services, cloud AI/TTS, accounts, subscriptions, or major architecture changes.

Preserve existing work. Do not delete user data, rewrite Git history, force-push, or alter signing identities without explicit approval.

Fix root causes. Do not suppress failures or weaken tests merely to obtain a passing result.

## Verification

For implementation changes, build the relevant target and run affected tests.

Check voice switching, pause/resume, cancelled playback callbacks, manual navigation during playback, lesson closure, interruptions, background behavior, and automatic-progression boundaries.

Check incorrect-answer feedback, retries, first-attempt scoring, progress restoration, and valid/invalid imports.

Inspect relevant layouts on iPhone and iPad, including large text sizes.

Clearly distinguish code inspection, successful compilation, passing tests, simulator observations, and physical-device verification. Never claim an unperformed check passed.

## Shared work and evidence

Once the GitHub destination is confirmed, commit and push completed implementation work to a dedicated branch. Inspect the diff first and stage only task-related files. Do not merge into the default branch without my approval.

Make the actual source changes available for review—not just a narrative report. Identify the repository, branch, and exact commit.

Keep relevant build/test evidence tied to that commit. Do not commit secrets, personal data, DerivedData, or large generated artifacts. Clearly label simulator screenshots and any checks awaiting hardware.

## Communication

I am a beginner. Keep updates brief and professional.

When my action is needed, explain exactly what to open, click, or select. When giving code for manual editing, provide the complete file or an exact insertion location.

At handoff, state what changed, what was verified, what remains uncertain, and where the pushed work can be inspected.

## Whole-collection imports (Handoff 002)

Import books only as their entire prepared, reviewed collection, including updates. Require a versioned collection manifest, stable IDs/revisions, shared artwork, and explicit coverage. Stage and review changes before confirmation. Never silently import individual-idea patches, remove omitted ideas, reset unchanged progress, or treat structural validation as factual review. Preserve archived progress and legacy installations through recoverable migration. See CONTENT_AUTHORING.md and LifeIsLearned_Handoff_002.pdf.


## Content limits and timing (Handoff 003)

Handoff 003 supersedes conflicting limits and duration guidance in Handoff 002. New complete collections and updates contain 1–12 selected ideas; twelve is a ceiling, never a quota. Preserve previously valid installed collections of up to 100 ideas and all progress. Apply the new limit at import/review, never by truncating stored books or creating disguised volumes. Updates explicitly declare removals and preserve archived progress.

There is no numerical image-count ceiling. Keep shared assets, unique nonempty IDs, valid references and cover validation. Retain 64 MiB package, 2 MiB per image, 24 MiB total decoded image-file bytes, 2048 × 2048 dimensions, single-frame PNG/JPEG and native decoding protections.

Authored releases have exactly two meaningful application questions. Budget the entire reference idea at no more than 300 seconds: all spoken titles/prose, options and their labels, one longest feedback response per question with spoken prefixes, completion, actual page-transition pauses, and 40 seconds for answers. Start planning at 130 words/minute and a 2-second page pause; measure at normal speed using only installed premium reference voices. Record actual voice IDs/settings/durations separately from estimates. An estimatedMinutes value is not evidence. Block over-budget authoring/export and require matching premium measurements for release approval. Never shorten runtime speech or change a user's speed/pause to enforce the budget.

Show the actual selected-idea count and honest coverage before starting; do not imply an exhaustive summary or an author's ranking. Keep source limits explicit and use original, attributed content/artwork. Changed content/estimates require idea and collection revision increases. The shortened demo is an explicit reviewed full-collection update, never an automatic replacement of an installed book. Mario is curating the two companion collections externally for later import.

Keep the manual Files picker. GitHub Releases plus a small catalog is a future distribution direction; cloud browsing, accounts, downloads, release publishing and bulk imports are outside this patch.

## Idea cards and completion flow (Handoff 004)

Completion now offers the next sequential active idea directly, or Finish book for the final idea; retain Back to book and optional card/review actions. This extends the original completion → book journey. No new autoplay, progress reset, or first-attempt-score overwrite during review.

Collect a card after practiceComplete, including imperfect attempts. Identity is bookID + lessonID across revisions. Preserve original earned date, unknown historical dates, favorites, and the last earned text snapshot. New revisions show Updated until completed again; earned removed ideas remain archived. No new import fields, duplicated artwork, invented facts, or automatic content rewrites.

Keep Ideas reachable from home. Provide a focused flip-card carousel and a two-column staggered grid (one readable column at accessibility text sizes), stable sort/filter behavior, and independent favorite controls. Favorite motion must be restrained, limited to visible active cards, and static with Reduce Motion. Keep VoiceOver's grid order top-to-bottom, with named open/flip/favorite/review actions. Verify rendered iPhone/iPad, light/dark and large-text layouts; distinguish simulator evidence from subjective physical animation checks.

## Catalog 001 identity foundation (Handoff 004.5)

`Catalog/Catalog-001.json` is the separate static editorial identity source for the approved 50 books and eight shelves. Do not repurpose the installed `CollectionCatalog` or infer package availability from catalog presence. Reuse the exact catalog book ID before authoring; preserve established `influential-mind` and `never-split-the-difference` IDs across revisions. New titles outside Catalog 001 require an approved later catalog revision. Validate changes with `Tools/validate_catalog.py` and its negative tests. Keep the whole-collection import, 1–12 idea and ≤300-second reference contracts. Handoff 004.5 is metadata/validation only; Handoff 005 will address remote discovery/distribution separately.

## Six-stage authoring and reader (Handoff 004.6)

New/re-authored ideas require exactly six illustrated pages: intro, explanation, story, story, application, takeaway; roles guide, guide, storyteller, storyteller, guide, guide. Require six distinct image IDs and resolved image bytes with descriptions, exactly two questions and the existing ≤300-second complete experience gate. Cross-idea byte reuse is an editorial warning. Keep runtime 2–40-page compatibility, stable identities, revisions, stored progress and collected cards. Never auto-rewrite old packages to meet the new authoring standard. See CONTENT_AUTHORING.md and the root Handoff 004.6 PDF.

Canonical progress has five weighted stages (1:1:2:1:1), with physical Story halves and accessible physical screen counts. Legacy sequences use per-page capsules. Only Story pages auto-follow narration; manual scrolling, VoiceOver and Reduce Motion retain priority. Takeaway artwork is visible without changing card snapshots or reveal/practice boundaries.

Handoff 005 must implement real book offload by separating removable prose/art/package snapshots from durable cards, favorites, progress and lightweight book history. Removing only the active catalog entry cannot reclaim historical payload snapshots. Preserve stable identities and reconnect compatible progress upon reinstall. Offload, downloads and History UI remain outside 004.6; do not ship offload before reclamation and state-preservation tests pass.
