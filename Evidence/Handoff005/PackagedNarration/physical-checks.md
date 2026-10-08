# Physical audio checks — pending

Do not infer these outcomes from compilation, installation or simulator tests.

1. Import a reviewed complete format-2 narrated package. Open its idea and confirm **Studio narration · available offline**. Enable airplane mode and replay all pages, both question prompts, incorrect/correct feedback and completion. Confirm distinct approved Guide/Storyteller recordings and learner speed controls.
2. With automatic progression on, play Hook and lock the iPhone. Confirm uninterrupted audio through later reading screens and the configured pauses. Use lock-screen Pause, wait longer than the page pause, then Play. Check book/idea/stage metadata and cover when supplied.
3. Return to the app: the current page should match the recording. Confirm takeaway stops; start practice manually. A question clip must wait for an answer and never skip the question.
4. Start a Story with timed cues; confirm approximate text following, manual scrolling priority, VoiceOver and Reduce Motion behavior. A second fixture without cues should still use studio audio without highlighting.
5. Test a genuine call/audio interruption and unplug/disconnect headphones. Playback should pause without advancing. Resume deliberately. Close the lesson during playback and confirm no later callback advances it.
6. Offload the test book. Check retained cards/favorites/progress/history; re-import or redownload it and confirm compatible progress and studio mode reconnect.
7. Import a test copy with one missing/stale/corrupt clip: the whole idea should use device fallback voices, including practice and replay.

Record device/iOS, tested source SHA, package SHA/revisions, production voice/model IDs, observations and failures. Capture lock-screen metadata and foreground stage images only with user permission to share any personal content.

## Optional isolated tone check before production masters exist

In Xcode, **Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables**, set `LIL_UI_TEST_RUN_ID` to a new UUID and `LIL_AUDIO_FIXTURE` to `1`. Run on Patcha and open **Offline audio verification → Offline audio check**. This is an isolated library. Each clip is a short tone, not spoken narration; it can check offline routing, stage transitions and controls, but not voice quality or audible text alignment. Disable those variables and run again to return to the real library. Do not enable them when delivering the normal app.
