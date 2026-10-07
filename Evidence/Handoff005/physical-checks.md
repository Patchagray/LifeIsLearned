# Handoff 005 physical checks — pending

None of the checks below is reported as performed for Handoff 005. Earlier device approvals apply to their earlier commits.

## Open and run

1. Open `LifeIsLearned.xcodeproj` in Xcode from this repository.
2. Select the **LifeIsLearned** scheme and your connected **PATCHA** iPhone as the run destination. Keep your existing signing settings.
3. Press **Command–R**. If Xcode reports a signing, trust or device-access error, resolve that specific prompt before continuing.

## Device checks

- **Reader and narration:** Open a reviewed canonical six-stage idea. Confirm large Hook, Explanation and Practical Application images, cinematic Story art, Story-only follow scrolling, Takeaway card and exactly two questions. Try your installed premium guide/storyteller voices, pause/resume, replay, back/next, closure, interruption and background/foreground. Check normal and large text; capture device images separately from the simulator evidence.
- **Completion:** Finish an uncompleted revision, including one incorrect answer and retry. Confirm one brief Bloom, success haptic and quiet chime without blocking the existing controls. Reopen the completed idea: no full first-completion replay. Check the two feedback settings, the device silent switch and Reduce Motion. Confirm narration remains intact.
- **Offload:** Use an imported test collection whose JSON you can re-import. Earn/favorite a card, open the book options and read the Offload confirmation. After offload, check History, card text/favorite and manual re-import messaging. Re-import that same collection and confirm saved learning state and no duplicate card. Deterministic byte reclamation is already recorded in the storage evidence; device storage accounting is a separate observation.
- **Scanner:** Tap **+ → Scan a Book → Open camera**. Try a visible ISBN barcode and cover text in different lighting. Review/edit recognized metadata. Confirm denied permission has a typed-search fallback and Settings link. No camera images should be sent; the app only submits reviewed metadata after Request.
- **Dive Deeper:** With a prepared package containing reviewed deeper content, confirm it is locked before practice, then available from completion and the earned card. After offload, confirm the source-specific reinstall/re-import action. Deeper reading must not appear as a seventh core stage.

## Gates that need later configuration

- The bundled discovery preview currently marks all titles planned. Real download/update/offload/redownload and real request submission require the reviewer-controlled catalog/releases/backend configuration in `Catalog/REMOTE_LIBRARY.md` and `Backend/RequestAPI/README.md`. Fixture success does not establish production availability.
- The production AppIcon uses your selected A — Idea Fold direction. Check it on the device home screen in standard, dark and tinted contexts.

Record the tested commit, device/iOS version, voice IDs/settings, observations and any failures when reporting results. Do not mark pending items passed based only on compilation or simulator screenshots.

## Optional isolated fixture walkthrough

To inspect the new surfaces before production endpoints/content are ready, use the existing Debug-only fixtures:

1. In Xcode choose **Product → Scheme → Edit Scheme → Run → Arguments**.
2. Under **Environment Variables**, add `LIL_UI_TEST_RUN_ID` with value `2BE92F2B-F099-4B41-B5FB-03E54BBC0050`. This uses an isolated temporary library and settings, separate from your normal learning state.
3. Add one fixture variable with value `1`:
   - `LIL_SIX_STAGE_FIXTURE` for six-stage artwork and a two-image Story.
   - `LIL_DEEPER_FIXTURE` for practice → completion → Dive Deeper and earned-card access.
   - `LIL_DISCOVERY_FIXTURE` for synthetic browse/download/update/offline/request responses.
4. Run with Command–R. Fixture titles identify verification content. It is not reviewed book content, real release availability or a live request backend. The scanner's fixture ISBN association is synthetic.
5. Disable these environment-variable checkboxes and run again to return to the normal library/configuration. Use a different valid UUID if you want a fresh isolated test library.

These fixtures support interface checks. They do not replace physical voice/silent-switch/camera observations or the later production-network smoke test.
