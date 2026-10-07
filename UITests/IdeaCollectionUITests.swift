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
        carousel.swipeLeft(); carousel.swipeRight()
        XCTAssertTrue(first.exists)
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
