# Handoff 004 — idea collection and next-idea flow

Implementation: `7a31213bf574ba6540e663d5177ceb4f178371a7` on `feature/handoff-004-idea-collection`, based on accepted Handoff 003 head `0fd3ef261b275c7adffbba2575f468398f0f4146`. Evidence-only commits may follow without changing executable source. Review against `feature/handoff-003-content-limits`; no default-branch merge is authorized.

Supplied root PDF is unchanged: SHA-256 `5ef702769b47fdcaf4f5dfa20b48ccd1840023bbc72cc9b989041ffa7912950f`. The handoff extends AGENTS.md's original completion → book path with optional direct continuation. All standing instructions remain; the H004 clarification is appended to AGENTS.md.

## Implemented

- Completion offers the next sequential active idea, resumes its saved position, labels completed destinations as review, and offers Finish book at the end. Back to book, card viewing and review remain explicit actions. No new autoplay.
- Cards are earned on completed practice, including imperfect results. Stable book/idea identity retains favorites and original dates across revisions. New revisions retain the earned snapshot until completed; removed earned ideas remain archived and can review retained source content.
- Independent `cards.json` joins the existing atomic snapshot boundary. Pre-H004 migration uses committed completed progress, keeps unknown dates unknown, and resolves historical text when available. Recovery preserves damaged files and enters read-only mode if both card copies are unreadable. A recovered older card copy can reconstruct missing ownership from newer committed completion records.
- Home Ideas entry, two lazy staggered columns, focused native carousel, readable card fronts/backs, favorites, book filtering and three sorts. The grid is centered and constrained to 820 pt on iPad, and becomes one full-text column at accessibility sizes.
- 0.4-second two-stage Y flip; 0.15-second crossfade under Reduce Motion. A favorite receives a 0.45-second edge sweep/tiny sparkle and restrained idle shimmer. Native scroll visibility on iOS 18+ (geometry fallback on iOS 17) and active-scene gating stop offscreen/background drawing.
- The grid uses explicit ordered UIKit accessibility elements at the real realized card bounds. Each card has a coherent full label and named actions. IDs and elements remain stable while favorite state changes. The grid’s Show details action opens the selected card’s back; Open begins on its front. Filled stars provide a non-color cue.

`SpeechPlayer.swift`, bundled starter, example collection, format version, import limits and signing configuration are unchanged. Long authored takeaways are preserved: thumbnails show an excerpt; focused fronts scroll the full text. Synthetic fixture titles are not new authored lessons and never populate the normal library.

## Verification results

All results below are for implementation commit **`7a31213bf574ba6540e663d5177ceb4f178371a7`**, on October 5, 2026. See [machine-readable results and screenshot hashes](verification.json) and the adjacent sanitized `*-test-results.txt` files.

| Destination / command | Passed | Failed | Explicitly skipped |
| --- | ---: | ---: | ---: |
| iPhone 16e simulator, full build/test | 52 | 0 | 2 |
| iPad (A16) simulator, full build/test | 52 | 0 | 2 |
| iPad simulator, actual system Reduce Motion enabled | 1 | 0 | 0 |
| PATCHA physical iPhone, H004 UI suite | 6 | 0 | 1 |
| Signed iOS Debug build; in-place device install; normal launch | All succeeded | — | — |

Each full simulator run contains 43 passing unit/layout tests plus 9 passing UI tests. The skipped cases are the physical premium-voice measurement and the system-Reduce-Motion-only UI test. The latter passed in the dedicated run with the actual setting enabled (static favorite pixels and accessible flipped details); the simulator preference was restored to its prior unset/off state afterward. The physical UI run skipped only that Reduce Motion-specific case. No failed or skipped case is counted as passing.

Build output includes Xcode’s benign “No AppIntents.framework dependency found” metadata warning. Simulator logs include system VoiceDB fallback/AX diagnostics; they are retained locally, and simulator voice quality is not claimed. There were no compiler errors or test failures in these final runs.

Simulator runtime: iOS 26.3.1, Xcode 26.5 (17F42), macOS host. iPhone 16e destination `20E0C31B-8975-45A3-8E2C-B91BC6C64E66`; iPad (A16) destination `B219EF2E-CFAA-43D2-8F69-804ED944F678`. Device identifiers and signing team are intentionally omitted from published device commands.

All UI runs use `LIL_UI_TEST_RUN_ID=<random UUID>` to select a temporary document directory and separate defaults. `LIL_IDEA_CARD_FIXTURE=1` builds two clearly labeled synthetic 12-idea collections with 20 earned cards and 7 favorites through the real storage/import paths. It is Debug-only and requires that isolated UUID namespace. Actual user books/progress are not used as test fixtures.

### Development findings resolved

Rendered checks caught an initially miscentered iPad sheet carousel and a transient negative grid width during zero-size layout. Deferring initial native scroll positioning and clamping the initial width fixed the underlying issues. The flip now swaps one real face at the edge instead of leaving two hidden scroll views alive. Accessibility uses an explicit stable container order instead of column order; Open and Show details have separate destinations. Tests wait for lazy cards and real animation completion before assertions; review is exercised through its actual visible button and reader result. Earlier failed runs are retained locally and are not counted as final passes.

