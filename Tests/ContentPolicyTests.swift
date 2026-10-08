import XCTest
@testable import LifeIsLearned

final class ContentPolicyTests: XCTestCase {
    @MainActor func testNewImportIdeaBoundariesAndAssetResourceBudgets() async throws {
        let f = try await CollectionFixture.make(empty: true); addTeardownBlock { await f.cleanup() }
        for count in [1, 12] {
            var package = f.multiIdea(count: count)
            package.collectionRevision = count == 12 ? 2 : 1
            await f.store.prepareImport(from: try f.file(package))
            XCTAssertNil(f.store.errorMessage)
            let review = try XCTUnwrap(f.store.importReview)
            XCTAssertEqual(review.package.book.lessons.count, count)
            await f.store.commitImport(review); await f.store.flush()
            XCTAssertNil(f.store.errorMessage)
            XCTAssertEqual(f.store.books.first?.lessons.count, count)
        }
        for count in [0, 13] {
            f.store.cancelImport()
            await f.store.prepareImport(from: try f.file(f.multiIdea(count: count)))
            XCTAssertNil(f.store.importReview)
            XCTAssertNotNil(f.store.errorMessage)
            XCTAssertEqual(f.store.books.first?.lessons.count, 12)
            if count == 13 { XCTAssertTrue(f.store.errorMessage?.contains("This collection contains 13 ideas. Prepare a complete release with no more than 12 selected ideas.") == true) }
        }
        var invalid = f.multiIdea()
        invalid.book.lessons[1].id = invalid.book.lessons[0].id
        invalid.manifest = invalid.book.lessons.map { IdeaManifestEntry(id: $0.id, revision: $0.revision) }
        XCTAssertThrowsError(try invalid.validated(), "Duplicate IDs still fail even with a matching manifest")
        invalid = f.multiIdea()
        let sampleImage = invalid.artwork.values.first
        invalid.assets?[" "] = sampleImage
        XCTAssertThrowsError(try invalid.validated())
        invalid = f.multiIdea(); invalid.assets = ["broken": CollectionArtwork(mediaType: "image/png", data: Data("not an image".utf8))]
        XCTAssertThrowsError(try invalid.validated())
        // All individual files are within budget; the shared table exceeds 24 MiB.
        invalid = f.multiIdea()
        let image = try XCTUnwrap(invalid.artwork.values.first)
        let count = CollectionLimits.allAssetBytes / image.data.count + 1
        invalid.assets = Dictionary(uniqueKeysWithValues: (0..<count).map { ("image-\($0)", image) })
        XCTAssertThrowsError(try invalid.validated()) { XCTAssertTrue($0.localizedDescription.contains("24 MiB")) }
        XCTAssertThrowsError(try LessonPackage.decodeImport(Data(count: CollectionLimits.packageBytes + 1)))
    }

    @MainActor func testStoredHundredIdeaCollectionSurvivesAndCompliantUpdateRequiresRemovals() async throws {
        let f = try await CollectionFixture.make(empty: true); addTeardownBlock { await f.cleanup() }
        let original = f.multiIdea(count: 100)
        XCTAssertNoThrow(try original.validated(for: .storedContent))
        XCTAssertThrowsError(try original.validated())
        var catalog = CollectionCatalog(packages: [original]); try catalog.record(original)
        var saved = LessonProgress(); saved.pageIndex = 3; saved.readComplete = true; saved.practiceComplete = true
        let keys = original.book.lessons.map { LessonProgress.key(bookID: original.book.id, lesson: $0) }
        let progress = Dictionary(uniqueKeysWithValues: keys.map { ($0, saved) })
        try await f.store.storage.save(catalog: catalog, progress: progress, cards: [:], history: [BookHistoryRecord.refresh(original, progress: progress, source: .manual, previous: nil)])
        let loaded = LibraryStore(documentsURL: f.directory, defaults: f.defaults, initialPackage: f.package)
        await loaded.ready()
        XCTAssertNil(loaded.errorMessage); XCTAssertFalse(loaded.readOnly)
        XCTAssertEqual(loaded.books.first?.lessons.count, 100)
        XCTAssertEqual(loaded.progress.count, 100)
        XCTAssertEqual(loaded.progress[keys.last!]?.pageIndex, 3)

        // The old imported-books migration path must also keep valid format-2 books.
        let legacyDirectory = f.directory.appendingPathComponent("old-storage")
        try FileManager.default.createDirectory(at: legacyDirectory, withIntermediateDirectories: true)
        try JSONEncoder().encode([original]).write(to: legacyDirectory.appendingPathComponent("imported-books.json"))
        f.defaults.set(try JSONEncoder().encode(progress), forKey: "lessonProgress.v1")
        let migrated = LibraryStore(documentsURL: legacyDirectory, defaults: f.defaults, includeDemo: false)
        await migrated.ready()
        XCTAssertNil(migrated.errorMessage); XCTAssertFalse(migrated.readOnly)
        XCTAssertEqual(migrated.books.first?.lessons.count, 100)
        XCTAssertTrue(migrated.progress[keys.last!]?.practiceComplete == true)

        var update = original; update.collectionRevision = 2
        update.book.lessons = Array(original.book.lessons.prefix(12))
        update.manifest = update.book.lessons.map { IdeaManifestEntry(id: $0.id, revision: $0.revision) }
        await loaded.prepareImport(from: try f.file(update))
        XCTAssertNil(loaded.importReview); XCTAssertNotNil(loaded.errorMessage)
        update.removedLessonIDs = original.book.lessons.dropFirst(12).map(\.id)
        await loaded.prepareImport(from: try f.file(update))
        let review = try XCTUnwrap(loaded.importReview)
        XCTAssertEqual(review.removed.count, 88); XCTAssertEqual(review.unchanged.count, 12)
        await loaded.commitImport(review)
        XCTAssertEqual(loaded.books.first?.lessons.count, 100)
        XCTAssertNotNil(loaded.errorMessage)
        await loaded.commitImport(review, acknowledgeRemovals: true); await loaded.flush()
        XCTAssertNil(loaded.errorMessage)
        let reloaded = LibraryStore(documentsURL: f.directory, defaults: f.defaults, includeDemo: false)
        await reloaded.ready()
        XCTAssertNil(reloaded.errorMessage); XCTAssertFalse(reloaded.readOnly)
        XCTAssertEqual(reloaded.books.first?.lessons.count, 12)
        XCTAssertEqual(reloaded.progress.count, 100)
        for key in keys { XCTAssertTrue(reloaded.progress[key]?.practiceComplete == true) }
        print("STORED_COLLECTION originalIdeas=100 updatedIdeas=12 archivedProgress=88 activeProgress=12 recoveryMode=false")
    }

