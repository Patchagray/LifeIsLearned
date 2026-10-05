import XCTest
@testable import LifeIsLearned

final class ResumeTests: XCTestCase {
    @MainActor func testInterruptedRetryRestoresQuestionFeedbackAttemptAndScoreWithoutAudio() async throws {
        let f = try await CollectionFixture.make(); addTeardownBlock { await f.cleanup() }
        let settings = PlaybackSettings(defaults: f.defaults)
        let narrator = FakeNarrator(); let lesson = f.package.book.lessons[0]
        let session = LessonSession(book: f.package.book, lesson: lesson, store: f.store, speech: narrator, settings: settings, practiceOnly: true)
        session.engage()
        let wrong = try XCTUnwrap(session.question.choices.first { $0.id != session.question.correctChoiceID })
        session.answer(wrong.id)
        await f.store.flush()
        let reload = LibraryStore(documentsURL: f.directory, defaults: f.defaults, initialPackage: f.package)
        await reload.ready()
        let newNarrator = FakeNarrator()
        let restored = LessonSession(book: f.package.book, lesson: lesson, store: reload, speech: newNarrator, settings: settings, practiceOnly: false)
        XCTAssertEqual(restored.phase, .practice); XCTAssertEqual(restored.selectedID, wrong.id)
        XCTAssertTrue(restored.attempted); XCTAssertEqual(restored.choice?.feedback, wrong.feedback)
        XCTAssertEqual(newNarrator.spokenCount, 0)
        restored.retry(); restored.answer(restored.question.correctChoiceID); restored.nextQuestion()
        XCTAssertEqual(restored.questionIndex, 1); XCTAssertEqual(restored.firstTryCorrect, 0)
        await reload.flush()
        let second = LessonSession(book: f.package.book, lesson: lesson, store: reload, speech: newNarrator, settings: settings, practiceOnly: false)
        XCTAssertEqual(second.questionIndex, 1); XCTAssertEqual(second.firstTryCorrect, 0)
        second.answer(second.question.correctChoiceID); second.nextQuestion()
        XCTAssertEqual(second.firstTryCorrect, 1); XCTAssertEqual(second.phase, .complete)
        await reload.flush()
        session.stop(); restored.stop(); second.stop()
    }

    @MainActor func testPauseDuringReflectionResumesNextScreenWithoutReplaying() async throws {
        let f = try await CollectionFixture.make(); addTeardownBlock { await f.cleanup() }
        let settings = PlaybackSettings(defaults: f.defaults); settings.pagePause = 0.25
        let narrator = FakeNarrator()
        let session = LessonSession(book: f.package.book, lesson: f.package.book.lessons[0], store: f.store, speech: narrator, settings: settings, practiceOnly: false)
        session.togglePlayback(); narrator.finish()
        session.togglePlayback()
        XCTAssertNotNil(session.reflectionRemaining); XCTAssertFalse(session.autoRunning)
        try await Task.sleep(nanoseconds: 350_000_000)
        XCTAssertEqual(session.index, 0); XCTAssertEqual(narrator.spokenCount, 1)
        session.togglePlayback()
        try await Task.sleep(nanoseconds: 350_000_000)
        XCTAssertEqual(session.index, 1); XCTAssertEqual(narrator.spokenCount, 2)
        XCTAssertEqual(narrator.lastRole, .storyteller)
        session.stop()
    }

    @MainActor func testClosureInterruptionAndNavigationInvalidateDelayedAdvance() async throws {
        let f = try await CollectionFixture.make(); addTeardownBlock { await f.cleanup() }
        let settings = PlaybackSettings(defaults: f.defaults); settings.pagePause = 0.1
        for action in 0..<3 {
            let narrator = FakeNarrator()
            let session = LessonSession(book: f.package.book, lesson: f.package.book.lessons[0], store: f.store, speech: narrator, settings: settings, practiceOnly: false)
            session.changePage(0, keepPlaying: false); session.togglePlayback(); narrator.finish()
            if action == 0 { session.stop() } // close/settings/source/interruption all use stop
            if action == 1 { session.changePage(3, keepPlaying: false) }
            if action == 2 { session.suspend() } // background behavior
            try await Task.sleep(nanoseconds: 200_000_000)
            XCTAssertEqual(session.index, action == 1 ? 3 : 0); XCTAssertFalse(session.autoRunning)
            session.stop()
        }
    }

    @MainActor func testHomeStatesAndSavedReflectionPreference() async throws {
        let f = try await CollectionFixture.make(empty: true); addTeardownBlock { await f.cleanup() }
        XCTAssertNil(f.store.continueLearning)
        let package = f.multiIdea(); try await f.commit(package)
        XCTAssertEqual(f.store.continueLearning?.action, .start)
        let first = package.book.lessons[0]
        f.store.update(book: package.book, lesson: first) { $0.pageIndex = 2; $0.lastEngagedAt = Date() }
        XCTAssertEqual(f.store.continueLearning?.action, .resume)
        XCTAssertEqual(f.store.continueLearning?.position, "Reading · Screen 3 of 8")
        f.store.update(book: package.book, lesson: first) { $0.phase = .complete; $0.practiceComplete = true }
        XCTAssertEqual(f.store.continueLearning?.action, .next)
        XCTAssertEqual(f.store.continueLearning?.lesson.id, package.book.lessons[1].id)
        for lesson in package.book.lessons { f.store.update(book: package.book, lesson: lesson) { $0.phase = .complete; $0.practiceComplete = true; $0.lastEngagedAt = Date() } }
        XCTAssertEqual(f.store.continueLearning?.action, .revisit)
        XCTAssertEqual(PlaybackSettings(defaults: f.defaults).pagePause, 2)
        f.defaults.set(1.5, forKey: "pagePause")
        XCTAssertEqual(PlaybackSettings(defaults: f.defaults).pagePause, 1.5)
    }
}

extension ResumeTests {
    @MainActor func testManualPlaybackNavigationChangesRolesAndRejectsOldCompletion() async throws {
        let f = try await CollectionFixture.make(); addTeardownBlock { await f.cleanup() }
        let settings = PlaybackSettings(defaults: f.defaults); settings.pagePause = 0
        let narrator = FakeNarrator()
        let session = LessonSession(book: f.package.book, lesson: f.package.book.lessons[0], store: f.store, speech: narrator, settings: settings, practiceOnly: false)
        session.togglePlayback(); XCTAssertEqual(narrator.lastRole, .guide)
        let stale = try XCTUnwrap(narrator.completions.first)
        session.changePage(1)
        XCTAssertEqual(narrator.lastRole, .storyteller); XCTAssertTrue(narrator.isPlaying)
        stale(); try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(session.index, 1)
        session.changePage(session.lesson.pages.count - 1)
        XCTAssertEqual(narrator.lastRole, .guide)
        try XCTUnwrap(narrator.completions.last)()
        XCTAssertFalse(session.autoRunning); XCTAssertEqual(session.phase, .reading)
        session.stop()
    }
}
