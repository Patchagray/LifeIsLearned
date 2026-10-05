import XCTest
import SwiftUI
import UIKit
@testable import LifeIsLearned

@MainActor final class FakeNarrator: Narrating {
    var isPlaying = false
    var isPaused = false
    var completions: [() -> Void] = []
    var lastRole: NarrationRole?
    var spokenCount = 0
    func speak(_ text: String, role: NarrationRole, settings: PlaybackSettings, finished: (() -> Void)?) {
        isPlaying = true; isPaused = false; lastRole = role; spokenCount += 1
        if let finished { completions.append(finished) }
    }
    func pause() { isPlaying = false; isPaused = true }
    func resume() { isPlaying = true; isPaused = false }
    func stop() { isPlaying = false; isPaused = false }
    func finish() { isPlaying = false; completions.removeFirst()() }
}

final class LessonSessionTests: XCTestCase {
    @MainActor private func fixture(practiceOnly: Bool = false) async throws -> (LessonSession, FakeNarrator, LibraryStore, URL, UserDefaults) {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "starter", withExtension: "json"))
        let package = try JSONDecoder().decode(LessonPackage.self, from: Data(contentsOf: url)).validated()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "LifeIsLearnedTests." + UUID().uuidString))
        let store = LibraryStore(documentsURL: directory, defaults: defaults, initialPackage: package)
        await store.ready()
        addTeardownBlock { await store.flush(); try? FileManager.default.removeItem(at: directory) }
        let narrator = FakeNarrator()
        let settings = PlaybackSettings(defaults: defaults)
        settings.pagePause = 0
        let session = LessonSession(book: package.book, lesson: package.book.lessons[0], store: store,
                                    speech: narrator, settings: settings, practiceOnly: practiceOnly)
        return (session, narrator, store, directory, defaults)
    }
    @MainActor func testAutomaticPlaybackChangesVoiceAfterIntro() async throws {
        let (session, narrator, _, _, _) = try await fixture()
        defer { session.stop() }
        session.togglePlayback()
        XCTAssertEqual(narrator.lastRole, .guide)
        narrator.finish()
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(session.index, 1)
        XCTAssertEqual(narrator.lastRole, .storyteller)
    }
    @MainActor func testPauseResumePreservesAutomaticProgression() async throws {
        let (session, narrator, _, _, _) = try await fixture()
        defer { session.stop() }
        session.togglePlayback(); session.togglePlayback()
        XCTAssertTrue(narrator.isPaused)
        session.togglePlayback(); narrator.finish()
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(session.index, 1)
    }
    @MainActor func testOldFinishCannotAdvanceAfterManualNavigation() async throws {
        let (session, narrator, _, _, _) = try await fixture()
        defer { session.stop() }
        session.togglePlayback()
        let staleFinish = try XCTUnwrap(narrator.completions.first)
        session.changePage(3, keepPlaying: false)
        staleFinish()
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(session.index, 3)
        XCTAssertFalse(session.autoRunning)
        XCTAssertFalse(narrator.isPlaying)
    }
    @MainActor func testTakeawayNeverAutomaticallyStartsQuiz() async throws {
        let (session, narrator, _, _, _) = try await fixture()
        defer { session.stop() }
        session.changePage(session.lesson.pages.count - 1, keepPlaying: false)
        session.togglePlayback(); narrator.finish()
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(session.phase, .reading)
        XCTAssertTrue(session.takeawayRevealed)
        XCTAssertFalse(session.autoRunning)
    }
    @MainActor func testWrongAnswerAndRetryDoNotCountAsFirstTrySuccess() async throws {
        let (session, _, store, _, _) = try await fixture(practiceOnly: true)
        defer { session.stop() }
        let wrong = try XCTUnwrap(session.question.choices.first { $0.id != session.question.correctChoiceID })
        session.answer(wrong.id)
        session.nextQuestion()
        XCTAssertEqual(session.questionIndex, 0)
        session.retry(); session.answer(session.question.correctChoiceID); session.nextQuestion()
        session.answer(session.question.correctChoiceID); session.nextQuestion()
        XCTAssertEqual(session.phase, .complete)
        let state = store.status(book: session.book, lesson: session.lesson)
        XCTAssertEqual(state.firstTryCorrect, 1)
        XCTAssertTrue(state.needsReview)
        // Practice-only mode must not manufacture a reading completion.
        XCTAssertFalse(state.readComplete)
    }
    @MainActor func testProgressSurvivesStoreReload() async throws {
        let (session, _, store, directory, defaults) = try await fixture()
        defer { session.stop() }
        session.changePage(2, keepPlaying: false)
        let package = try XCTUnwrap(store.package(for: session.book))
        await store.flush()
        let restored = LibraryStore(documentsURL: directory, defaults: defaults, initialPackage: package)
        await restored.ready()
        XCTAssertEqual(restored.status(book: session.book, lesson: session.lesson).pageIndex, 2)
        XCTAssertNil(store.errorMessage)
    }
    @MainActor func testInvalidImportLeavesExistingBookUntouched() async throws {
        let (session, _, store, directory, _) = try await fixture()
        defer { session.stop() }
        let invalid = directory.appendingPathComponent("invalid.json")
        try Data("{\"formatVersion\":99}".utf8).write(to: invalid)
        await store.prepareImport(from: invalid)
        XCTAssertNotNil(store.errorMessage)
        XCTAssertEqual(store.books.count, 1)
        XCTAssertEqual(store.books[0].id, session.book.id)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("imported-books.json").path))
    }
    @MainActor func testValidatorRejectsUnknownSourceAndInvalidAnswerKey() async throws {
        let (session, _, _, _, _) = try await fixture()
        defer { session.stop() }
        let data = try Data(contentsOf: XCTUnwrap(Bundle.main.url(forResource: "starter", withExtension: "json")))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var book = try XCTUnwrap(object["book"] as? [String: Any])
        var lessons = try XCTUnwrap(book["lessons"] as? [[String: Any]])
        var pages = try XCTUnwrap(lessons[0]["pages"] as? [[String: Any]])
        pages[0]["sourceIDs"] = ["missing"]
        lessons[0]["pages"] = pages; book["lessons"] = lessons; object["book"] = book
        let badSource = try JSONDecoder().decode(LessonPackage.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertThrowsError(try badSource.validated())
        pages[0]["sourceIDs"] = ["book"]
        lessons[0]["pages"] = pages
        var questions = try XCTUnwrap(lessons[0]["questions"] as? [[String: Any]])
        questions[0]["correctChoiceID"] = "missing"
        lessons[0]["questions"] = questions; book["lessons"] = lessons; object["book"] = book
        let badAnswer = try JSONDecoder().decode(LessonPackage.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertThrowsError(try badAnswer.validated())
    }
}


final class NarrationScrollingTests: XCTestCase {
    func testSpeechRangeAccountsForUnicodeTitleAndRejectsStaleOrInvalidRanges() {
        let title = "A 🧠 idea"
        let body = "Read café, then 👋 and continue."
        let utterance = title + ". " + body
        let word = (utterance as NSString).range(of: "continue")
        XCTAssertEqual(NarrationText.bodyRange(text: body, title: title, spokenText: utterance, spokenRange: word),
                       (body as NSString).range(of: "continue"))
        XCTAssertNil(NarrationText.bodyRange(text: body, title: title, spokenText: utterance,
                                           spokenRange: NSRange(location: 0, length: 1)))
        XCTAssertNil(NarrationText.bodyRange(text: body, title: title, spokenText: "old page", spokenRange: word))
        XCTAssertNil(NarrationText.bodyRange(text: body, title: title, spokenText: utterance,
                                           spokenRange: NSRange(location: 500, length: 10)))
        XCTAssertNil(NarrationText.bodyRange(text: body, title: title, spokenText: utterance, spokenRange: nil))
    }

    @MainActor func testRenderedTextScrollsOnlyWhenNeededAndHandlesPauseAndReplay() throws {
        // Exercise real TextKit geometry in phone portrait, landscape, and iPad
        // viewports, including an accessibility-sized font.
        for (size, fontSize) in [(CGSize(width: 390, height: 600), 20.0),
                                 (CGSize(width: 750, height: 240), 20.0),
                                 (CGSize(width: 820, height: 850), 48.0)] {
            let window = UIWindow(frame: CGRect(origin: .zero, size: size))
            let controller = UIViewController()
            window.rootViewController = controller
            window.makeKeyAndVisible()
            defer { window.isHidden = true }
            let scroll = UIScrollView(frame: CGRect(origin: .zero, size: size))
            scroll.contentInsetAdjustmentBehavior = .never
            scroll.contentInset = UIEdgeInsets(top: 12, left: 0, bottom: 20, right: 0)
            controller.view.addSubview(scroll)
            let textView = NarrationTextView()
            scroll.addSubview(textView)
            let text = String(repeating: "A thoughtful reader follows the explanation one line at a time. ", count: 40) + "Finish."
            func configure(_ range: NSRange?, playing: Bool = true) {
                textView.configure(text: text, fontSize: fontSize, range: range, following: playing, reduceMotion: true)
                textView.layoutIfNeeded()
                textView.followSpokenLine()
            }
            configure(nil, playing: false)
            let width = min(680, size.width) - 48
            let height = textView.sizeThatFits(CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)).height
            textView.frame = CGRect(x: 24, y: min(160, size.height * 0.25), width: width, height: height)
            scroll.contentSize = CGSize(width: size.width, height: height + 450)
            textView.layoutIfNeeded()
            scroll.contentOffset.y = -scroll.contentInset.top
            let initialOffset = scroll.contentOffset.y
            configure(NSRange(location: 0, length: 1))
            XCTAssertEqual(scroll.contentOffset.y, initialOffset, "Visible first line should not move")
            let end = (text as NSString).range(of: "Finish")
            configure(end, playing: false)
            XCTAssertEqual(scroll.contentOffset.y, initialOffset, "Paused narration should not scroll")
            let plainHeight = textView.sizeThatFits(CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)).height
            configure(end)
            XCTAssertEqual(textView.sizeThatFits(CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)).height, plainHeight,
                           "Spoken emphasis must not change text wrapping or hide the final line")
            XCTAssertGreaterThan(scroll.contentOffset.y, 0)
            let glyphs = textView.layoutManager.glyphRange(forCharacterRange: end, actualCharacterRange: nil)
            let line = textView.layoutManager.lineFragmentRect(forGlyphAt: glyphs.location, effectiveRange: nil)
            let visibleLine = textView.convert(line, to: scroll)
            XCTAssertGreaterThanOrEqual(visibleLine.minY, scroll.bounds.minY + scroll.contentInset.top)
            XCTAssertLessThanOrEqual(visibleLine.maxY, scroll.bounds.maxY - scroll.contentInset.bottom)
            let offset = scroll.contentOffset
            configure(end)
            XCTAssertEqual(scroll.contentOffset, offset, "A visible line should stay still")
            configure(NSRange(location: 0, length: 1))
            XCTAssertLessThan(scroll.contentOffset.y, offset.y, "Replay should bring the first line back")
        }
    }

    @MainActor func testSwiftUIReaderIntegrationWrapsAndFollowsAtLargeTextSize() async throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "starter", withExtension: "json"))
        let package = try JSONDecoder().decode(LessonPackage.self, from: Data(contentsOf: url)).validated()
        let lesson = package.book.lessons[0]
        let pageIndex = 2
        let text = lesson.pages[pageIndex].text
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let suite = "NarrationScrollingTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = LibraryStore(documentsURL: directory, defaults: defaults, initialPackage: package)
        await store.ready()
        store.update(book: package.book, lesson: lesson) { $0.pageIndex = pageIndex }
        let settings = PlaybackSettings(defaults: defaults)
        let content = ReaderView(book: package.book, lesson: lesson, store: store,
                                 speech: SpeechPlayer(), settings: settings)
            .environment(\.dynamicTypeSize, .accessibility3)
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: isPad ? 820 : 390, height: isPad ? 1180 : 844))
        let host = UIHostingController(rootView: content)
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        host.view.layoutIfNeeded()
        try await Task.sleep(nanoseconds: 100_000_000)
        host.view.layoutIfNeeded()
        func findText(_ view: UIView) -> NarrationTextView? {
            (view as? NarrationTextView) ?? view.subviews.lazy.compactMap { findText($0) }.first
        }
        let textView = try XCTUnwrap(findText(host.view))
        XCTAssertGreaterThan(textView.bounds.height, 700, "SwiftUI must give wrapping text its full height")
        let font = try XCTUnwrap(textView.attributedText.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)
        XCTAssertGreaterThan(font.pointSize, 20, "Dynamic Type must scale the font")
        func snapshot(_ name: String) {
            let image = UIGraphicsImageRenderer(bounds: host.view.bounds).image { _ in
                host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
            }
            let attachment = XCTAttachment(image: image)
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        snapshot("Simulator-reader-large-text-before")
        let lastWord = String(try XCTUnwrap(text.split { $0.isWhitespace }.last))
            .trimmingCharacters(in: .punctuationCharacters)
        let finalWord = (text as NSString).range(of: lastWord, options: .backwards)
        var ancestor = textView.superview
        while let view = ancestor, !(view is UIScrollView) { ancestor = view.superview }
        let scroll = try XCTUnwrap(ancestor as? UIScrollView)
        let initialOffset = scroll.contentOffset
        textView.configure(text: text, fontSize: font.pointSize, range: finalWord,
                           following: true, reduceMotion: true)
        textView.configure(text: text, fontSize: font.pointSize, range: nil,
                           following: false, reduceMotion: true)
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(scroll.contentOffset, initialOffset, "Stopping must cancel an already queued scroll")
        textView.configure(text: text, fontSize: font.pointSize, range: finalWord,
                           following: true, reduceMotion: true)
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertGreaterThan(scroll.contentOffset.y, initialOffset.y, "Narration must move SwiftUI's outer scroll view")
        let glyphs = textView.layoutManager.glyphRange(forCharacterRange: finalWord, actualCharacterRange: nil)
        let line = textView.layoutManager.lineFragmentRect(forGlyphAt: glyphs.location, effectiveRange: nil)
        let rect = textView.convert(line, to: scroll)
        XCTAssertGreaterThanOrEqual(rect.minY, scroll.bounds.minY)
        XCTAssertLessThanOrEqual(rect.maxY, scroll.bounds.maxY)
        snapshot("Simulator-reader-large-text-after")
    }
}
