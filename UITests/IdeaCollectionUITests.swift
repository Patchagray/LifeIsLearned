import XCTest
import UIKit

final class IdeaCollectionUITests: XCTestCase {
    private func launch(fixture: Bool = true, largeText: Bool = false) -> XCUIApplication {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchEnvironment["LIL_UI_TEST_RUN_ID"] = UUID().uuidString
        if fixture { app.launchEnvironment["LIL_IDEA_CARD_FIXTURE"] = "1" }
        if largeText { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        XCTAssertTrue(app.buttons["Ideas"].waitForExistence(timeout: 20))
        return app
    }
    func testEmptyCollectionAndEmptyFavorites() {
        let app = launch(fixture: false)
        app.buttons["Ideas"].tap()
        XCTAssertTrue(app.staticTexts["Finish an idea to collect your first card."].waitForExistence(timeout: 5))
        snapshot("h004-live-empty")
        app.buttons["Favorites"].tap()
        XCTAssertTrue(app.staticTexts["Star an idea you want to keep close."].exists)
        snapshot("h004-live-empty-favorites")
    }
    func testTwentyCardsGridCarouselFlipFavoriteRelaunchAndReview() {
        let app = launch()
        app.buttons["Ideas"].tap()
        let count = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '20 collected'")).firstMatch
        XCTAssertTrue(count.waitForExistence(timeout: 30))
        snapshot("h004-live-grid-20")
        let grid = app.scrollViews["ideas-scroll"]
        for _ in 0..<5 { grid.swipeUp() }
        snapshot("h004-live-grid-bottom")
        for _ in 0..<6 { grid.swipeDown() }
        app.buttons["Show carousel"].tap()
        let cards = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'card-'"))
        // The newest card is index 9: Return to what matters.
        let first = cards.matching(NSPredicate(format: "label BEGINSWITH 'Return to what matters'")).firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        XCTAssertEqual(first.value as? String, "Front")
        XCTAssertEqual(first.frame.midX, app.frame.midX, accuracy: 3)
        snapshot("h004-live-carousel-front")
        first.tap()
        waitForFace(first, "Details")
        Thread.sleep(forTimeInterval: 0.6) // Let the 0.4-second flip settle before recording its face.
        snapshot("h004-live-carousel-back")
        first.tap()
        // The star is an independent 44-point control; favoriting must not flip.
        app.buttons["favorite-14:card-fixture-b6:card-9"].tap()
        XCTAssertTrue(first.label.contains("Not a favorite")); XCTAssertEqual(first.value as? String, "Front")
        app.buttons["favorite-14:card-fixture-b6:card-9"].tap()
        XCTAssertFalse(first.label.contains("Not a favorite")); XCTAssertEqual(first.value as? String, "Front")
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["Ideas"].waitForExistence(timeout: 20)); app.buttons["Ideas"].tap()
        app.buttons["Favorites"].tap(); app.buttons["Show carousel"].tap()
        XCTAssertTrue(first.waitForExistence(timeout: 5)); XCTAssertFalse(first.label.contains("Not a favorite"))
        let carousel = app.scrollViews["idea-carousel"]
        carousel.swipeLeft(velocity: .slow)
        XCTAssertGreaterThan(abs(first.frame.midX - app.frame.midX), 20, "Manual scrolling must leave the first card")
        XCTAssertFalse(app.staticTexts["1 of 7"].exists, "The selected-card footer follows the centered card")
        carousel.swipeRight(velocity: .slow)
        XCTAssertTrue(first.exists)
        XCTAssertEqual(first.frame.midX, app.frame.midX, accuracy: 3)
        XCTAssertTrue(app.staticTexts["1 of 7"].exists)
        first.tap()
        waitForFace(first, "Details")
        Thread.sleep(forTimeInterval: 0.6)
        snapshot("h004-live-favorites-back")
        // The card intentionally exposes one coherent accessibility element with
        // a named Review action. Exercise the separate visual Review button at
        // its observed fixture position (normal text, two-line application).
        first.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 110, dy: 338)).tap()
        XCTAssertTrue(app.buttons["Close lesson"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Play narration"].exists)
        app.buttons["Close lesson"].tap()
    }
    func testFilterSortAndAccessibleGridOrder() {
        let app = launch()
        app.buttons["Ideas"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '20 collected'")).firstMatch.waitForExistence(timeout: 30))
        let cards = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'card-'"))
        XCTAssertGreaterThanOrEqual(cards.count, 3, "The lazy grid exposes realized cards")
        XCTAssertTrue(cards.element(boundBy: 0).label.hasPrefix("Return to what matters"))
        XCTAssertTrue(cards.element(boundBy: 1).label.hasPrefix("Consider the context"))
        XCTAssertTrue(cards.element(boundBy: 2).label.hasPrefix("Let evidence change your mind"))
        app.buttons["Favorites"].tap()
        XCTAssertGreaterThanOrEqual(cards.count, 3)
        XCTAssertFalse(cards.allElementsBoundByIndex.contains { $0.label.contains("Not a favorite") })
        app.buttons["All"].tap()
        app.buttons["Filter and sort ideas"].tap()
        app.buttons["Alphabetical"].tap()
        XCTAssertTrue(cards.element(boundBy: 0).label.hasPrefix("Consider the context"))
        app.buttons["Filter and sort ideas"].tap()
        app.buttons["The Art of Paying Attention"].tap()
        XCTAssertGreaterThanOrEqual(cards.count, 3)
        XCTAssertTrue(cards.allElementsBoundByIndex.allSatisfy { $0.label.contains("The Art of Paying Attention") })
        snapshot("h004-live-book-filter-alphabetical")
        // Opening a specific grid card must focus that same semantic identity.
        let selectedID = cards.element(boundBy: 0).identifier
        cards.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["Show grid"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons[selectedID].value as? String, "Front")
        XCTAssertEqual(app.buttons[selectedID].frame.midX, app.frame.midX, accuracy: 3)
    }
    func testAccessibilityTextUsesOneColumnAndReadableCarousel() {
        let app = launch(largeText: true)
        app.buttons["Ideas"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '20 collected'")).firstMatch.waitForExistence(timeout: 30))
        let cards = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'card-'"))
        XCTAssertGreaterThanOrEqual(cards.count, 1)
        let columnX = cards.element(boundBy: 0).frame.minX
        XCTAssertGreaterThan(cards.element(boundBy: 0).frame.width, app.frame.width * 0.7)
        let second = app.buttons["card-14:card-fixture-b6:card-8"]
        // A full-text accessibility card can exceed the viewport. Realize the next
        // lazy card before comparing columns instead of requiring offscreen views.
        for _ in 0..<8 {
            if second.exists { break }
            app.scrollViews["ideas-scroll"].swipeUp()
        }
        XCTAssertTrue(second.exists)
        XCTAssertEqual(columnX, second.frame.minX, accuracy: 1)
        snapshot("h004-live-accessibility-grid")
        app.buttons["Show carousel"].tap()
        let first = app.buttons["card-14:card-fixture-b6:card-9"]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        XCTAssertEqual(first.frame.midX, app.frame.midX, accuracy: 3)
        snapshot("h004-live-accessibility-carousel")
    }
    func testVisibleFavoriteShimmersWhileUnfavoritedCardStaysStill() throws {
        try XCTSkipIf(UIAccessibility.isReduceMotionEnabled, "The separate Reduce Motion test requires a static favorite.")
        let app = launch()
        app.buttons["Ideas"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '20 collected'")).firstMatch.waitForExistence(timeout: 30))
        let favorite = app.buttons["card-14:card-fixture-b6:card-9"]
        let ordinary = app.buttons["card-14:card-fixture-b6:card-8"]
        Thread.sleep(forTimeInterval: 1)
        let favoriteBefore = favorite.screenshot().pngRepresentation
        let ordinaryBefore = ordinary.screenshot().pngRepresentation
        Thread.sleep(forTimeInterval: 1)
        XCTAssertNotEqual(favoriteBefore, favorite.screenshot().pngRepresentation, "Visible grid favorites have an active perimeter")
        XCTAssertEqual(ordinaryBefore, ordinary.screenshot().pngRepresentation, "Ordinary grid cards remain still")
        app.buttons["Show carousel"].tap()
        Thread.sleep(forTimeInterval: 1)
        let carouselBefore = favorite.screenshot().pngRepresentation
        Thread.sleep(forTimeInterval: 1)
        XCTAssertNotEqual(carouselBefore, favorite.screenshot().pngRepresentation, "Visible carousel favorites also shimmer")
        snapshot("h004-live-favorite-active")
    }
    func testSystemReduceMotionStaticFavoriteAndFlip() throws {
        try XCTSkipUnless(UIAccessibility.isReduceMotionEnabled, "Dedicated run requires the simulator's actual Reduce Motion setting enabled.")
        let app = launch()
        app.buttons["Ideas"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '20 collected'")).firstMatch.waitForExistence(timeout: 30))
        app.buttons["Show carousel"].tap()
        let card = app.buttons["card-14:card-fixture-b6:card-9"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        let before = card.screenshot().pngRepresentation
        Thread.sleep(forTimeInterval: 1)
        XCTAssertEqual(before, card.screenshot().pngRepresentation, "A visible favorite stays static with system Reduce Motion")
        snapshot("h004-live-reduce-motion-front")
        card.tap()
        waitForFace(card, "Details")
        snapshot("h004-live-reduce-motion-back")
    }
    func testCompletionGoesDirectlyToSavedNextIdea() {
        let app = launch()
        let book = app.buttons["book-card-fixture-a"]
        reveal(book, app); book.tap()
        let firstIdea = app.buttons["idea-card-0"]
        reveal(firstIdea, app); firstIdea.tap()
        let wrong = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Option 2.'")).firstMatch
        reveal(wrong, app); wrong.tap()
        app.buttons["Try again"].tap()
        let correct = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Option 1.'")).firstMatch
        reveal(correct, app); correct.tap(); app.buttons["Continue"].tap()
        let second = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Option 3.'")).firstMatch
        reveal(second, app); second.tap(); app.buttons["Finish lesson"].tap()
        XCTAssertTrue(app.staticTexts["1 of 2 correct on the first try."].waitForExistence(timeout: 5))
        let collected = app.buttons["View collected card"]
        reveal(collected, app); collected.tap()
        let collectedCard = app.buttons["card-14:card-fixture-a6:card-0"]
        XCTAssertTrue(collectedCard.waitForExistence(timeout: 5))
        XCTAssertEqual(collectedCard.frame.midX, app.frame.midX, accuracy: 3)
        snapshot("h004-live-collected-card")
        app.buttons["Done"].tap()
        let next = app.buttons["continue-next-idea"]
        app.swipeDown()
        reveal(next, app); snapshot("h004-live-completion-next")
        XCTAssertEqual(next.label, "Continue to next idea")
        XCTAssertTrue(app.staticTexts["Listen before deciding"].exists)
        next.tap()
        XCTAssertTrue(app.staticTexts["Listen before deciding"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["3 / 8"].exists, "Continue resumes the next idea's saved screen")
        XCTAssertTrue(app.buttons["Play narration"].exists, "No automatic playback was introduced")
        XCTAssertFalse(app.staticTexts["book-detail-title"].isHittable, "The underlying book remains covered by the next reader")
        snapshot("h004-live-next-resumed")
    }
    private func waitForFace(_ card: XCUIElement, _ face: String) {
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", face), object: card)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 3), .completed)
    }
    private func reveal(_ element: XCUIElement, _ app: XCUIApplication) {
        XCTAssertTrue(element.waitForExistence(timeout: 20))
        for _ in 0..<12 { if element.isHittable { return }; app.swipeUp() }
        XCTAssertTrue(element.isHittable)
    }
    private func snapshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}

final class SixStageReaderUITests: XCTestCase {
    func testCanonicalReaderLabelsArtworkAndPracticeBoundary() {
        let app = XCUIApplication()
        app.launchEnvironment["LIL_UI_TEST_RUN_ID"] = UUID().uuidString
        app.launchEnvironment["LIL_SIX_STAGE_FIXTURE"] = "1"
        app.launch()
        let book = app.buttons["book-six-stage-fixture"]
        reveal(book, app); book.tap()
        let idea = app.buttons["idea-six-stage-idea"]
        reveal(idea, app); idea.tap()
        let indicator = app.descendants(matching: .any)["semantic-lesson-progress"].firstMatch
        XCTAssertTrue(indicator.waitForExistence(timeout: 10))
        let labels = ["Hook", "Explanation", "Story 1 of 2", "Story 2 of 2", "Practical Application", "Takeaway"]
        for index in 0..<6 {
            XCTAssertEqual(indicator.label, "Screen \(index + 1) of 6 · " + labels[index])
            XCTAssertFalse(app.buttons["Pause narration"].exists)
            if [0, 1, 4].contains(index) {
                let artwork = app.descendants(matching: .any)["editorial-artwork"].firstMatch
                XCTAssertTrue(artwork.exists)
                XCTAssertGreaterThanOrEqual(artwork.frame.height, 180)
                XCTAssertLessThanOrEqual(artwork.frame.height, 231)
            }
            let stage = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            stage.name = "h005a-live-stage-\(index)"; stage.lifetime = .keepAlways; add(stage)
            if index == 2 {
                let secondary = app.descendants(matching: .any)["story-secondary-artwork"].firstMatch
                reveal(secondary, app)
                XCTAssertTrue(secondary.isHittable)
                let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
                image.name = "h005a-live-second-story-image"; image.lifetime = .keepAlways; add(image)
            }
            if index < 5 { app.buttons["Next screen"].tap() }
        }
        let art = app.images["takeaway-artwork"]
        XCTAssertFalse(art.exists, "The Idea Card is the production Takeaway visual")
        XCTAssertFalse(app.buttons["Practice this idea"].isEnabled)
        let revealButton = app.buttons["Reveal the idea"]
        reveal(revealButton, app); revealButton.tap()
        XCTAssertTrue(app.buttons["Practice this idea"].isEnabled)
        XCTAssertFalse(art.exists)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "h005a-live-takeaway-card"; attachment.lifetime = .keepAlways; add(attachment)
        app.buttons["Practice this idea"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Option 1.'")).firstMatch.waitForExistence(timeout: 5))
    }
    private func reveal(_ element: XCUIElement, _ app: XCUIApplication) {
        XCTAssertTrue(element.waitForExistence(timeout: 30))
        for _ in 0..<12 { if element.isHittable { return }; app.swipeUp() }
        XCTAssertTrue(element.isHittable)
    }
}

final class LibraryHistoryUITests: XCTestCase {
    func testOffloadConfirmationHistoryAndCardsSurviveRelaunch() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["LIL_UI_TEST_RUN_ID"] = UUID().uuidString
        app.launchEnvironment["LIL_IDEA_CARD_FIXTURE"] = "1"
        app.launch()
        let book = app.buttons["book-card-fixture-a"]
        reveal(book, app); book.tap()
        app.buttons["Book options"].tap()
        app.buttons["Offload Book"].tap()
        let explanation = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Idea Cards, favorites, progress and History stay'")).firstMatch
        XCTAssertTrue(explanation.waitForExistence(timeout: 5))
        XCTAssertTrue(explanation.label.contains("re-import"))
        snapshot("h005b-offload-confirmation")
        app.buttons["Offload Book"].tap()
        let history = app.buttons["library-history"]
        reveal(history, app); history.tap()
        let restore = app.buttons["restore-book-card-fixture-a"]
        reveal(restore, app)
        XCTAssertEqual(restore.label, "Re-import book")
        XCTAssertTrue(app.staticTexts["Offloaded"].exists)
        snapshot("h005b-history-offloaded")
        app.terminate()
        app.launchEnvironment.removeValue(forKey: "LIL_IDEA_CARD_FIXTURE")
        app.launch()
        XCTAssertTrue(app.buttons["Ideas"].waitForExistence(timeout: 20))
        XCTAssertFalse(app.buttons["book-card-fixture-a"].exists)
        app.buttons["Ideas"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '20 collected'")).firstMatch.waitForExistence(timeout: 10))
        snapshot("h005b-cards-after-offload")
    }
    func testHistoryAtAccessibilityTextSize() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["LIL_UI_TEST_RUN_ID"] = UUID().uuidString
        app.launchEnvironment["LIL_IDEA_CARD_FIXTURE"] = "1"
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let history = app.buttons["library-history"]
        reveal(history, app); history.tap()
        let open = app.buttons["Open book"].firstMatch
        reveal(open, app)
        XCTAssertTrue(open.isHittable)
        snapshot("h005b-history-accessibility-text")
    }
    private func reveal(_ element: XCUIElement, _ app: XCUIApplication) {
        XCTAssertTrue(element.waitForExistence(timeout: 30))
        for _ in 0..<12 { if element.isHittable { return }; app.swipeUp() }
        XCTAssertTrue(element.isHittable)
    }
    private func snapshot(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
    }
}

final class DiscoveryUITests: XCTestCase {
    func testBrowseDownloadUpdateAndOfflineCache() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["LIL_UI_TEST_RUN_ID"] = UUID().uuidString
        app.launchEnvironment["LIL_DISCOVERY_FIXTURE"] = "1"
        app.launch()
        XCTAssertTrue(app.buttons["Add Books"].waitForExistence(timeout: 25)); app.buttons["Add Books"].tap()
        app.buttons["Browse Library"].tap()
        let download = app.buttons["download-influence-the-psychology-of-persuasion"]
        XCTAssertTrue(download.waitForExistence(timeout: 20))
        snapshot("h005c-browse-synthetic")
        if !download.isHittable { app.swipeUp() }
        download.tap()
        XCTAssertTrue(app.buttons["Cancel download"].waitForExistence(timeout: 5))
        snapshot("h005c-download-progress")
        let done = app.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 20)); done.tap()
        XCTAssertTrue(app.staticTexts["In Library"].firstMatch.waitForExistence(timeout: 10))
        snapshot("h005c-in-library")
        app.buttons["Refresh catalog"].tap()
        XCTAssertTrue(app.buttons["Update"].waitForExistence(timeout: 10))
        snapshot("h005c-update-available")
        app.buttons["Update"].tap()
        XCTAssertTrue(done.waitForExistence(timeout: 20)); done.tap()
        XCTAssertTrue(app.staticTexts["In Library"].firstMatch.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Update"].exists)
        snapshot("h005c-update-installed")
        app.buttons["Refresh catalog"].tap()
        XCTAssertTrue(app.staticTexts["Showing saved catalog · refresh unavailable"].waitForExistence(timeout: 10))
        snapshot("h005c-offline-cache")
    }
    private func snapshot(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
    }
}

final class ScannerRequestUITests: XCTestCase {
    func testAddBooksAndRequestAtLargeText() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["LIL_UI_TEST_RUN_ID"] = UUID().uuidString
        app.launchEnvironment["LIL_DISCOVERY_FIXTURE"] = "1"
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["Add Books"].waitForExistence(timeout: 25)); app.buttons["Add Books"].tap()
        app.buttons["Browse Library"].tap()
        func reveal(_ element: XCUIElement) {
            for _ in 0..<16 { if element.exists && element.isHittable { return }; app.swipeUp() }
            XCTAssertTrue(element.isHittable)
        }
        let download = app.buttons["download-influence-the-psychology-of-persuasion"]
        reveal(download); snapshot("h005c-browse-large-text")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["Add Books"].tap(); app.buttons["Scan a Book"].tap()
        let title = app.textFields["scan-title"]; reveal(title); title.tap(); title.typeText("An unlisted book")
        let keyboardDone = app.buttons["scanner-keyboard-done"]
        XCTAssertTrue(keyboardDone.waitForExistence(timeout: 5)); keyboardDone.tap()
        let find = app.buttons["Find matches"]; reveal(find); find.tap()
        let review = app.buttons["Review details & request"]; reveal(review); snapshot("h005d-unknown-large-text"); review.tap()
        let requestTitle = app.textFields["request-title"]; reveal(requestTitle); requestTitle.tap(); requestTitle.typeText(" revised")
        let requestDone = app.buttons["request-keyboard-done"]
        XCTAssertTrue(requestDone.waitForExistence(timeout: 5)); requestDone.tap()
        let send = app.buttons["Request this book"]; reveal(send); snapshot("h005d-request-large-text"); send.tap()
        XCTAssertTrue(app.staticTexts["request-success"].waitForExistence(timeout: 10))
    }

    func testISBNTextFallbackAndReviewedRequest() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["LIL_UI_TEST_RUN_ID"] = UUID().uuidString
        app.launchEnvironment["LIL_DISCOVERY_FIXTURE"] = "1"
        app.launch()
        XCTAssertTrue(app.buttons["Add Books"].waitForExistence(timeout: 25)); app.buttons["Add Books"].tap()
        app.buttons["Scan a Book"].tap()
        XCTAssertTrue(app.buttons["Open camera"].waitForExistence(timeout: 10)); app.buttons["Open camera"].tap()
        XCTAssertTrue(app.staticTexts["scanner-fallback"].waitForExistence(timeout: 5))
        snapshot("h005d-camera-unavailable-text-fallback")
        let isbn = app.textFields["scan-isbn"]
        isbn.tap(); isbn.typeText("9780141033570")
        let keyboardDone = app.buttons["scanner-keyboard-done"]
        XCTAssertTrue(keyboardDone.waitForExistence(timeout: 5)); keyboardDone.tap()
        app.buttons["Find matches"].tap()
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["Exact ISBN match"].waitForExistence(timeout: 10))
        snapshot("h005d-isbn-match-synthetic")
        app.buttons["View prepared book"].tap()
        XCTAssertTrue(app.buttons["download-influence-the-psychology-of-persuasion"].waitForExistence(timeout: 15), "A stable-ID match must survive a different catalog display title")
        snapshot("h005d-prepared-book-from-scan")
        // A separate isolated launch verifies title recognition fallback without an ISBN.
        app.terminate(); app.launchEnvironment["LIL_UI_TEST_RUN_ID"] = UUID().uuidString; app.launch()
        XCTAssertTrue(app.buttons["Add Books"].waitForExistence(timeout: 25)); app.buttons["Add Books"].tap()
        app.buttons["Scan a Book"].tap()
        let title = app.textFields["scan-title"]
        title.tap(); title.typeText("Thinking, Fast and Slow")
        XCTAssertTrue(keyboardDone.waitForExistence(timeout: 5)); keyboardDone.tap()
        app.buttons["Find matches"].tap(); app.swipeUp()
        XCTAssertTrue(app.staticTexts["Title / author match"].firstMatch.waitForExistence(timeout: 10))
        snapshot("h005d-title-match")
        app.buttons["Request this book"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Request this book"].waitForExistence(timeout: 10))
        snapshot("h005d-review-before-request")
        app.buttons["Request this book"].tap()
        XCTAssertTrue(app.staticTexts["request-success"].waitForExistence(timeout: 10))
        snapshot("h005d-request-accepted-fixture")
    }
    private func snapshot(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
    }
}

final class DiveDeeperUITests: XCTestCase {
    private var largeText = false
    func testCompletionAndCollectedCardEntryPoints() { exerciseDeeper() }
    func testCompletionAndCollectedCardAtLargeText() { largeText = true; exerciseDeeper() }
    private func exerciseDeeper() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["LIL_UI_TEST_RUN_ID"] = UUID().uuidString
        app.launchEnvironment["LIL_DEEPER_FIXTURE"] = "1"
        if largeText { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        XCTAssertTrue(app.buttons["Add Books"].waitForExistence(timeout: 25))
        let book = app.buttons["book-deeper-fixture"]; reveal(book, app); book.tap()
        let idea = app.buttons["idea-deeper-idea"]; reveal(idea, app); idea.tap()
        XCTAssertFalse(app.buttons["completion-dive-deeper"].exists)
        let first = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Option 1.'")).firstMatch
        reveal(first, app); first.tap(); app.buttons["Continue"].tap()
        let second = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Option 3.'")).firstMatch
        reveal(second, app); second.tap(); app.buttons["Finish lesson"].tap()
        let deep = app.buttons["completion-dive-deeper"]; reveal(deep, app)
        snapshot("h005e-completion-entry"); deep.tap()
        reveal(app.staticTexts["A worked example"], app)
        snapshot("h005e-section-view")
        app.buttons["Done"].tap()
        let card = app.buttons["View collected card"]; reveal(card, app); card.tap()
        let cardDeep = app.buttons["card-dive-deeper"]; reveal(cardDeep, app)
        snapshot("h005e-card-entry"); cardDeep.tap()
        reveal(app.staticTexts["A worked example"], app)
        snapshot("h005e-from-card")
    }
    private func reveal(_ element: XCUIElement, _ app: XCUIApplication) {
        for _ in 0..<16 { if element.exists && element.isHittable { return }; app.swipeUp() }
        XCTAssertTrue(element.isHittable)
    }
    private func snapshot(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); a.name = largeText ? name + "-large-text" : name; a.lifetime = .keepAlways; add(a)
    }
}

