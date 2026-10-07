# Life Is Learned · An illustrated reading room

An independent native SwiftUI iPhone/iPad app for Mario: learn one idea at a time through illustrated screens, two narration roles, automatic progression, and feedback. The name is provisional.

## Handoff 005 implementation branch

Reader artwork/authoring cleanup and completion feedback are implemented. Library-v3 separates removable packages from cards, progress and History; **Book options → Offload Book** reclaims package/art storage, and **History** retains offloaded books. Manual books require re-import; remote source metadata is retained for the discovery/download epic. Older sections below document prior milestones and their original verification boundaries. See [current Handoff 005 evidence](Evidence/Handoff005/README.md).

## Run it

1. Open the local project folder, or clone this repository on your Mac.
2. Open **LifeIsLearned.xcodeproj** in Xcode (Xcode 16 or newer recommended; minimum iOS/iPadOS 17).
3. Choose the **LifeIsLearned** scheme and an iPhone simulator. Press **⌘R**.
4. For your physical iPhone/iPad: select the app target → **Signing & Capabilities** → select your Apple development team. Select your connected device and press **⌘R**. If asked, enable Developer Mode on the device. No API key or external dependency is needed.
5. Open The Influential Mind → The Prior Problem → Play. The app begins with the guide, switches to the storyteller, and returns to the guide for the explanation and takeaway.
6. Tap the sliders to audition and select both voices. Download any additional English voices in the device's Accessibility voice settings before selecting them. Age and vocal texture cannot be guaranteed by Apple's voice API; listen on the actual device.

Use an installed simulator for unit/layout and app journey tests. The manual Files-import UI check requires its fixture first: boot the selected simulator, run `python3 Tools/prepare_simulator_import.py SIMULATOR_UDID`, then press **⌘U**. Premium-voice timing runs on a physical device and is explicitly skipped in simulator suites. See `VALIDATION.md` for the exact commands.

## Handoff 003: content limits and whole-idea timing

New collections and updates contain **1–12 selected ideas**. Previously valid installed books with 13–100 ideas remain readable with their progress intact. Shared images have **no numerical count cap**; file-size, decoded-byte, dimension, type and decoding protections remain. Manual Files import, preview and explicit confirmation are unchanged.

New authored ideas have exactly two application questions and a **five-minute reference budget for the complete experience**, including narration, options, feedback, transitions and answering time. The interface shows an approximate whole-idea estimate and explains why individual listening time can vary. First start opens the book's selection and source coverage before reading.

The shortened demo is `Example-Lesson-Package.json`: `influential-mind` / `priors`, collection and idea revision **2**, six screens, 413 total reference spoken words. It is an explicit complete update. Select it using **Import book → Files → Import complete update**. The old revision's progress stays archived; the revised idea begins unpracticed. The revision-1 startup seed is frozen to preserve installed content.

- Brief: `LifeIsLearned_Handoff_003_Content_Limits_Patch.pdf`.
- Authoring limits, timing gate and premium-voice measurement: `CONTENT_AUTHORING.md`.
- Stored-book compatibility and migration: `PERSISTENCE.md`.
- Verification: `VALIDATION.md` and `Evidence/Handoff003/`.

The two larger companion collections are being curated separately for later import under these rules. No cloud catalog, release publishing, bulk import or new book material is included in this patch.

## Handoff 002

One learning home now combines Continue learning and your book library. Prepared books import as complete collections with a preview, explicit update/removal review, revision protection, and recoverable local persistence. Interrupted reading and practice resume without starting audio. The complete journey uses an editorial light/dark design with adaptive book covers, illustrations, source notes, clear answer feedback, and accessible controls.

- Brief: `LifeIsLearned_Handoff_002.pdf` (copied unchanged into the repository root).
- Visual rules: `DESIGN_SYSTEM.md`.
- Format and authoring: `CONTENT_AUTHORING.md` and the format-2 example package.
- Persistence/migration/recovery: `PERSISTENCE.md`.
- Verification and labeled simulator evidence: `VALIDATION.md`, `Evidence/Handoff002/`.

