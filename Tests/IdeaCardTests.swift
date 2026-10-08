import XCTest
@testable import LifeIsLearned

final class IdeaCardTests: XCTestCase {
    @MainActor private func complete(_ book: LearningBook, _ lesson: Lesson, in store: LibraryStore,
                                     defaults: UserDefaults, imperfect: Bool = false) -> LessonSession {
        let session = LessonSession(book: book, lesson: lesson, store: store, speech: FakeNarrator(),
                                    settings: PlaybackSettings(defaults: defaults), practiceOnly: true)
        session.beginPractice()
        if imperfect {
            session.answer(session.question.choices.first { $0.id != session.question.correctChoiceID }!.id)
            session.retry()
        }
        for _ in lesson.questions { session.answer(session.question.correctChoiceID); session.nextQuestion() }
        session.stop()
        return session
    }

    @MainActor func testImperfectCompletionEarnsOnceAndReviewPreservesOriginalScoreAndDate() async throws {
        let f = try await CollectionFixture.make(); addTeardownBlock { await f.cleanup() }
        let book = f.package.book, lesson = book.lessons[0]
        let session = complete(book, lesson, in: f.store, defaults: f.defaults, imperfect: true)
        XCTAssertEqual(session.phase, .complete); XCTAssertEqual(session.firstTryCorrect, 1)
        let original = try XCTUnwrap(f.store.cards.values.first)
        XCTAssertEqual(f.store.cards.count, 1); XCTAssertNotNil(original.earnedAt)
        f.store.toggleFavorite(original.id); await f.store.flush()
        let reload = LibraryStore(documentsURL: f.directory, defaults: f.defaults, initialPackage: f.package)
        await reload.ready()
        XCTAssertTrue(reload.cards[original.id]?.isFavorite == true)
        let narrator = FakeNarrator()
        let review = LessonSession(book: book, lesson: lesson, store: reload, speech: narrator,
            settings: PlaybackSettings(defaults: f.defaults), practiceOnly: false, review: true)
        review.engage()
        XCTAssertEqual(review.index, 0); XCTAssertEqual(narrator.spokenCount, 0)
        XCTAssertTrue(reload.status(book: book, lesson: lesson).practiceComplete)
        XCTAssertEqual(reload.status(book: book, lesson: lesson).firstTryCorrect, 1)
        _ = complete(book, lesson, in: reload, defaults: f.defaults)
        XCTAssertEqual(reload.cards.count, 1)
        XCTAssertEqual(reload.cards[original.id]?.earnedAt, original.earnedAt)
        XCTAssertEqual(reload.status(book: book, lesson: lesson).firstTryCorrect, 1)
        XCTAssertTrue(reload.cards[original.id]?.isFavorite == true)
        await reload.flush(); review.stop()
    }

    @MainActor func testRevisionMetadataReorderAndRemovalPreserveOwnedCards() async throws {
        let f = try await CollectionFixture.make(empty: true); addTeardownBlock { await f.cleanup() }
        let original = f.multiIdea(); try await f.commit(original)
        let first = original.book.lessons[0], second = original.book.lessons[1]
        _ = complete(original.book, first, in: f.store, defaults: f.defaults)
        _ = complete(original.book, second, in: f.store, defaults: f.defaults, imperfect: true)
        let id = LessonProgress.identity(bookID: original.book.id, lessonID: first.id)
        f.store.toggleFavorite(id); await f.store.flush()
        let earned = try XCTUnwrap(f.store.cards[id])
        var updated = original; updated.collectionRevision = 2; updated.book.title = "A new book display title"
        updated.book.lessons[0].revision = 2; updated.book.lessons[0].title = "A revised idea"
        updated.book.lessons[0].pages[updated.book.lessons[0].pages.count - 1].text = "Examine support and challenges fairly."
        updated.book.lessons.swapAt(0, 1)
        updated.manifest = updated.book.lessons.map { IdeaManifestEntry(id: $0.id, revision: $0.revision) }
        try await f.commit(updated)
        var card = try XCTUnwrap(f.store.cards[id])
        XCTAssertEqual(card, earned)
        XCTAssertTrue(f.store.cardPresentation(card).updated)
        let revised = try XCTUnwrap(updated.book.lessons.first { $0.id == first.id })
        XCTAssertFalse(f.store.status(book: updated.book, lesson: revised).practiceComplete)
        _ = complete(updated.book, revised, in: f.store, defaults: f.defaults)
        card = try XCTUnwrap(f.store.cards[id]); XCTAssertEqual(card.lastEarnedRevision, 2)
        XCTAssertEqual(card.snapshot.title, "A revised idea"); XCTAssertEqual(card.snapshot.takeaway, "Examine support and challenges fairly.")
        XCTAssertEqual(card.earnedAt, earned.earnedAt); XCTAssertTrue(card.isFavorite)
        var removed = f.multiIdea(count: 4); removed.collectionRevision = 3
        removed.book.lessons = [removed.book.lessons[3]]
        removed.removedLessonIDs = original.book.lessons.map(\.id)
        removed.manifest = removed.book.lessons.map { IdeaManifestEntry(id: $0.id, revision: $0.revision) }
        try await f.commit(removed, acknowledge: true)
        XCTAssertEqual(f.store.cards.count, 2, "Removing the unearned third idea creates no card")
        XCTAssertTrue(f.store.cardPresentation(card).archived)
        let archivedReview = await f.store.cardReview(card)
        XCTAssertNil(archivedReview, "V3 does not retain obsolete lesson payloads for normal card browsing")
        XCTAssertEqual(f.store.cards[id], card)
        XCTAssertEqual(f.store.source(for: card.bookID).restoreTitle, "Re-import book")
        let reload = LibraryStore(documentsURL: f.directory, defaults: f.defaults, includeDemo: false); await reload.ready()
        XCTAssertEqual(reload.cards[id], card); XCTAssertEqual(reload.cards.count, 2)
    }

