import XCTest
import SwiftUI
@testable import LifeIsLearned

final class SixStageLessonTests: XCTestCase {
    @MainActor private func canonical(_ original: LessonPackage) -> LessonPackage {
        // Synthetic presentation fixture only; no authored package is rewritten.
        var package = original
        let titles = ["What are you missing?", "Make room for evidence", "A difficult choice", "A different perspective", "Try another explanation", "Keep an open question"]
        let texts = [
            "A familiar answer can feel certain before you have examined it. What could help you notice another possibility? This synthetic screen demonstrates the Hook layout, not new book content.",
            "Separate what you observed from what you inferred. Consider another explanation before deciding. This synthetic screen demonstrates the Explanation layout and its guide voice; it is not an additional claim about the book.",
            "In this fictional layout example, a reader pauses at a difficult decision. She writes down what she knows, then asks which details could change her view. The setting establishes the first half of a story. This fixture checks presentation only.",
            "The reader notices a detail she had overlooked. She revisits the decision and compares two explanations. Something has changed: she now has a useful question to investigate. This fixture advances the fictional scene and checks the second half of the Story indicator.",
            "Before your next decision, name one alternative explanation and one observation that would help you choose between them. This synthetic example demonstrates a short Practical Application screen; it adds no claims to the installed book.",
            "Keep one question open long enough to consider another explanation. This synthetic takeaway checks artwork and reveal behavior."
        ]
        package.book.lessons[0].pages = (0..<6).map { i in
            var page = original.book.lessons[0].pages[0]
            page.id = "synthetic-stage-\(i)"; page.kind = SixStageLesson.kinds[i]
            page.role = (i == 2 || i == 3) ? .storyteller : .guide
            page.title = titles[i]; page.text = texts[i]
            page.imageDescription = "Synthetic layout fixture using existing reviewed illustration, stage \(i + 1)"
            return page
        }
        return package
    }

    @MainActor func testApplicationAndLegacyCountsDecodeValidateAndPersist() async throws {
        let f = try await CollectionFixture.make(); addTeardownBlock { await f.cleanup() }
        let canonicalPackage = canonical(f.package)
        let decoded = try JSONDecoder().decode(LessonPackage.self, from: JSONEncoder().encode(canonicalPackage)).validated()
        XCTAssertEqual(decoded.book.lessons[0].pages[4].kind, .application)
        for count in [2, 5, 6, 7, 8, 40] {
            var legacy = f.package
            legacy.book.lessons[0].pages = (0..<count).map { i in
                var page = f.package.book.lessons[0].pages[i == count - 1 ? f.package.book.lessons[0].pages.count - 1 : 0]
                page.id = "legacy-\(i)"; if i > 0 && i < count - 1 { page.kind = .story }
                return page
            }
            let restored = try JSONDecoder().decode(LessonPackage.self, from: JSONEncoder().encode(legacy)).validated(for: .storedContent)
            XCTAssertEqual(restored.book.lessons[0].pages.count, count)
            XCTAssertFalse(restored.book.lessons[0].usesSixStageProgress)
        }
        var imported = canonicalPackage
        imported.book.id = "six-stage-verification"
        try await f.commit(imported)
        let reloaded = LibraryStore(documentsURL: f.directory, defaults: f.defaults, includeDemo: false)
        await reloaded.ready()
        XCTAssertEqual(reloaded.books.first { $0.id == imported.book.id }?.lessons.first?.pages[4].kind, .application)
    }

    @MainActor func testSemanticProgressAndLegacyFallback() async throws {
        let f = try await CollectionFixture.make(); addTeardownBlock { await f.cleanup() }
        let lesson = canonical(f.package).book.lessons[0]
        XCTAssertTrue(lesson.usesSixStageProgress)
        XCTAssertFalse(f.package.book.lessons[0].usesSixStageProgress)
        XCTAssertEqual(SixStageLesson.pageRanges.map(\.count), [1, 1, 2, 1, 1])
        XCTAssertEqual((0..<5).map { SixStageLesson.fill(stage: $0, page: 2) }, [1, 1, 0.5, 0, 0])
        XCTAssertEqual((0..<5).map { SixStageLesson.fill(stage: $0, page: 3) }, [1, 1, 1, 0, 0])
        XCTAssertEqual(lesson.progressDescription(at: 2), "Screen 3 of 6 · Story 1 of 2")
        XCTAssertEqual(lesson.progressDescription(at: 3), "Screen 4 of 6 · Story 2 of 2")
        XCTAssertEqual(lesson.progressDescription(at: 4), "Screen 5 of 6 · Practical Application")
        XCTAssertEqual(SixStageLesson.readerLabels[4], "Practical application")
        var reordered = lesson; reordered.pages.swapAt(1, 2)
        XCTAssertFalse(reordered.usesSixStageProgress)
    }