## Included experience

- Book library, book description, source notes, available idea list.
- Frozen legacy demo: eight screens, retained for continuity. Explicit shortened update: six screens; the complete reference timing includes the quiz and feedback, not only the story.
- Three original scene illustrations (setup, disagreement, collaboration) reused where appropriate.
- Guide and storyteller voice choices, previews, speed and screen-pause controls.
- Auto-advance on actual speech completion, pause/resume, replay, back/next, spoken-word emphasis.
- Narration follows long Story text by scrolling the spoken line into view when needed. Manual drags take priority; following resumes as narration continues after the drag settles. Reduce Motion is respected, and automatic following is disabled while VoiceOver is running.
- A revealable idea card. Playback stops here. Practice requires your action.
- Two practice questions, feedback for every answer, retries, first-attempt score, completion.
- Reading position and practice progress saved on device. You can revisit screens freely.
- Complete book collection import from Files: validate, review, confirm, and open. Shared PNG/JPEG illustrations and optional cover artwork are supported.
- Dynamic Type, text-size adjustment, accessible control names, illustration descriptions, and scrollable content.

This app reproduces the reference interaction sequence with its own design, content, and artwork. It does not use the reference app's screenshots, mascot, prose, or artwork.

## Content quality

The bundled lesson is an **introductory concept lesson**, not a complete summary of Chapter 1 or the whole book. Its coverage note explicitly identifies that limitation. It uses the publisher's publicly available prologue to identify priors in Sharot's framework, plus a separately identified 2019 paper involving Sharot to support a limited explanation of confirmation bias. The college program and report are fictional. The shared-goal intervention is our teaching example, not a research result from that study.

New content should be reviewed against the supplied book/article/PDF before import. The app displays coverage notes and citations; it does not independently verify that a package's claims or answer key are true.

Sources:
- Tali Sharot, The Influential Mind (2017), publisher-provided prologue: https://us.macmillan.com/books/9781627792660/theinfluentialmind/
- Kappes et al. (2019), Confirmation bias in the utilization of others' opinion strength, Nature Neuroscience, DOI 10.1038/s41593-019-0549-2: https://affectivebrain.com/wp-content/uploads/2019/12/s41593-019-0549-2.pdf
- Apple's speech API: https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer

## Import a complete book collection

`Example-Lesson-Package.json` is an importable example and the complete format reference. See `CONTENT_AUTHORING.md` for authoring requirements. Send the source material to the content-authoring session, review the package, save the complete format-2 collection as JSON, and use the + (Import book) control. Review coverage and changes, then confirm the whole collection. A PDF or book title is not itself an importable lesson. Updates require a higher collection revision; changed ideas require higher idea revisions. Undeclared omissions are rejected. Unchanged progress survives reordering and display-metadata updates; revised ideas retain archived history and begin a fresh active state.

The app is intentionally a lesson player. Automatic book/PDF extraction, live AI generation, arbitrary free-text grading, cloud TTS, audio caching, accounts, and spaced review scheduling are later work. Playback is foreground-only in this starter; going to the background pauses it. There is no lock-screen player.

## Files

- `Catalog/Catalog-001.json`: approved static identities for 50 books across eight shelves; separate from installed packages. See `Catalog/README.md` and run `python3 Tools/validate_catalog.py` before editing/authoring catalog titles. Handoff 004.5 adds no app screen or networking; Handoff 005 will consume this foundation later.