### Coverage

| Area | Evidence |
| --- | --- |
| Perfect/imperfect earning; duplicate prevention; first score/date retained | `IdeaCardTests` |
| Same-ID revision, metadata/reorder, archive, historical source | `IdeaCardTests` |
| Unknown-date migration, orphan-progress exclusion, failure/recovery | `IdeaCardTests` |
| Next unstarted/in-progress/completed/final destination | `IdeaCardTests` and live completion UI test |
| Favorite persistence, flip independence, review launch | Live 20-card UI journey |
| Book/Favorites filters, deterministic sorts and semantic identity | Model and live UI tests |
| Alternating left/right accessibility order and actual grid tap bounds | Live grid filter/order test |
| One-column large text, centered carousel | Presentation and live accessibility-size test |
| Narration cancellation, pause/resume, manual navigation, closure, progression boundaries | Existing `LessonSessionTests` / `NarrationScrollingTests` |
| Unchanged manual Files import and incorrect-answer/retry/resume/final book return | Existing live `LearningJourneyUITests` |

## Screenshots and limits

Published screenshots in `Screenshots/` are labeled **simulator** and state. Physical screenshots were inspected locally and are not published because the phone’s system status area can include personal activity. Hosted SwiftUI captures exercise controlled light/dark/text-size/layout states; live UI screenshots come from actual taps and navigation. All use synthetic data. Screenshots demonstrate layout and state, not animation frame rate or voice quality.

**Physical iPhone 15 Pro Max (PATCHA), iOS 27.2:** six actual-app UI tests passed on implementation commit `7a31213bf574ba6540e663d5177ceb4f178371a7`; the Reduce Motion-only test was explicitly skipped because that setting was off. The device earned a card after a wrong answer/retry, opened its card, continued to the saved next screen without starting narration, browsed 20 synthetic cards with 7 favorites, flipped cards, toggled favorites independently, retained them across relaunch, and opened review. Grid and carousel favorite pixels changed while the ordinary card remained still. The signed build, in-place installation, and normal launch without fixture variables all succeeded.

These are physical-device automated assertions and inspected static renders. They do **not** establish measured frame rate, subjective animation smoothness, haptic feel, or a spoken VoiceOver audition. Those remain Mario’s manual checks. No new premium-voice audition/timing, audio interruption, or background playback check was performed on hardware for H004; the prior H003 acceptance/timing is historical evidence, and the speech implementation is unchanged. Only iOS 26.3.1 simulators and iOS 27.2 hardware were exercised; the iOS 17 visibility fallback was compiled and inspected, not run on an installed iOS 17 destination.

### Selected screenshots

All links below are **simulator evidence**, from the tested implementation. `live` captures use actual app navigation; the other captures host the production SwiftUI views with controlled size/appearance. The full 27-image list and hashes are in [verification.json](verification.json).

| State | Evidence |
| --- | --- |
| Completion and resumed next idea | [Completion](Screenshots/simulator-iphone-live-completion-next.png), [next screen 3/8](Screenshots/simulator-iphone-live-next-resumed.png) |
| Carousel and favorites | [Front](Screenshots/simulator-iphone-live-carousel-front.png), [back](Screenshots/simulator-iphone-live-carousel-back.png), [Favorites filter](Screenshots/simulator-iphone-live-favorites-back.png), [favorite active](Screenshots/simulator-iphone-live-favorite-active.png) |
| Grid, filters and empties | [20 cards](Screenshots/simulator-iphone-live-grid-20.png), [book/alphabetical](Screenshots/simulator-iphone-live-book-filter-alphabetical.png), [empty](Screenshots/simulator-iphone-live-empty.png), [empty favorites](Screenshots/simulator-iphone-live-empty-favorites.png) |
| iPad portrait / landscape | [Grid portrait](Screenshots/simulator-ipad-grid.png), [grid landscape](Screenshots/simulator-ipad-grid-landscape.png), [carousel portrait](Screenshots/simulator-ipad-carousel.png), [carousel landscape](Screenshots/simulator-ipad-carousel-landscape.png), [completion sheet](Screenshots/simulator-ipad-live-collected-card.png) |
| Dark appearance | [Phone grid](Screenshots/simulator-iphone-grid-dark.png), [phone front](Screenshots/simulator-iphone-carousel-dark.png), [phone back](Screenshots/simulator-iphone-card-back-dark.png), [iPad grid](Screenshots/simulator-ipad-grid-dark.png), [iPad carousel](Screenshots/simulator-ipad-carousel-dark.png) |
| Accessibility text / Reduce Motion | [Phone full-text column](Screenshots/simulator-iphone-grid-accessibility3.png), [phone scrolled bottom](Screenshots/simulator-iphone-grid-accessibility3-bottom.png), [iPad column](Screenshots/simulator-ipad-grid-accessibility3.png), [static favorite](Screenshots/simulator-ipad-live-reduce-motion-front.png), [details](Screenshots/simulator-ipad-live-reduce-motion-back.png) |