final class BrandUITests: XCTestCase {
    func testSelectedIconOnHomeScreenLaunchesApp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchEnvironment["LIL_UI_TEST_RUN_ID"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(app.buttons["Ideas"].waitForExistence(timeout: 20))
        XCUIDevice.shared.press(.home)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let icon = springboard.icons["Life Is Learned"].firstMatch
        for _ in 0..<5 {
            if icon.exists && icon.isHittable { break }
            springboard.swipeLeft()
        }
        XCTAssertTrue(icon.waitForExistence(timeout: 5))
        XCTAssertTrue(icon.isHittable)
        // Capture the actual installed icon and label, excluding unrelated apps.
        let attachment = XCTAttachment(screenshot: icon.screenshot())
        attachment.name = "h005f-selected-icon-home-screen"
        attachment.lifetime = .keepAlways; add(attachment)
        icon.tap()
        XCTAssertTrue(app.buttons["Ideas"].waitForExistence(timeout: 10))
    }
}

final class PackagedNarrationUITests: XCTestCase {
    func testOfflineStudioModeBackgroundReturnAndFallbackSettings() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["LIL_UI_TEST_RUN_ID"] = UUID().uuidString
        app.launchEnvironment["LIL_AUDIO_FIXTURE"] = "1"
        app.launch()
        let book = app.buttons["book-audio-verification-fixture"]
        XCTAssertTrue(book.waitForExistence(timeout: 30))
        for _ in 0..<8 { if book.isHittable { break }; app.swipeUp() }
        book.tap()
        let idea = app.buttons["idea-audio-check"]
        for _ in 0..<10 { if idea.exists && idea.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(idea.isHittable); idea.tap()
        XCTAssertTrue(app.staticTexts["Studio narration · available offline"].waitForExistence(timeout: 15))
        snapshot("audio-studio-mode")
        app.buttons["Play narration"].tap()
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 4)
        app.activate()
        XCTAssertTrue(app.staticTexts["Studio narration · available offline"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Device fallback voices"].exists)
        XCTAssertFalse(app.staticTexts["Audio check 1"].exists, "Packaged auto-run should advance the reading stage while backgrounded")
        snapshot("audio-foreground-return-simulator")
        if app.buttons["Pause narration"].exists { app.buttons["Pause narration"].tap() }
        app.buttons["Playback settings"].tap()
        XCTAssertTrue(app.staticTexts["Device fallback voices"].waitForExistence(timeout: 5))
        snapshot("audio-fallback-voice-settings")
        app.buttons["Done"].tap()
        app.buttons["Close lesson"].tap()
    }
    private func snapshot(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
    }
}

/// Explicit opt-in inspection of an existing physical-device library. No fixture,
/// imports, progress interactions, reset flags or user-data screenshots are used.
final class ExistingLibraryRecoveryUITests: XCTestCase {
    func testExistingLibrarySurvivesThreeColdLaunches() throws {
        guard ProcessInfo.processInfo.environment["LIL_VERIFY_EXISTING_LIBRARY"] == "1" else {
            throw XCTSkip("Opt in only after backing up the device's existing library.")
        }
        #if targetEnvironment(simulator)
        throw XCTSkip("This inspection is for the backed-up physical-device library.")
        #else
        continueAfterFailure = false
        let app = XCUIApplication()
        for _ in 0..<3 {
            app.launchEnvironment = [:]; app.launchArguments = []; app.launch()
            let add = app.buttons["Add Books"]
            XCTAssertTrue(add.waitForExistence(timeout: 30))
            XCTAssertTrue(NSPredicate(format: "enabled == true").evaluate(with: add) ||
                XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: add)], timeout: 30) == .completed)
            XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Recovery mode:'")).firstMatch.exists)
            XCTAssertFalse(app.alerts.firstMatch.exists)
            XCTAssertTrue(app.staticTexts["2 collections"].exists)
            add.tap()
            XCTAssertTrue(app.buttons["Import File"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.buttons["Import File"].isEnabled)
            app.buttons["Cancel"].tap()
            app.terminate()
        }
        app.launch() // Leave the ordinary library open for the owner.
        XCTAssertTrue(app.buttons["Add Books"].waitForExistence(timeout: 30))
        #endif
    }
}
