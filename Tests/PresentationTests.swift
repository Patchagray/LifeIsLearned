import XCTest
import SwiftUI
@testable import LifeIsLearned

final class PresentationTests: XCTestCase {
    @MainActor func testLearningJourneyRenderedScreens() async throws {
        let f = try await CollectionFixture.make(); addTeardownBlock { await f.cleanup() }
        let store = f.store
        let settings = PlaybackSettings(defaults: f.defaults)
        let speech = NarrationController()
        let narrator = FakeNarrator()
        let lesson = f.package.book.lessons[0]
        let session = LessonSession(book: f.package.book, lesson: lesson, store: store, speech: narrator, settings: settings, practiceOnly: false)
        let pad = UIDevice.current.userInterfaceIdiom == .pad
        let prefix = pad ? "ipad" : "iphone"
        let normalSize = CGSize(width: pad ? 820 : 390, height: pad ? 1180 : 844)

        func capture<V: View>(_ content: V, _ name: String, size: CGSize? = nil,
                              scheme: ColorScheme = .light, type: DynamicTypeSize = .large, bottom: Bool = false) async throws {
            let host = UIHostingController(rootView: content
                .environmentObject(store).environmentObject(settings).environmentObject(speech)
                .environment(\.colorScheme, scheme).environment(\.dynamicTypeSize, type)
                .tint(Palette.teal))
            let window = UIWindow(frame: CGRect(origin: .zero, size: size ?? normalSize))
            window.rootViewController = host
            window.overrideUserInterfaceStyle = scheme == .dark ? .dark : .light
            window.makeKeyAndVisible()
            host.view.layoutIfNeeded()
            try await Task.sleep(nanoseconds: 600_000_000)
            host.view.layoutIfNeeded()
            if bottom {
                func scrolls(_ view: UIView) -> [UIScrollView] {
                    (view as? UIScrollView).map { [$0] } ?? view.subviews.flatMap { scrolls($0) }
                }
                if let scroll = scrolls(host.view).first {
                    scroll.setContentOffset(CGPoint(x: 0, y: max(-scroll.adjustedContentInset.top, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)), animated: false)
                    try await Task.sleep(nanoseconds: 100_000_000)
                }
            }
            XCTAssertGreaterThan(host.view.bounds.height, 300)
            let image = UIGraphicsImageRenderer(bounds: host.view.bounds).image { _ in
                host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
            }
            let attachment = XCTAttachment(image: image)
            attachment.name = "\(prefix)-\(name)"; attachment.lifetime = .keepAlways; add(attachment)
            window.isHidden = true
        }
        func reader() -> ReaderView { ReaderView(session: session, speech: speech, settings: settings) }

        try await capture(LibraryView(), "home")
        try await capture(NavigationStack { BookDetailView(book: f.package.book) }, "book")
        session.changePage(1, keepPlaying: false)
        try await capture(reader(), "reader")
        try await capture(reader(), "reader-dark", scheme: .dark)
        try await capture(reader(), "reader-large-text", type: .accessibility3)
        try await capture(reader(), "reader-landscape", size: CGSize(width: normalSize.height, height: normalSize.width))
        session.changePage(lesson.pages.count - 1, keepPlaying: false)
        try await capture(reader(), "takeaway-closed")
        session.toggleTakeaway()
        try await capture(reader(), "takeaway-open")
        try await capture(reader(), "takeaway-dark", scheme: .dark)
        session.beginPractice()
        try await capture(reader(), "practice")
        session.answer(try XCTUnwrap(session.question.choices.first { $0.id != session.question.correctChoiceID }).id)
        try await capture(reader(), "practice-retry")
        try await capture(reader(), "practice-retry-dark", scheme: .dark)
        session.retry(); session.answer(session.question.correctChoiceID)
        try await capture(reader(), "practice-correct")
        session.nextQuestion(); session.answer(session.question.correctChoiceID); session.nextQuestion()
        try await capture(reader(), "completion")
        try await capture(reader(), "completion-dark", scheme: .dark)
        try await capture(SettingsView(), "settings")
        try await capture(SettingsView(), "settings-dark", scheme: .dark)
        try await capture(SourcesView(book: f.package.book), "sources")
        var collection = f.multiIdea()
        await store.prepareImport(from: try f.file(collection))
        let review = try XCTUnwrap(store.importReview)
        try await capture(ImportReviewView(review: review), "import-preview")
        try await capture(ImportReviewView(review: review), "import-preview-dark", scheme: .dark)
        await store.commitImport(review)
        store.importedBook = nil
        collection.book.title = "A Thoughtful Collection of Ideas for Seeing the World a Little Differently"
        collection.collectionRevision = 2
        await store.prepareImport(from: try f.file(collection))
        try await capture(ImportReviewView(review: XCTUnwrap(store.importReview)), "import-update")
        store.cancelImport()
        try await f.commit(collection)
        store.importedBook = nil
        try await capture(LibraryView(), "home-multiple-books", bottom: true)
        try await capture(LibraryView(initialSearch: "unmatched query"), "search-empty", bottom: true)
        try await capture(NavigationStack { BookDetailView(book: collection.book) }, "book-long-title", type: .accessibility1)
        try await capture(LibraryView(), "home-dark", scheme: .dark)
        try await capture(LibraryView(), "home-large-text", type: .accessibility3)
        try await capture(LibraryView(), "library-large-text", type: .accessibility3, bottom: true)
        session.stop()
        await store.flush()
        XCTAssertFalse(speech.isPlaying, "Screenshots inject session state; they never start real audio")
        XCTAssertEqual(session.firstTryCorrect, 1)
    }