Rendered review checked readable type, restrained gold edges, independent stars, consistent portrait proportions, 40% right-column stagger, a centered iPad content window, and the one-column accessibility fallback. Long source takeaways stay intact and scroll inside focused fronts; grid thumbnails deliberately excerpt them at normal text sizes. Still images do not demonstrate animation smoothness.

## Actual commands

Run from the repository root. Exact raw invocations/results are retained locally in the ignored `LocalVerification/Handoff004/` folder; result bundles and full raw logs are not published.

```sh
xcodebuild -project LifeIsLearned.xcodeproj -scheme LifeIsLearned -configuration Debug -destination 'platform=iOS Simulator,id=20E0C31B-8975-45A3-8E2C-B91BC6C64E66' -derivedDataPath /tmp/LifeIsLearned-H004-DerivedData -resultBundlePath /tmp/LifeIsLearned-h004-phone-commit.xcresult -parallel-testing-enabled NO test > /tmp/LifeIsLearned-h004-phone-commit.log 2>&1
xcodebuild -project LifeIsLearned.xcodeproj -scheme LifeIsLearned -configuration Debug -destination 'platform=iOS Simulator,id=B219EF2E-CFAA-43D2-8F69-804ED944F678' -derivedDataPath /tmp/LifeIsLearned-H004-iPad-DerivedData -resultBundlePath /tmp/LifeIsLearned-h004-ipad-commit.xcresult -parallel-testing-enabled NO test > /tmp/LifeIsLearned-h004-ipad-commit.log 2>&1
xcodebuild -project LifeIsLearned.xcodeproj -scheme LifeIsLearned -configuration Debug -destination 'platform=iOS,id=<PRIVATE_DEVICE_UDID>' -derivedDataPath /tmp/LifeIsLearned-H004-Device-DerivedData -resultBundlePath /tmp/LifeIsLearned-h004-device-commit.xcresult -parallel-testing-enabled NO -only-testing:LifeIsLearnedUITests/IdeaCollectionUITests -allowProvisioningUpdates DEVELOPMENT_TEAM=<EXISTING_TEAM> test > /tmp/LifeIsLearned-h004-device-commit.log 2>&1
# The iPad key was originally absent (system Reduce Motion off).
xcrun simctl spawn B219EF2E-CFAA-43D2-8F69-804ED944F678 defaults write com.apple.Accessibility ReduceMotionEnabled -bool YES
xcodebuild -project LifeIsLearned.xcodeproj -scheme LifeIsLearned -configuration Debug -destination 'platform=iOS Simulator,id=B219EF2E-CFAA-43D2-8F69-804ED944F678' -derivedDataPath /tmp/LifeIsLearned-H004-iPad-DerivedData -resultBundlePath /tmp/LifeIsLearned-h004-reduce-motion-commit.xcresult -parallel-testing-enabled NO -only-testing:LifeIsLearnedUITests/IdeaCollectionUITests/testSystemReduceMotionStaticFavoriteAndFlip test > /tmp/LifeIsLearned-h004-reduce-motion-commit.log 2>&1
xcrun simctl spawn B219EF2E-CFAA-43D2-8F69-804ED944F678 defaults delete com.apple.Accessibility ReduceMotionEnabled
xcodebuild -project LifeIsLearned.xcodeproj -scheme LifeIsLearned -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /tmp/LifeIsLearned-H004-Install-DerivedData -allowProvisioningUpdates DEVELOPMENT_TEAM=<EXISTING_TEAM> build > /tmp/LifeIsLearned-h004-device-commit-build.log 2>&1
xcrun devicectl device install app --device <PRIVATE_DEVICE_ID> /tmp/LifeIsLearned-H004-Install-DerivedData/Build/Products/Debug-iphoneos/LifeIsLearned.app --timeout 60 --json-output /tmp/LifeIsLearned-h004-device-install.json > /tmp/LifeIsLearned-h004-device-install.log 2>&1
# A nonempty inherited fixture environment is explicitly excluded from the normal launch.
env -u DEVICECTL_CHILD_LIL_UI_TEST_RUN_ID -u DEVICECTL_CHILD_LIL_IDEA_CARD_FIXTURE xcrun devicectl device process launch --device <PRIVATE_DEVICE_ID> --terminate-existing --timeout 60 --json-output /tmp/LifeIsLearned-h004-device-launch-final.json com.mariosinclair.lifeislearned > /tmp/LifeIsLearned-h004-device-launch-final.log 2>&1
```

## Open and run

1. Open `LifeIsLearned.xcodeproj` in Xcode.
2. Select the **LifeIsLearned** scheme and **PATCHA**, or the installed **iPhone 16e** simulator.
3. Click the triangular **Run** button (⌘R).
4. Tap **Ideas** (stack icon at the top left). Completed ideas are migrated into cards automatically; complete practice to collect another.
5. Tap a card to open it, tap its body to turn it over, or use the separate star. From completion, choose **Continue to next idea** or **Back to book**.

Do not delete the installed app to troubleshoot migration or imports. Existing library snapshots are retained for recovery.
