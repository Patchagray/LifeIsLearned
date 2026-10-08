# Handoff 005 Audio Addendum

Implemented on `feature/handoff-005-library-platform`, starting at `b01b69df7699aa183b4b2538bfee44692f9c68c6`. The root audio PDF and supplied Markdown agree. No merge or production audio publication is included.

## Reviewed source and results

Tested/installed source: **`60882b3807f8e91476bbe7f39bce3661ef53d950`**. Native implementation commit: `ba619fb` followed by Sound Production tooling commit `60882b3`. The evidence follow-up changes no source. All **98 source/fixture hashes** match that commit.

- iPhone 16e and iPad (A16), iOS 26.3.1: **95 distinct affected tests passed, zero failed, one explicit physical-premium-voice timing skip per destination**. Broad regression passed 90; additional card/review/large-text journeys passed five. A final rerun passed all nine audio native tests and the audio UI journey on each simulator after the tolerant cue-decoding fix.
- **53 Python tests**, **512 portable checks**, Catalog 001 validation, exact Swift/Python script parity and the fixture audio gate passed. Normalization produced a decodable mono MP3; the synthetic signal's measured normalization output was -15.95 LUFS. This is not production speech QA.
- Signed Patcha build, strict signature verification, in-place installation and normal launch succeeded with existing signing. The first launch was blocked by the locked phone; the subsequent final build launched successfully. No fixture flags or library reset were used. No physical iPad installation was performed.
- Audio fixture: **15,351 installed bytes → 0 offloaded → 15,351 reinstalled**. The MP3 itself is 10,074 bytes. Cards, progress and history hashes were unchanged by offload; a failed deletion retained installed bytes and reinstall recovered studio mode.

[Exact commands](commands.md) · [Results](test-results.json) · [Test cases](test-cases.txt) · [Source hashes](tested-source-sha256.json) · [Storage proof](audio-storage-proof.json) · [Deployment](deployment.json) · [Physical checklist](physical-checks.md)

The `iphone-` and `ipad-` images are simulator captures: studio mode, return at Explanation after background auto-progression, and fallback-voice settings. Additional accessibility XXXL card captures show the existing scrollable presentation (the carousel was captured after scrolling); metadata previews retain their existing truncation. The screenshots and test interactions were inspected; no physical audio-quality claim is implied.

## Behavior and boundaries

- Optional format-2 `audioAssets` and per-lesson `narration` decode alongside legacy books. Complete expected IDs, roles, exact UTF-8 script SHA-256, mono MP3 full decode and plausible durations are checked before an idea chooses one engine. Every answer-feedback branch and every first-try completion score has its own segment.
- `NarrationController` fixes the mode for the session. Existing `SpeechPlayer` remains the device fallback and voice-preview engine. `PackagedNarrationPlayer` uses local-file AVPlayer items with spoken-audio pitch processing; no runtime ElevenLabs call or credential exists. A later clip failure stops audio and reports an error without switching voices or blocking manual reading/practice.
- Cues use UTF-16 coordinates, matching the existing read-along view. Valid cues drive its Story-only following. Missing or out-of-bounds cues produce no word highlight; they do not change engines. Coarse production cues are explicitly estimates, not forced alignment.
- Packaged playback uses the audio background mode, spoken playback audio session, book/idea/stage/cover Now Playing metadata and Play/Pause/Toggle commands. Session transitions retain page state and use a bounded background task during the learner's inter-page pause. Takeaway and practice remain interactive stops. Interruption or disconnected headphones pause without advancing; resumption is explicit.
- Settings identify Guide/Storyteller choices as **device fallback voices**. Speed applies to studio playback as well as local narration.
- Audio is excluded from pedagogical fingerprints. A voice/model/MP3/cue-only update requires a newer collection revision and preserves the existing idea revision, cards and progress. Changed prose still requires an idea revision and makes old audio script hashes stale.

## Storage decision

New narrated packages use one `.lilbook` binary property-list file in Library-v3. It stores audio `Data` as binary, avoiding base64 expansion. Existing non-audio JSON payloads keep their original representation. The state reference records the encoding, byte count and checksum; distribution/catalog checksums remain checksums of the delivered JSON. No full MP3 is put in cards, history or state snapshots.

At session preflight, only the chosen idea's referenced audio is written once to randomly named temporary files. AVPlayer reuses these files for replay; it never decodes base64 repeatedly or downloads a clip. Files use protection that permits reading after screen lock following the first unlock. Closing/replacing the session releases the lease. App startup removes only prior `LIL-Narration-<UUID>` leases left by a terminated process. These are disposable working files, not a second durable package copy. Temporary peak storage includes one idea's clips; this is the tradeoff for preserving the existing single-file, failure-safe offload transaction.

Offload unlinks the entire normalized payload under the existing recovery journal. A deletion failure restores the installed reference. Reinstall restores the exact compatible progress and cards. See `audio-storage-proof.json` for actual before/after bytes from the deterministic tone fixture, and `test-results.json` for measured outcomes.

## Evidence limits

`audio-tone-package-fixture.json` is synthetic QA content. Its MP3 is a generated sine tone, deliberately shared across segments to exercise routing and file playback. It is **not ElevenLabs speech**, voice audition evidence, or a reviewed book. Script identity can verify that a manifest describes the current text; human audio QA must still verify that the audible recording actually says those words.

The production tooling accepts downloaded ElevenLabs masters and provenance, normalizes locally, and packages all branches. No production voice IDs were selected, no generation credits were spent, and no book audio release was published. Production voice audition/approval and actual master generation remain Sound Production work.

Physical screen lock, headphones/Bluetooth interruption, lock-screen controls, audible Story alignment and return-to-foreground on Patcha remain pending until observed. Simulator background navigation and deterministic interruption/transition tests do not establish physical iOS scheduling or voice quality. See `physical-checks.md`.

## Implementation notes

- Apple API references: [AVPlayerItem audioTimePitchAlgorithm](https://developer.apple.com/documentation/avfoundation/avplayeritem/audiotimepitchalgorithm), [AVAudioFile sequential PCM decoding](https://developer.apple.com/documentation/avfaudio/avaudiofile), [Now Playing metadata](https://developer.apple.com/documentation/mediaplayer/mpnowplayinginfocenter).
- The initial native decoder read one block past EOF; full-length bounded reading fixed that error. Initial compiler fixes added explicit Codable keys and removed an overlapping mutation in a negative test. An initial UI fixture left its import-success sheet open; clearing fixture presentation state fixed the walkthrough. Raw attempts are retained locally; none are counted as passes.
- FFmpeg is a Mac authoring/QA dependency only. A Homebrew attempt was stopped when it began building dependencies; the verification environment uses an isolated `imageio-ffmpeg` binary under ignored LocalVerification. No app dependency was added.
