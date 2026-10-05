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
