import XCTest

/// Exercises the actual app and native navigation on a simulator. Its isolated
/// document directory/defaults are selected only in Debug with a random test UUID.
final class LearningJourneyUITests: XCTestCase {
    func testBookReadingRetryResumeAndCompletionJourney() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["LIL_UI_TEST_RUN_ID"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(app.buttons["continue-learning"].waitForExistence(timeout: 15))
        let book = app.buttons["book-influential-mind"]
        reveal(book, in: app)
        book.tap()
        let idea = app.buttons["idea-priors"]
        reveal(idea, in: app)
        idea.tap()
        try exerciseJourney(app, pageCount: 8)
    }

    func testFirstStartShowsSelectionAndDurationHelp() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["LIL_UI_TEST_RUN_ID"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(app.buttons["continue-learning"].waitForExistence(timeout: 15))
        app.buttons["continue-learning"].tap()
        let preface = app.staticTexts["collection-preface"]
        XCTAssertTrue(preface.waitForExistence(timeout: 5))
        XCTAssertTrue(preface.label.contains("1 selected idea"))
        XCTAssertFalse(app.buttons["Next screen"].exists)
        snapshot(app, "handoff003-selection-preface")
        let help = app.buttons["About idea durations"]
        reveal(help, in: app); help.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Approximate whole-idea time includes narration")).firstMatch.exists)
        snapshot(app, "handoff003-duration-help")
    }

    /// Fixture is placed in this simulator's Files provider before the run.
    /// This uses the actual system picker, preview, confirmation and persisted library.
    func testManualFilesImportOfShortDemoAndJourney() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["LIL_UI_TEST_RUN_ID"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(app.buttons["Import book"].waitForExistence(timeout: 15))
        app.buttons["Import book"].tap()
        let browse = app.buttons["Browse"].firstMatch
        let local = app.staticTexts.matching(NSPredicate(format: "label IN %@", ["On My iPhone", "On My iPad"])).firstMatch
        let file = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "Handoff003-ShortDemo")).firstMatch
        // A newly booted simulator may start the remote Files provider slowly.
        // Wait for its controls before deciding which navigation path is visible.
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            browse.exists || local.exists || file.exists
        }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 60), .completed)
        if browse.exists { browse.tap() }
        if !file.exists && local.waitForExistence(timeout: 20) { local.tap() }
        if !file.waitForExistence(timeout: 30) { print("FILES_PICKER_TREE " + app.debugDescription) }
        XCTAssertTrue(file.exists, "Place Handoff003-ShortDemo.json in the simulator Files provider before this acceptance test.")
        snapshot(app, "handoff003-manual-files-picker")
        file.tap()
        let confirm = app.buttons["Import complete update"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 20))
        snapshot(app, "handoff003-short-demo-update-review")
        reveal(confirm, in: app); confirm.tap()
        let open = app.buttons["Open book"]
        XCTAssertTrue(open.waitForExistence(timeout: 20)); open.tap()
        let idea = app.buttons["idea-priors"]
        reveal(idea, in: app)
        XCTAssertTrue(idea.label.contains("About 5 min"))
        XCTAssertTrue(idea.label.contains("Updated"))
        snapshot(app, "handoff003-short-demo-ready")
        idea.tap()
        try exerciseJourney(app, pageCount: 6)
    }

    private func exerciseJourney(_ app: XCUIApplication, pageCount: Int) throws {
        XCTAssertTrue(app.buttons["Next screen"].waitForExistence(timeout: 5))
        app.buttons["Next screen"].tap()
        XCTAssertTrue(app.staticTexts["Before the report"].waitForExistence(timeout: 5))
        snapshot(app, "live-simulator-reader")
        XCUIDevice.shared.orientation = .landscapeLeft
        waitForOrientation(landscape: true, in: app)
        XCTAssertTrue(app.buttons["Next screen"].isHittable)
        snapshot(app, "live-simulator-reader-landscape")
        XCUIDevice.shared.orientation = .portrait
        waitForOrientation(landscape: false, in: app)
        app.buttons["Previous screen"].tap()
        for _ in 0..<(pageCount - 1) { app.buttons["Next screen"].tap() }
        let revealCard = app.buttons["Reveal the idea"]
        reveal(revealCard, in: app); revealCard.tap()
        let practice = app.buttons["Practice this idea"]
        XCTAssertTrue(practice.isEnabled); practice.tap()
        let wrong = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Option 2.")).firstMatch
        reveal(wrong, in: app); wrong.tap()
        XCTAssertTrue(app.buttons["Try again"].waitForExistence(timeout: 5))
        snapshot(app, "live-simulator-incorrect-feedback")
        // Relaunch the same isolated installation while feedback is selected.
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["continue-learning"].waitForExistence(timeout: 15))
        app.buttons["continue-learning"].tap()
        XCTAssertTrue(app.buttons["Try again"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Read question or feedback"].exists)
        app.buttons["Try again"].tap()
        let correct = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Option 1.")).firstMatch
        reveal(correct, in: app); correct.tap()
        app.buttons["Continue"].tap()
        let second = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Option 3.")).firstMatch
        reveal(second, in: app); second.tap()
        app.buttons["Finish lesson"].tap()
        XCTAssertTrue(app.staticTexts["1 of 2 correct on the first try."].waitForExistence(timeout: 5))
        snapshot(app, "live-simulator-completion")
        app.buttons["Continue book"].tap()
        XCTAssertTrue(app.staticTexts["book-detail-title"].waitForExistence(timeout: 5))
        let completedIdea = app.buttons["idea-priors"]
        reveal(completedIdea, in: app)
        XCTAssertTrue(completedIdea.label.contains("Practiced"), "Completion returns to the book's achieved progress")
    }
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<10 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.exists && element.isHittable, "Expected a visible control: \(element)")
    }
    private func snapshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func waitForOrientation(landscape: Bool, in app: XCUIApplication) {
        // Capture the screen rather than an app element's portrait-coordinate crop.
        // A hittable button alone does not mean the system rotation has finished.
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let size = XCUIScreen.main.screenshot().image.size
            return landscape ? size.width > size.height : size.height > size.width
        }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 8), .completed)
    }
}
