import XCTest
import SwiftUI
@testable import LifeIsLearned

@MainActor final class Handoff005ATests: XCTestCase {
    func testLegacyFingerprintAndOptionalFieldsStayCompatible() async throws {
        let f = try await CollectionFixture.make(); addTeardownBlock { await f.cleanup() }
        let package = f.package, lesson = package.book.lessons[0]
        XCTAssertNil(lesson.pages[0].secondaryImageID)
        XCTAssertNil(lesson.pages[0].isOriginalFiction)
        // Persisted baseline produced by the pre-005 fingerprint implementation.
        XCTAssertEqual(try package.fingerprint(lesson), "8e7945c26ea520cc2b2da9e87b5995e01fde0a6ecdb6dd8ecc5138f21917a445")
        var changed = package
        let story = try XCTUnwrap(lesson.pages.firstIndex { $0.kind == .story })
        changed.book.lessons[0].pages[story].secondaryImageID = lesson.pages[0].imageID
        changed.book.lessons[0].pages[story].secondaryImageDescription = "Second scene"
        _ = try changed.validated()
        XCTAssertNotEqual(try changed.fingerprint(changed.book.lessons[0]), try package.fingerprint(lesson))
        let before = try changed.fingerprint(changed.book.lessons[0])
        let id = try XCTUnwrap(changed.book.lessons[0].pages[story].secondaryImageID)
        let alias = changed.assets?[id]
        changed.assets?["secondary-alias"] = alias
        changed.book.lessons[0].pages[story].secondaryImageID = "secondary-alias"
        XCTAssertEqual(try changed.fingerprint(changed.book.lessons[0]), before, "Asset aliases do not revise content")
        changed.assets?["secondary-alias"]?.data.append(0)
        XCTAssertNotEqual(try changed.fingerprint(changed.book.lessons[0]), before)
        changed.book.lessons[0].pages[story].secondaryImageDescription = " "
        XCTAssertThrowsError(try changed.validated())
    }

    func testCompletionTransitionOnceAndNewRevisionCanCelebrate() async throws {
        let f = try await CollectionFixture.make(); addTeardownBlock { await f.cleanup() }
        let settings = PlaybackSettings(defaults: f.defaults), feedback = RecordingFeedback()
        let book = f.package.book, lesson = book.lessons[0]
        func session(_ l: Lesson) -> LessonSession {
            LessonSession(book: book, lesson: l, store: f.store, speech: FakeNarrator(), settings: settings,
                          practiceOnly: true, completionFeedback: feedback)
        }
        func finish(_ s: LessonSession) {
            s.beginPractice()
            for _ in s.lesson.questions { s.answer(s.question.correctChoiceID); s.nextQuestion() }
        }
        let first = session(lesson)
        first.answer(first.question.choices.first { $0.id != first.question.correctChoiceID }!.id)
        first.nextQuestion()
        XCTAssertEqual(feedback.haptics, 0)
        XCTAssertNil(first.takeCompletionBloom())
        finish(first)
        XCTAssertEqual(feedback.haptics, 1); XCTAssertEqual(feedback.sounds, 1)
        XCTAssertNotNil(first.takeCompletionBloom()); XCTAssertNil(first.takeCompletionBloom())
        finish(session(lesson))
        XCTAssertEqual(feedback.haptics, 1)
        var revised = lesson; revised.revision += 1
        let next = session(revised); finish(next)
        XCTAssertEqual(feedback.haptics, 2); XCTAssertNotNil(next.takeCompletionBloom())
        XCTAssertTrue(f.store.status(book: book, lesson: revised).practiceComplete)
        XCTAssertEqual(f.store.cards[next.collectedCardID]?.lastEarnedRevision, revised.revision)
    }

    func testFeedbackSettingsAndFailuresNeverBlockCollection() async throws {
        let f = try await CollectionFixture.make(); addTeardownBlock { await f.cleanup() }
        let settings = PlaybackSettings(defaults: f.defaults), feedback = RecordingFeedback()
        XCTAssertTrue(settings.completionSound); XCTAssertTrue(settings.completionHaptics)
        settings.completionSound = false; settings.completionHaptics = false
        CompletionFeedback.deliver(using: feedback, settings: settings)
        XCTAssertEqual(feedback.sounds, 0); XCTAssertEqual(feedback.haptics, 0)
        let restored = PlaybackSettings(defaults: f.defaults)
        XCTAssertFalse(restored.completionSound); XCTAssertFalse(restored.completionHaptics)
        settings.completionSound = true
        CompletionFeedback.deliver(using: feedback, settings: settings)
        XCTAssertEqual(feedback.sounds, 1); XCTAssertEqual(feedback.haptics, 0)
        settings.completionHaptics = true; feedback.fails = true
        let book = f.package.book, lesson = book.lessons[0]
        let s = LessonSession(book: book, lesson: lesson, store: f.store, speech: FakeNarrator(),
                              settings: settings, practiceOnly: true, completionFeedback: feedback)
        for _ in lesson.questions { s.answer(s.question.correctChoiceID); s.nextQuestion() }
        XCTAssertEqual(s.phase, .complete); XCTAssertTrue(s.hasCollectedCard)
        XCTAssertNotNil(s.takeCompletionBloom())
        XCTAssertEqual(feedback.haptics, 1); XCTAssertEqual(feedback.sounds, 2, "Haptic failure cannot suppress sound")
    }

    func testCompletionAndReduceMotionRenderedEvidence() async throws {
        let f = try await CollectionFixture.make(); addTeardownBlock { await f.cleanup() }
        for reduce in [false, true] {
            let settings = PlaybackSettings(defaults: f.defaults)
            var book = f.package.book; book.id += reduce ? "-reduced" : "-motion"
            let lesson = book.lessons[0]
            let session = LessonSession(book: book, lesson: lesson, store: f.store, speech: FakeNarrator(),
                                        settings: settings, practiceOnly: true, completionFeedback: RecordingFeedback())
            for _ in lesson.questions { session.answer(session.question.correctChoiceID); session.nextQuestion() }
            let host = UIHostingController(rootView: LessonCompletionView(session: session, continueBook: {}, reduceMotionOverride: reduce).readingCanvas())
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
            window.rootViewController = host; window.makeKeyAndVisible(); host.view.layoutIfNeeded()
            try await Task.sleep(for: .milliseconds(250))
            let image = UIGraphicsImageRenderer(bounds: host.view.bounds).image { _ in host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true) }
            let attachment = XCTAttachment(image: image); attachment.name = reduce ? "h005a-bloom-reduce-motion" : "h005a-bloom"
            attachment.lifetime = .keepAlways; add(attachment)
            XCTAssertNil(session.takeCompletionBloom(), "Presentation consumes the event once")
            window.isHidden = true
        }
    }
}

@MainActor private final class RecordingFeedback: CompletionFeedbackPlaying {
    var haptics = 0, sounds = 0
    var fails = false
    func playHaptic() throws { haptics += 1; if fails { throw PackageError.invalid("Synthetic haptic failure") } }
    func playSound() throws { sounds += 1; if fails { throw PackageError.invalid("Synthetic sound failure") } }
}