    @MainActor func testLegacyMigrationUsesCommittedCompletionAndUnknownDatesRemainUnknown() async throws {
        let f = try await CollectionFixture.make(empty: true); addTeardownBlock { await f.cleanup() }
        await f.store.flush()
        try FileManager.default.removeItem(at: f.directory.appendingPathComponent("Library-v3"))
        let old = f.multiIdea(); var current = old; current.book.lessons = [old.book.lessons[0]]
        current.book.lessons[0].revision = 2
        current.manifest = current.book.lessons.map { IdeaManifestEntry(id: $0.id, revision: $0.revision) }
        let root = f.directory.appendingPathComponent("Library-v2")
        let currentID = UUID().uuidString, historyID = UUID().uuidString, orphanID = UUID().uuidString
        var done = LessonProgress(); done.practiceComplete = true; done.firstTryCorrect = 1; done.questionCount = 2
        var dated = done; dated.practicedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let progress = [LessonProgress.key(bookID: old.book.id, lesson: old.book.lessons[0]): done,
                        LessonProgress.key(bookID: old.book.id, lesson: old.book.lessons[1]): dated]
        let encoder = JSONEncoder()
        for (id, package) in [(currentID, current), (historyID, old), (orphanID, old)] {
            let dir = root.appendingPathComponent(id); try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try encoder.encode(CollectionCatalog(packages: [package])).write(to: dir.appendingPathComponent("collections.json"))
            var recorded = progress
            if id == orphanID { recorded[LessonProgress.key(bookID: old.book.id, lesson: old.book.lessons[2])] = done }
            try encoder.encode(recorded).write(to: dir.appendingPathComponent("progress.json"))
        }
        try encoder.encode(CollectionStorage.Pointer(current: currentID, previous: historyID)).write(to: root.appendingPathComponent("CURRENT.json"))
        let migrated = LibraryStore(documentsURL: f.directory, defaults: f.defaults, includeDemo: false); await migrated.ready()
        XCTAssertFalse(migrated.readOnly); XCTAssertNil(migrated.errorMessage)
        XCTAssertEqual(migrated.cards.count, 2, "Uncommitted progress never earns a card")
        let firstID = LessonProgress.identity(bookID: old.book.id, lessonID: old.book.lessons[0].id)
        let first = try XCTUnwrap(migrated.cards[firstID])
        XCTAssertNil(first.earnedAt); XCTAssertEqual(first.earnedLabel, "Earned previously")
        XCTAssertFalse(first.isFavorite); XCTAssertEqual(first.lastEarnedRevision, 1)
        XCTAssertTrue(migrated.cardPresentation(first).updated)
        XCTAssertEqual(migrated.cards.values.first { $0.lessonID == old.book.lessons[1].id }?.earnedAt, dated.practicedAt)
        migrated.toggleFavorite(firstID); await migrated.flush()
        let again = LibraryStore(documentsURL: f.directory, defaults: f.defaults, includeDemo: false); await again.ready()
        XCTAssertTrue(again.cards[firstID]?.isFavorite == true); XCTAssertNil(again.cards[firstID]?.earnedAt)
        XCTAssertEqual(again.cards.count, 2)
    }

