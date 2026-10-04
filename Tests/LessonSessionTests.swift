import XCTest
@testable import LifeIsLearned

@MainActor private final class FakeNarrator: Narrating {
    var isPlaying = false
    var isPaused = false
    var completions: [() -> Void] = []
    var lastRole: NarrationRole?
    func speak(_ text: String, role: NarrationRole, settings: PlaybackSettings, finished: (() -> Void)?) {
        isPlaying = true; isPaused = false; lastRole = role
        if let finished { completions.append(finished) }
    }
    func pause() { isPlaying = false; isPaused = true }
    func resume() { isPlaying = true; isPaused = false }
    func stop() { isPlaying = false; isPaused = false }
    func finish() { isPlaying = false; completions.removeFirst()() }
}

final class LessonSessionTests: XCTestCase {
    @MainActor private func fixture(practiceOnly: Bool = false) throws -> (LessonSession, FakeNarrator, LibraryStore, URL, UserDefaults) {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "starter", withExtension: "json"))
        let package = try JSONDecoder().decode(LessonPackage.self, from: Data(contentsOf: url)).validated()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "LifeIsLearnedTests." + UUID().uuidString))
        let store = LibraryStore(documentsURL: directory, defaults: defaults, initialPackage: package)
        let narrator = FakeNarrator()
        let settings = PlaybackSettings(defaults: defaults)
        settings.pagePause = 0
        let session = LessonSession(book: package.book, lesson: package.book.lessons[0], store: store,
                                    speech: narrator, settings: settings, practiceOnly: practiceOnly)
        return (session, narrator, store, directory, defaults)
    }
    @MainActor func testAutomaticPlaybackChangesVoiceAfterIntro() async throws {
        let (session, narrator, _, directory, _) = try fixture()
        defer { session.stop(); try? FileManager.default.removeItem(at: directory) }
        session.togglePlayback()
        XCTAssertEqual(narrator.lastRole, .guide)
        narrator.finish()
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(session.index, 1)
        XCTAssertEqual(narrator.lastRole, .storyteller)
    }
    @MainActor func testPauseResumePreservesAutomaticProgression() async throws {
        let (session, narrator, _, directory, _) = try fixture()
        defer { session.stop(); try? FileManager.default.removeItem(at: directory) }
        session.togglePlayback(); session.togglePlayback()
        XCTAssertTrue(narrator.isPaused)
        session.togglePlayback(); narrator.finish()
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(session.index, 1)
    }
    @MainActor func testOldFinishCannotAdvanceAfterManualNavigation() async throws {
        let (session, narrator, _, directory, _) = try fixture()
        defer { session.stop(); try? FileManager.default.removeItem(at: directory) }
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
        let (session, narrator, _, directory, _) = try fixture()
        defer { session.stop(); try? FileManager.default.removeItem(at: directory) }
        session.changePage(session.lesson.pages.count - 1, keepPlaying: false)
        session.togglePlayback(); narrator.finish()
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(session.phase, .reading)
        XCTAssertTrue(session.takeawayRevealed)
        XCTAssertFalse(session.autoRunning)
    }
    @MainActor func testWrongAnswerAndRetryDoNotCountAsFirstTrySuccess() throws {
        let (session, _, store, directory, _) = try fixture(practiceOnly: true)
        defer { session.stop(); try? FileManager.default.removeItem(at: directory) }
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
    @MainActor func testProgressSurvivesStoreReload() throws {
        let (session, _, store, directory, defaults) = try fixture()
        defer { session.stop(); try? FileManager.default.removeItem(at: directory) }
        session.changePage(2, keepPlaying: false)
        let package = LessonPackage(formatVersion: 1, book: session.book)
        let restored = LibraryStore(documentsURL: directory, defaults: defaults, initialPackage: package)
        XCTAssertEqual(restored.status(book: session.book, lesson: session.lesson).pageIndex, 2)
        XCTAssertNil(store.errorMessage)
    }
    @MainActor func testInvalidImportLeavesExistingBookUntouched() throws {
        let (session, _, store, directory, _) = try fixture()
        defer { session.stop(); try? FileManager.default.removeItem(at: directory) }
        let invalid = directory.appendingPathComponent("invalid.json")
        try Data("{\"formatVersion\":99}".utf8).write(to: invalid)
        store.importPackage(from: invalid)
        XCTAssertNotNil(store.errorMessage)
        XCTAssertEqual(store.books.count, 1)
        XCTAssertEqual(store.books[0].id, session.book.id)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("imported-books.json").path))
    }
    @MainActor func testValidatorRejectsUnknownSourceAndInvalidAnswerKey() throws {
        let (session, _, _, directory, _) = try fixture()
        defer { session.stop(); try? FileManager.default.removeItem(at: directory) }
        let data = try JSONEncoder().encode(LessonPackage(formatVersion: 1, book: session.book))
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
