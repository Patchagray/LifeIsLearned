# Codex build handoff · Life Is Learned V1

Mario wants you to take over native build work on his Mac. Read README.md, CONTENT_AUTHORING.md and VALIDATION.md, then inspect the supplied code. This is a prepared implementation; it has not yet been compiled on an Apple toolchain. Your first task is to make the provided project compile and work on iPhone/iPad, rather than redesign the product.

## Priorities

1. Information quality: source-scoped concepts, faithful distinctions, original illustrative scenarios, explicit limitations, correct answer keys. Never imply that a title or publisher description establishes full chapter coverage.
2. Consumption flexibility: small screens with natural reading order, easy manual control, text-size adjustment and readable layouts.
3. Narration: separately selectable guide and storyteller voices. Mario prefers an older, crisp male guide for opening/ending and a younger, softer female storyteller for the body. Audition available voices on hardware; don't promise age/timbre the OS doesn't expose.
4. Progression: continuously narrate and advance through the lesson; a configurable pause between screens; stop for reflection and questions; reliable pause/resume, replay, back/next, cancellation and saved progress.
5. UI polish follows a working core. Keep the native SwiftUI project and modular files. Do not add accounts, social features, subscriptions, cloud generation or a dependency framework to solve the initial build.

## User's reference sequence

Book overview → main idea list → introduction → illustrated lesson screens with segmented progress and back/next/Play → revealable takeaway card → multiple-choice application questions → immediate explanatory correct/incorrect feedback → retry or Continue → completion → Continue book.

The reference screenshots were reviewed during authoring. They depict The 48 Laws of Power, but the starter uses The Influential Mind. Preserve the interaction pattern; use our original artwork and prose.

## Execute

- Inspect local instructions and the project. Enumerate installed Xcode and simulator destinations. Build the LifeIsLearned scheme for an available iPhone simulator. Fix actual compiler or project-file errors.
- Run the included XCTest target and resolve failures. Expand testing only where an observed failure or missing core acceptance check warrants it.
- Run the app and inspect the complete starter journey. Test iPhone portrait, iPad, a landscape layout, and a large accessibility text size.
- Test speech on hardware when available. Keep device-only voice quality checks clearly distinguished from simulator checks. Don't change an Apple account or signing identity without Mario's instruction; selecting his existing team in Xcode may be needed for device deployment.
- Verify play from intro changes guide → storyteller → guide; actual utterance finish drives progression; pause/resume keeps the current utterance; replay restarts the screen; tapping next/back cannot let a cancelled utterance advance the new screen; closing/settings/source sheets stop playback; backgrounding pauses; an audio interruption doesn't resume unexpectedly.
- Verify the takeaway never autostarts practice; wrong answers provide feedback, can retry, and don't inflate first-try scores; practice-only revisits don't claim a new reading completion.
- Verify the app can relaunch at the saved page; malformed imports leave the existing library intact; a valid revised package imports, displays custom embedded artwork, survives relaunch, and uses new progress for a new revision.
- Make build/test results concrete: report the Xcode version, destination, commands, tests passed/failed, observed UI/audio behavior and anything still awaiting the physical device. Fix the core before proposing polish.

Example commands (substitute an installed simulator; the device name is not assumed):

```bash
xcodebuild -list -project LifeIsLearned.xcodeproj
xcodebuild -showdestinations -project LifeIsLearned.xcodeproj -scheme LifeIsLearned
xcodebuild -project LifeIsLearned.xcodeproj -scheme LifeIsLearned -destination 'platform=iOS Simulator,id=YOUR_SIMULATOR_UDID' build
xcodebuild -project LifeIsLearned.xcodeproj -scheme LifeIsLearned -destination 'platform=iOS Simulator,id=YOUR_SIMULATOR_UDID' test
```

## Architecture

Content is Codable JSON. LibraryStore validates/imports it and persists it atomically. LessonSession manages page/quiz state and cancellable delayed progression. SpeechPlayer wraps AVSpeechSynthesizer and invalidates stale utterance callbacks by identity. Narrating is a test seam; production uses native speech, tests use FakeNarrator. Settings and progress are local. The Xcode project has a shared scheme and a hosted XCTest target. Project regeneration is optional using Tools/make_project.py, but it will overwrite manual project-file changes; don't run it blindly after updating the project.

## Content expansion

Only one starter lesson is supplied. Do not invent the rest of the book from its title. Ask for the necessary source material when the content-authoring task requires it. Review new lessons separately from app changes, link teaching screens to specific sources, label inventions, and explain uncertainty. No extraction/generation pipeline is implemented in V1.

## Finish

Deliver a working local app build and a concise status summary. Mario is a beginner: explain exactly which file/project to open, which scheme/destination to select, and how to run it. Keep changes in separate files rather than merging the app into one huge SwiftUI file.