    @MainActor func testNarrationFollowRespectsGestureVoiceOverAndReduceMotion() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 600))
        let host = UIViewController(); window.rootViewController = host; window.makeKeyAndVisible()
        defer { window.isHidden = true }
        let scroll = FollowTestScroll(frame: window.bounds); scroll.contentInsetAdjustmentBehavior = .never
        host.view.addSubview(scroll)
        var voiceOver = false
        let view = NarrationTextView(voiceOverRunning: { voiceOver }); scroll.addSubview(view)
        let text = String(repeating: "A long fictional story keeps the current spoken line visible. ", count: 45) + "Finish."
        let end = (text as NSString).range(of: "Finish")
        view.configure(text: text, fontSize: 20, range: nil, following: false, reduceMotion: true)
        view.frame = CGRect(x: 24, y: 30, width: 342, height: view.sizeThatFits(CGSize(width: 342, height: 10000)).height)
        scroll.contentSize = CGSize(width: 390, height: view.frame.maxY + 40)
        view.layoutIfNeeded()
        func follow(reduce: Bool = true) {
            view.configure(text: text, fontSize: 20, range: end, following: true, reduceMotion: reduce)
            view.followSpokenLine()
        }
        for gesture in 0..<3 {
            scroll.gesture = gesture; follow()
            XCTAssertEqual(scroll.contentOffset.y, 0, "Tracking, dragging and deceleration all win")
        }
        scroll.gesture = nil; voiceOver = true; follow()
        XCTAssertEqual(scroll.contentOffset.y, 0)
        voiceOver = false; follow()
        XCTAssertGreaterThan(scroll.contentOffset.y, 0)
        XCTAssertEqual(scroll.lastAnimated, false)
        scroll.contentOffset = .zero; follow(reduce: false)
        XCTAssertEqual(scroll.lastAnimated, true)
    }

    @MainActor func testNarrationRepresentableOnlyFollowsStories() async throws {
        for kind in SixStageLesson.kinds {
            let text = String(repeating: "This text is intentionally long to test automatic following. ", count: 45) + "Finish."
            let title = "Fixture"
            let spoken = title + ". " + text
            let host = UIHostingController(rootView: ScrollView {
                NarrationText(text: text, title: title, spokenText: spoken,
                              spokenRange: (spoken as NSString).range(of: "Finish"), isPlaying: true,
                              textSize: 20, followNarration: kind == .story)
            })
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 600))
            window.rootViewController = host; window.makeKeyAndVisible()
            host.view.layoutIfNeeded(); try await Task.sleep(nanoseconds: 200_000_000)
            let view = try XCTUnwrap(descendants(host.view).compactMap { $0 as? NarrationTextView }.first)
            var ancestor = view.superview
            while let current = ancestor, !(current is UIScrollView) { ancestor = current.superview }
            let scroll = try XCTUnwrap(ancestor as? UIScrollView)
            XCTAssertEqual(view.following, kind == .story)
            if kind == .story { XCTAssertGreaterThan(scroll.contentOffset.y, 0) }
            else { XCTAssertEqual(scroll.contentOffset.y, -scroll.adjustedContentInset.top, accuracy: 1) }
            window.isHidden = true
        }
    }

    @MainActor func testSixStageReaderRenderedEvidence() async throws {
        let f = try await CollectionFixture.make(); addTeardownBlock { await f.cleanup() }
        let package = canonical(f.package)
        let settings = PlaybackSettings(defaults: f.defaults), speech = SpeechPlayer()
        let session = LessonSession(book: package.book, lesson: package.book.lessons[0], store: f.store,
                                    speech: FakeNarrator(), settings: settings, practiceOnly: false, archivedPackage: package)
        let pad = UIDevice.current.userInterfaceIdiom == .pad
        let prefix = pad ? "ipad" : "iphone"
        func capture(_ name: String, index: Int, large: Bool = false, dark: Bool = false, follow: Bool = false) async throws {
            session.changePage(index, keepPlaying: false)
            if index == 5 { session.toggleTakeaway() }
            let host = UIHostingController(rootView: ReaderView(session: session, speech: speech, settings: settings)
                .environmentObject(f.store).environmentObject(settings).environmentObject(speech)
                .environment(\.dynamicTypeSize, large ? .accessibility3 : .large)
                .environment(\.colorScheme, dark ? .dark : .light))
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: pad ? 820 : 390, height: pad ? 1180 : 844))
            window.rootViewController = host; window.makeKeyAndVisible(); host.view.layoutIfNeeded()
            defer { window.isHidden = true }
            try await Task.sleep(nanoseconds: 500_000_000)
            let views = descendants(host.view)
            let textView = try XCTUnwrap(views.compactMap { $0 as? NarrationTextView }.first)
            XCTAssertFalse(textView.following, "Opening a page must not start playback or following")
            if !large && [0, 1, 4, 5].contains(index) {
                let rect = textView.convert(textView.bounds, to: host.view)
                XCTAssertLessThanOrEqual(rect.maxY, host.view.bounds.height - (index == 5 ? 155 : 100), "Short non-story body fits above reader controls")
            }
            if follow {
                let text = textView.text ?? ""
                let font = try XCTUnwrap(textView.attributedText.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)
                textView.configure(text: text, fontSize: font.pointSize,
                                   range: NSRange(location: (text as NSString).length - 8, length: 5), following: true, reduceMotion: true)
                textView.followSpokenLine()
                try await Task.sleep(nanoseconds: 100_000_000)
            }
            let image = UIGraphicsImageRenderer(bounds: host.view.bounds).image { _ in host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true) }
            let attachment = XCTAttachment(image: image); attachment.name = "h0046-\(prefix)-\(name)"; attachment.lifetime = .keepAlways; add(attachment)
        }
        for (i, name) in ["hook", "explanation", "story-a", "story-b", "application", "takeaway-art"].enumerated() {
            try await capture(name, index: i)
        }
        try await capture("story-long-follow", index: 2, large: true, follow: true)
        try await capture("application-large-dark", index: 4, large: true, dark: true)
        session.stop()
    }

    @MainActor private func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap { descendants($0) } }
}

@MainActor private final class FollowTestScroll: UIScrollView {
    var gesture: Int?
    var lastAnimated: Bool?
    override var isTracking: Bool { gesture == 0 }
    override var isDragging: Bool { gesture == 1 }
    override var isDecelerating: Bool { gesture == 2 }
    override func setContentOffset(_ offset: CGPoint, animated: Bool) {
        lastAnimated = animated
        super.setContentOffset(offset, animated: false)
    }
}