    @MainActor func testShortDemoIsExplicitRevisionUpdateAndDoesNotReplaceInstalledSeed() async throws {
        let f = try await CollectionFixture.make(); addTeardownBlock { await f.cleanup() }
        let short = try Self.shortDemo()
        let oldLesson = f.package.book.lessons[0]
        f.store.update(book: f.package.book, lesson: oldLesson) { $0.pageIndex = 4; $0.practiceComplete = true }
        await f.store.flush()
        let reopened = LibraryStore(documentsURL: f.directory, defaults: f.defaults, initialPackage: short)
        await reopened.ready()
        XCTAssertEqual(reopened.books.first?.lessons.first?.revision, 1, "A new seed must not overwrite an installed collection")
        XCTAssertEqual(reopened.status(book: f.package.book, lesson: oldLesson).pageIndex, 4)
        await reopened.prepareImport(from: try f.file(short))
        let review = try XCTUnwrap(reopened.importReview)
        XCTAssertEqual(review.revised.count, 1); XCTAssertTrue(review.removed.isEmpty)
        await reopened.commitImport(review); await reopened.flush()
        XCTAssertNil(reopened.errorMessage)
        let current = try XCTUnwrap(reopened.books.first?.lessons.first)
        XCTAssertEqual(current.revision, 2)
        XCTAssertFalse(reopened.status(book: short.book, lesson: current).practiceComplete)
        XCTAssertTrue(reopened.status(book: short.book, lesson: oldLesson).practiceComplete)
    }

    func testWholeIdeaTimingIncludesTitlesChoicesFeedbackAndPauses() throws {
        let package = try Self.shortDemo(), lesson = package.book.lessons[0]
        let timing = LessonTiming(lesson: lesson)
        XCTAssertEqual(timing.spokenWords, 413, "Must match the Python timing report")
        XCTAssertEqual(timing.transitionCount, 5)
        XCTAssertEqual(timing.pauseSeconds, 10)
        XCTAssertEqual(timing.answerSeconds, 40)
        XCTAssertEqual(timing.totalSeconds, 240.6153846153846, accuracy: 0.001)
        XCTAssertEqual(timing.approximateMinutes, lesson.estimatedMinutes)
        XCTAssertEqual(timing.segments.filter { $0.id.hasPrefix("question:") }.count, 2)
        XCTAssertTrue(timing.segments.contains { $0.text.contains("Option 3.") })
        XCTAssertTrue(timing.segments.contains { $0.text.hasPrefix("That's right.") || $0.text.hasPrefix("Let's reconsider.") })
        XCTAssertEqual(timing.segments.last?.text, LessonNarration.completion(correct: 2, total: 2))
        XCTAssertEqual(LessonTiming.wordCount("Don't rush—café 2’s choice."), 5)
        XCTAssertTrue(package.book.selectionPreface.contains("1 selected idea"))
        XCTAssertFalse(package.book.selectionPreface.contains("[N]"))
        let records = timing.segments.map { ["id": $0.id, "role": $0.role.rawValue, "text": $0.text] }
        let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: records, options: [.sortedKeys, .prettyPrinted]), uniformTypeIdentifier: "public.json")
        attachment.name = "native-reference-script"; attachment.lifetime = .keepAlways; add(attachment)
    }

    static func shortDemo() throws -> LessonPackage {
        let url = try XCTUnwrap(Bundle(for: ContentPolicyTests.self).url(forResource: "Example-Lesson-Package", withExtension: "json"))
        return try LessonPackage.decodeImport(Data(contentsOf: url))
    }
}