    @MainActor func testCardCorruptionRecoversIndependentlyAndTotalFailurePreservesFiles() async throws {
        let f = try await CollectionFixture.make(); addTeardownBlock { await f.cleanup() }
        _ = complete(f.package.book, f.package.book.lessons[0], in: f.store, defaults: f.defaults)
        await f.store.flush()
        let id = try XCTUnwrap(f.store.cards.keys.first)
        f.store.toggleFavorite(id); await f.store.flush()
        let root = f.directory.appendingPathComponent("Library-v3"), pointerURL = root.appendingPathComponent("CURRENT.json")
        let pointerBytes = try Data(contentsOf: pointerURL)
        let pointer = try JSONDecoder().decode(LibraryStorage.Pointer.self, from: pointerBytes)
        let current = root.appendingPathComponent("StateSnapshots/" + pointer.current).appendingPathComponent("cards.json")
        try Data("broken".utf8).write(to: current)
        let recovered = LibraryStore(documentsURL: f.directory, defaults: f.defaults, includeDemo: false); await recovered.ready()
        XCTAssertFalse(recovered.readOnly); XCTAssertEqual(recovered.cards.count, 1)
        XCTAssertTrue(recovered.errorMessage?.contains("Recovered the previous idea-card") == true)
        XCTAssertTrue(recovered.status(book: f.package.book, lesson: f.package.book.lessons[0]).practiceComplete)
        let previous = root.appendingPathComponent("StateSnapshots/" + (try XCTUnwrap(pointer.previous))).appendingPathComponent("cards.json")
        try Data("broken too".utf8).write(to: previous)
        let blocked = LibraryStore(documentsURL: f.directory, defaults: f.defaults, includeDemo: false); await blocked.ready()
        XCTAssertTrue(blocked.readOnly); blocked.toggleFavorite(id); await blocked.flush()
        XCTAssertEqual(try Data(contentsOf: pointerURL), pointerBytes)
        XCTAssertEqual(try Data(contentsOf: current), Data("broken".utf8))
    }

    @MainActor func testRecoveredCardsBackfillNewOwnershipFromCommittedProgress() async throws {
        let f = try await CollectionFixture.make(empty: true); addTeardownBlock { await f.cleanup() }
        let package = f.multiIdea(); try await f.commit(package)
        _ = complete(package.book, package.book.lessons[0], in: f.store, defaults: f.defaults)
        await f.store.flush()
        // A single update puts a second completed idea into the current snapshot,
        // while the previous snapshot still owns only the first card.
        f.store.update(book: package.book, lesson: package.book.lessons[1]) {
            $0.practiceComplete = true; $0.practicedAt = Date(); $0.firstTryCorrect = 1
        }
        await f.store.flush()
        let root = f.directory.appendingPathComponent("Library-v3")
        let pointer = try JSONDecoder().decode(LibraryStorage.Pointer.self, from: Data(contentsOf: root.appendingPathComponent("CURRENT.json")))
        try Data("broken".utf8).write(to: root.appendingPathComponent("StateSnapshots/" + pointer.current).appendingPathComponent("cards.json"))
        let reload = LibraryStore(documentsURL: f.directory, defaults: f.defaults, includeDemo: false)
        await reload.ready()
        XCTAssertFalse(reload.readOnly); XCTAssertEqual(reload.cards.count, 2)
        XCTAssertNotNil(reload.errorMessage)
        XCTAssertTrue(reload.cards.values.contains { $0.lessonID == package.book.lessons[1].id })
    }

    @MainActor func testFailedFavoriteSaveDoesNotPublishPartialState() async throws {
        let f = try await CollectionFixture.make(); addTeardownBlock { await f.cleanup() }
        _ = complete(f.package.book, f.package.book.lessons[0], in: f.store, defaults: f.defaults); await f.store.flush()
        let id = try XCTUnwrap(f.store.cards.keys.first)
        await f.store.storage.setWriteFailure(true)
        f.store.toggleFavorite(id); await f.store.flush()
        XCTAssertNotNil(f.store.errorMessage)
        let reload = LibraryStore(documentsURL: f.directory, defaults: f.defaults, includeDemo: false); await reload.ready()
        XCTAssertFalse(try XCTUnwrap(reload.cards[id]).isFavorite)
        XCTAssertTrue(reload.status(book: f.package.book, lesson: f.package.book.lessons[0]).practiceComplete)
        await f.store.storage.setWriteFailure(false)
    }