    @MainActor func testEmptyLibraryAndSemanticContrast() async throws {
        let f = try await CollectionFixture.make(empty: true); addTeardownBlock { await f.cleanup() }
        XCTAssertNil(f.store.continueLearning)
        let host = UIHostingController(rootView: LibraryView().environmentObject(f.store)
            .environmentObject(PlaybackSettings(defaults: f.defaults)).environmentObject(NarrationController()))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 568))
        window.rootViewController = host; window.makeKeyAndVisible()
        try await Task.sleep(nanoseconds: 200_000_000)
        let screenshot = UIGraphicsImageRenderer(bounds: host.view.bounds).image { _ in host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true) }
        let attachment = XCTAttachment(image: screenshot); attachment.name = "empty-library-narrow"; attachment.lifetime = .keepAlways; add(attachment)
        window.isHidden = true
        func luminance(_ color: Color, style: UIUserInterfaceStyle) -> Double {
            let resolved = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
            func linear(_ v: CGFloat) -> Double { let x = Double(v); return x <= 0.04045 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4) }
            return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
        }
        for style in [UIUserInterfaceStyle.light, .dark] {
            for (foreground, background) in [(Palette.ink, Palette.paper), (Palette.secondary, Palette.paper), (Palette.teal, Palette.paper), (Palette.onTeal, Palette.teal), (Palette.amber, Palette.reflection)] as [(Color, Color)] {
                let a = luminance(foreground, style: style), b = luminance(background, style: style)
                XCTAssertGreaterThanOrEqual((max(a,b)+0.05)/(min(a,b)+0.05), 4.5)
            }
        }
    }
}

final class BrandTests: XCTestCase {
    @MainActor func testProductionIconIsCompiledIntoAppBundle() throws {
        let icons = try XCTUnwrap(Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any])
        let primary = try XCTUnwrap(icons["CFBundlePrimaryIcon"] as? [String: Any])
        XCTAssertEqual(primary["CFBundleIconName"] as? String, "AppIcon")
        let files = try XCTUnwrap(primary["CFBundleIconFiles"] as? [String])
        XCTAssertFalse(files.isEmpty)
        for file in files { XCTAssertNotNil(UIImage(named: file), "Compiled icon must load: \(file)") }
    }
}