- `LifeIsLearned/Models/`: collection contract/comparison, lesson models, and resumable progress.
- `LifeIsLearned/Services/LibraryStore.swift` and `CollectionStorage.swift`: import staging, atomic snapshot publication, migration, and progress.
- `LifeIsLearned/Services/PlaybackSettings.swift`: settings and installed voice selection.
- `LifeIsLearned/Services/SpeechPlayer.swift`: native speech, interruptions, word ranges.
- `LifeIsLearned/Services/LessonSession.swift`: reading/practice playback state.
- `LifeIsLearned/Views/`: library, reader, practice, completion, settings and source views.
- `LifeIsLearned/Resources/starter.json`: starter content.
- `Tests/`: collection safety, migration/recovery, resumable learning, playback/scrolling, contrast, and simulator-rendered layouts.
- `UITests/`: taps through the actual app, relaunches interrupted practice, and checks completion navigation.
- `CODEX_HANDOFF.md`: original bootstrap brief (historical); `LifeIsLearned_Handoff_002.pdf` is the implemented follow-up brief.
- `VALIDATION.md`: exactly what has and has not been verified.

## Validation status

Handoff 004: the committed implementation passed 52 tests on each simulator, plus the separate system Reduce Motion check. Six card UI tests passed on PATCHA; the signed build was installed and launched normally. The report includes 27 simulator screenshots, exact commands and remaining manual device checks. See [Handoff 004 evidence](Evidence/Handoff004/README.md).

Handoff 003: both simulator builds passed 35 tests each (one hardware-only voice test skipped per simulator), and all 12 Python authoring tests passed. The premium-only physical reference measured 225.17 seconds including pauses and answering allowance. The committed patch was built, installed and launched on PATCHA. See [Handoff 003 evidence](Evidence/Handoff003/README.md) for exact source, commands, screenshots and remaining physical checks.

Historical Handoff 002 verification passed 29 tests on each of the iPhone 16e and iPad (A16) simulators. Commit `f4a8693645c3e97a54567f1034f4d463b6506fb3` then built, installed, and launched on an iPhone 15 Pro Max running iOS 27.2. After checking that device build, the user reported “All checks are good” and approved pushing the work. See [VALIDATION.md](VALIDATION.md) for commands, outcomes, simulator evidence, and the scope of user-reported physical-device acceptance.

Handoff 003 results, premium voice settings/durations, and current import evidence are recorded in [VALIDATION.md](VALIDATION.md).

## Handoff 004: your collected ideas

Finish practice to collect an idea card, including after retries. Completion offers the next idea directly and resumes its saved position; the final idea offers **Finish book**. **Back to book**, **View collected card**, and **Review this idea** remain available. Reviewing preserves the original completion score and earned date and does not start audio automatically.

Tap the stack icon (**Ideas**) at the top left of home. Browse the staggered grid, open a card in the carousel, tap its body to see an application reminder, or use the separate star to favorite it. Use All/Favorites, book filtering and sort controls to find cards again. Earned ideas remain available if a collection removes them. Revised ideas show Updated until you complete the new revision.

The supplied brief is `LifeIsLearned_Handoff_004_Idea_Collection_and_Next_Flow.pdf`; implementation and verification evidence are in `Evidence/Handoff004/`. Card storage/migration details are in `PERSISTENCE.md`. Content import and narration formats are unchanged.

## Handoff 004.6: six-stage lesson support

New authored lessons use Hook → Explanation → Story A → Story B → Practical Application → Takeaway, with six distinct instructional illustrations. Canonical lessons show five labeled progress stages; Story takes two segments of width and fills halfway, then fully. Existing books retain their original per-screen indicator. Takeaway artwork now appears alongside the reveal interaction, and automatic narration scrolling is limited to Story pages.

The strict six-stage contract applies to authoring/release approval. Runtime format-2 imports and stored lessons retain 2–40-page compatibility. No installed content, demo/example, cards or progress is rewritten. The first content rebuild is a separate step after engineering review; therefore the current example remains a legacy compatibility example. See [authoring rules](CONTENT_AUTHORING.md) and [verification evidence](Evidence/Handoff004_6/README.md). Handoff 005 offload requirements are pinned in AGENTS.md and the root PDF; offload is not implemented here.
