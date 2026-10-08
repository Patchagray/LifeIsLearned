import XCTest
import SwiftUI
@testable import LifeIsLearned

final class IdeaCardPresentationTests: XCTestCase {
    func testArrivingCardsDoNotCreateAnUnrequestedSelection() {
        var selected: String?
        selected = IdeaCardSelection.reconcile(selected, availableIDs: ["older-book-card"])
        XCTAssertNil(selected)
        selected = IdeaCardSelection.reconcile(selected, availableIDs: ["newest-card", "older-book-card"])
        XCTAssertNil(selected, "Opening the carousel can now choose the actual current first card")
        XCTAssertEqual(IdeaCardSelection.reconcile("older-book-card", availableIDs: ["newest-card", "older-book-card"]), "older-book-card", "A real previous choice is retained")
        XCTAssertEqual(IdeaCardSelection.reconcile("removed-card", availableIDs: ["newest-card"]), "newest-card")
        XCTAssertNil(IdeaCardSelection.reconcile("removed-card", availableIDs: []))
    }

    @MainActor func testGridAccessibilityActionsKeepIdentityAndSeparateOpenFromDetails() async throws {
        let f = try await CollectionFixture.make(empty: true); addTeardownBlock { await f.cleanup() }
        try await IdeaCardFixture.install(in: f.store)
        let records = IdeaCardCollection.ordered(Array(f.store.cards.values), books: f.store.books, sort: .recent)
        let items = records.prefix(3).enumerated().map { index, record in
            IdeaGridAccessibility.Item(card: f.store.cardPresentation(record), frame: CGRect(x: index % 2 * 180, y: index * 100, width: 160, height: 220))
        }
        var opened: String?, detailed: String?, favorited: String?
        let bridge = IdeaGridAccessibility(items: items, canFavorite: true,
            open: { opened = $0 }, showDetails: { detailed = $0 }, favorite: { favorited = $0 })
        let container = IdeaGridAccessibility.Container()
        bridge.update(container)
        let elements = try XCTUnwrap(container.accessibilityElements as? [IdeaGridAccessibility.CardElement])
        XCTAssertEqual(elements.map(\.accessibilityIdentifier), items.map { "card-" + $0.card.id })
        let card = try XCTUnwrap(elements.first), id = records[0].id
        XCTAssertTrue(card.accessibilityActivate()); XCTAssertEqual(opened, id); XCTAssertNil(detailed)
        let details = try XCTUnwrap(card.accessibilityCustomActions?.first { $0.name == "Show details" })
        opened = nil
        XCTAssertEqual(details.actionHandler?(details), true); XCTAssertEqual(detailed, id); XCTAssertNil(opened)
        let favorite = try XCTUnwrap(card.accessibilityCustomActions?.first { $0.name == "Unfavorite" })
        XCTAssertEqual(favorite.actionHandler?(favorite), true); XCTAssertEqual(favorited, id)
        bridge.update(container)
        XCTAssertTrue(container.cards[id] === card, "Favorite refreshes preserve accessibility focus identity")
    }