    @MainActor func testSequentialNextResumesPracticeReviewsCompletedAndStopsAtFinalIdea() async throws {
        let f = try await CollectionFixture.make(empty: true); addTeardownBlock { await f.cleanup() }
        let package = f.multiIdea(count: 5); try await f.commit(package)
        let nextLesson = package.book.lessons[3]
        f.store.update(book: package.book, lesson: nextLesson) {
            $0.pageIndex = 4; $0.phase = .practice
            $0.practice = PracticePosition(questionIndex: 1, selectedID: nil, attempted: true, firstTryCorrect: 0)
        }
        let next = try XCTUnwrap(f.store.nextIdea(after: package.book.lessons[2], in: package.book))
        XCTAssertEqual(next.lesson.id, nextLesson.id); XCTAssertFalse(next.review)
        let voice = FakeNarrator()
        let resumed = LessonSession(book: next.book, lesson: next.lesson, store: f.store, speech: voice,
            settings: PlaybackSettings(defaults: f.defaults), practiceOnly: next.practiceOnly, review: next.review)
        resumed.engage(); XCTAssertEqual(resumed.phase, .practice); XCTAssertEqual(resumed.questionIndex, 1)
        XCTAssertTrue(resumed.attempted); XCTAssertEqual(voice.spokenCount, 0)
        _ = complete(package.book, nextLesson, in: f.store, defaults: f.defaults)
        XCTAssertTrue(f.store.nextIdea(after: package.book.lessons[2], in: package.book)?.review == true)
        XCTAssertNil(f.store.nextIdea(after: package.book.lessons[4], in: package.book))
        resumed.stop()
    }

    @MainActor func testTwentyCardFilteringRetainsIdentityAndFavoriteState() async throws {
        let f = try await CollectionFixture.make(empty: true); addTeardownBlock { await f.cleanup() }
        try await IdeaCardFixture.install(in: f.store)
        let ordered = IdeaCardCollection.ordered(Array(f.store.cards.values), books: f.store.books, sort: .recent)
        let favorites = IdeaCardCollection.select(from: ordered, favoritesOnly: true, bookID: nil)
        XCTAssertEqual(ordered.count, 20); XCTAssertEqual(favorites.count, 7)
        XCTAssertEqual(favorites.map(\.id), ordered.filter(\.isFavorite).map(\.id))
        let oneBook = IdeaCardCollection.select(from: ordered, favoritesOnly: false, bookID: "card-fixture-a")
        XCTAssertEqual(oneBook.count, 10)
        XCTAssertEqual(Set(oneBook.map(\.bookID)), ["card-fixture-a"])
        XCTAssertEqual(IdeaCardCollection.select(from: ordered, favoritesOnly: true, bookID: "card-fixture-a").count, 3)
        XCTAssertEqual(f.store.cards.count, 20)
        XCTAssertEqual(Set(favorites.map(\.id)).count, 7)
    }

    @MainActor func testOrderingIdentityAndMotionPolicy() async throws {
        let f = try await CollectionFixture.make(empty: true); addTeardownBlock { await f.cleanup() }
        let package = f.multiIdea(); try await f.commit(package)
        for lesson in package.book.lessons { _ = complete(package.book, lesson, in: f.store, defaults: f.defaults) }
        let values = Array(f.store.cards.values)
        let before = IdeaCardCollection.ordered(values, books: f.store.books, sort: .book).map(\.id)
        f.store.toggleFavorite(before[1])
        XCTAssertEqual(IdeaCardCollection.ordered(Array(f.store.cards.values), books: f.store.books, sort: .book).map(\.id), before)
        for order in IdeaCardSort.allCases {
            XCTAssertEqual(IdeaCardCollection.ordered(values, books: f.store.books, sort: order).map(\.id),
                           IdeaCardCollection.ordered(values.reversed(), books: f.store.books, sort: order).map(\.id))
        }
        XCTAssertFalse(CardMotionPolicy(reduceMotion: true, visible: true, sceneActive: true).animatesFavorite)
        XCTAssertFalse(CardMotionPolicy(reduceMotion: true, visible: true, sceneActive: true).uses3DFlip)
        XCTAssertFalse(CardMotionPolicy(reduceMotion: false, visible: false, sceneActive: true).animatesFavorite)
        XCTAssertFalse(CardMotionPolicy(reduceMotion: false, visible: true, sceneActive: false).animatesFavorite)
        XCTAssertTrue(CardMotionPolicy(reduceMotion: false, visible: true, sceneActive: true).animatesFavorite)
    }
}
