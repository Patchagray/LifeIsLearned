# Life Is Learned · V1 starter

An independent native SwiftUI iPhone/iPad app for Mario: learn one idea at a time through illustrated screens, two narration roles, automatic progression, and feedback. The name is provisional.

## Run it

1. Unzip this folder on your Mac.
2. Open **LifeIsLearned.xcodeproj** in Xcode (Xcode 16 or newer recommended; minimum iOS/iPadOS 17).
3. Choose the **LifeIsLearned** scheme and an iPhone simulator. Press **⌘R**.
4. For your physical iPhone/iPad: select the app target → **Signing & Capabilities** → select your Apple development team. Select your connected device and press **⌘R**. If asked, enable Developer Mode on the device. No API key or external dependency is needed.
5. Open The Influential Mind → The Prior Problem → Play. The app begins with the guide, switches to the storyteller, and returns to the guide for the explanation and takeaway.
6. Tap the sliders to audition and select both voices. Download any additional English voices in the device's Accessibility voice settings before selecting them. Age and vocal texture cannot be guaranteed by Apple's voice API; listen on the actual device.

Use **⌘U** to run the included XCTest target. Use an installed simulator. Voice quality should be checked on hardware, rather than inferred from the simulator.

## Included experience

- Book library, book description, source notes, available idea list.
- Eight lesson screens; 684 narrated words, approximately 4–5 minutes at the default pace.
- Three original scene illustrations (setup, disagreement, collaboration) reused where appropriate.
- Guide and storyteller voice choices, previews, speed and screen-pause controls.
- Auto-advance on actual speech completion, pause/resume, replay, back/next, spoken-word emphasis.
- A revealable idea card. Playback stops here. Practice requires your action.
- Two practice questions, feedback for every answer, retries, first-attempt score, completion.
- Reading position and practice progress saved on device. You can revisit screens freely.
- JSON lesson import from Files, validated before replacing an existing book. Embedded PNG/JPEG illustrations supported.
- Dynamic Type, text-size adjustment, accessible control names, illustration descriptions, and scrollable content.

This app reproduces the reference interaction sequence with its own design, content, and artwork. It does not use the reference app's screenshots, mascot, prose, or artwork.

## Content quality

The bundled lesson is an **introductory concept lesson**, not a complete summary of Chapter 1 or the whole book. Its coverage note explicitly identifies that limitation. It uses the publisher's publicly available prologue to identify priors in Sharot's framework, plus a separately identified 2019 paper involving Sharot to support a limited explanation of confirmation bias. The college program and report are fictional. The shared-goal intervention is our teaching example, not a research result from that study.

New content should be reviewed against the supplied book/article/PDF before import. The app displays coverage notes and citations; it does not independently verify that a package's claims or answer key are true.

Sources:
- Tali Sharot, The Influential Mind (2017), publisher-provided prologue: https://us.macmillan.com/books/9781627792660/theinfluentialmind/
- Kappes et al. (2019), Confirmation bias in the utilization of others' opinion strength, Nature Neuroscience, DOI 10.1038/s41593-019-0549-2: https://affectivebrain.com/wp-content/uploads/2019/12/s41593-019-0549-2.pdf
- Apple's speech API: https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer

## Add a lesson

`Example-Lesson-Package.json` is an importable example and the complete format reference. See `CONTENT_AUTHORING.md` for authoring requirements. Send the source material to the content-authoring session, review the package, save it as JSON, and import that file. A PDF or book title is not itself an importable lesson. Importing the same book ID replaces that book's content. Increment a changed lesson's `revision` to keep old progress from applying to different material.

The app is intentionally a lesson player. Automatic book/PDF extraction, live AI generation, arbitrary free-text grading, cloud TTS, audio caching, accounts, and spaced review scheduling are later work. Playback is foreground-only in this starter; going to the background pauses it. There is no lock-screen player.

## Files

- `LifeIsLearned/Models/LessonPackage.swift`: format and validation.
- `LifeIsLearned/Services/LibraryStore.swift`: content import, persistence, progress.
- `LifeIsLearned/Services/PlaybackSettings.swift`: settings and installed voice selection.
- `LifeIsLearned/Services/SpeechPlayer.swift`: native speech, interruptions, word ranges.
- `LifeIsLearned/Services/LessonSession.swift`: reading/practice playback state.
- `LifeIsLearned/Views/`: library, reader, practice, completion, settings and source views.
- `LifeIsLearned/Resources/starter.json`: starter content.
- `Tests/LessonSessionTests.swift`: tests for sequencing, pause/resume, stale callbacks, quiz boundaries, scores, persistence and invalid import handling.
- `CODEX_HANDOFF.md`: the next build task for Codex on your Mac.
- `VALIDATION.md`: exactly what has and has not been verified.

## Validation status

This package was created in a Linux workspace. It has **not been compiled or run in Xcode** here. Content, file references, scheme structure and image packaging were checked; native compiler and simulator checks remain the first Mac-side step. The XCTest suite is included but has not been executed here. Do not label this a tested iOS build until those checks pass.