    @MainActor func testRenderedCollectionStates() async throws {
        let f = try await CollectionFixture.make(empty: true); addTeardownBlock { await f.cleanup() }
        let store = f.store, speech = NarrationController(), settings = PlaybackSettings(defaults: f.defaults)
        let pad = UIDevice.current.userInterfaceIdiom == .pad
        let prefix = pad ? "ipad" : "iphone"
        let size = CGSize(width: pad ? 820 : 390, height: pad ? 1180 : 844)
        func capture<V: View>(_ view: V, _ name: String, scheme: ColorScheme = .light,
                              type: DynamicTypeSize = .large, landscape: Bool = false, bottom: Bool = false) async throws {
            let bounds = CGRect(origin: .zero, size: landscape ? CGSize(width: size.height, height: size.width) : size)
            let host = UIHostingController(rootView: view.environmentObject(store).environmentObject(settings).environmentObject(speech)
                .environment(\.colorScheme, scheme).environment(\.dynamicTypeSize, type)
                .tint(Palette.teal))
            let window = UIWindow(frame: bounds); window.rootViewController = host
            window.overrideUserInterfaceStyle = scheme == .dark ? .dark : .light
            window.makeKeyAndVisible(); host.view.layoutIfNeeded()
            try await Task.sleep(for: .milliseconds(600)); host.view.layoutIfNeeded()
            if bottom {
                func scrolls(_ view: UIView) -> [UIScrollView] {
                    (view as? UIScrollView).map { [$0] } ?? view.subviews.flatMap { scrolls($0) }
                }
                if let scroll = scrolls(host.view).first {
                    scroll.setContentOffset(CGPoint(x: 0, y: max(-scroll.adjustedContentInset.top, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)), animated: false)
                    try await Task.sleep(for: .milliseconds(200))
                }
            }
            XCTAssertEqual(host.view.bounds.width, bounds.width, accuracy: 1)
            let image = UIGraphicsImageRenderer(bounds: host.view.bounds).image { _ in host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true) }
            let attachment = XCTAttachment(image: image); attachment.name = "h004-\(prefix)-\(name)"; attachment.lifetime = .keepAlways; add(attachment)
            window.isHidden = true
        }
        try await capture(NavigationStack { IdeaCollectionView() }, "empty")
        try await IdeaCardFixture.install(in: store)
        XCTAssertEqual(store.cards.count, 20)
        try await capture(LibraryView(), "home-ideas-entry")
        try await capture(NavigationStack { IdeaCollectionView() }, "grid")
        try await capture(NavigationStack { IdeaCollectionView() }, "grid-dark", scheme: .dark)
        try await capture(NavigationStack { IdeaCollectionView() }, "grid-landscape", landscape: true)
        try await capture(NavigationStack { IdeaCollectionView() }, "grid-accessibility3", type: .accessibility3)
        try await capture(NavigationStack { IdeaCollectionView() }, "grid-accessibility3-bottom", type: .accessibility3, bottom: true)
        let record = try XCTUnwrap(IdeaCardCollection.ordered(Array(store.cards.values), books: store.books, sort: .recent).first)
        XCTAssertTrue(record.isFavorite)
        try await capture(NavigationStack { IdeaCollectionView(initialCardID: record.id) }, "carousel")
        try await capture(NavigationStack { IdeaCollectionView(initialCardID: record.id) }, "carousel-dark", scheme: .dark)
        try await capture(NavigationStack { IdeaCollectionView(initialCardID: record.id) }, "carousel-landscape", landscape: true)
        func single(back: Bool, compact: Bool = false) -> some View {
            ScrollView { IdeaCardView(card: store.cardPresentation(record), compact: compact, viewport: CGRect(origin: .zero, size: size), initiallyBack: back, favorite: {}, review: {})
                .frame(width: min(size.width - 48, 430), height: 600).padding(24).frame(maxWidth: .infinity) }.readingCanvas()
        }
        try await capture(single(back: true), "card-back")
        try await capture(single(back: true), "card-back-dark", scheme: .dark)
        try await capture(NavigationStack { IdeaCollectionView(initialCardID: record.id) }, "carousel-accessibility3", type: .accessibility3)
        try await capture(NavigationStack { IdeaCollectionView(initialCardID: record.id) }, "carousel-accessibility3-bottom", type: .accessibility3, bottom: true)
        let book = try XCTUnwrap(store.books.first { $0.id == "card-fixture-a" })
        let session = LessonSession(book: book, lesson: book.lessons[0], store: store, speech: FakeNarrator(), settings: settings, practiceOnly: true)
        session.beginPractice()
        session.answer(session.question.choices.first { $0.id != session.question.correctChoiceID }!.id); session.retry()
        for _ in session.lesson.questions { session.answer(session.question.correctChoiceID); session.nextQuestion() }
        try await capture(ReaderView(session: session, speech: speech, settings: settings), "completion-next")
        try await capture(ReaderView(session: session, speech: speech, settings: settings), "completion-next-dark", scheme: .dark)
        try await capture(ReaderView(session: session, speech: speech, settings: settings), "completion-next-accessibility3", type: .accessibility3)
        session.stop(); await store.flush()
        XCTAssertFalse(speech.isPlaying)
    }
}
