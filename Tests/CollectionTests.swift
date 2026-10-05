import XCTest
import UIKit
@testable import LifeIsLearned

struct CollectionFixture {
    var package: LessonPackage
    let directory: URL
    let defaults: UserDefaults
    let suite: String
    @MainActor let store: LibraryStore

    @MainActor static func make(empty: Bool = false) async throws -> CollectionFixture {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "starter", withExtension: "json"))
        let package = try JSONDecoder().decode(LessonPackage.self, from: Data(contentsOf: url)).validated()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let suite = "CollectionTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let store = LibraryStore(documentsURL: directory, defaults: defaults, initialPackage: empty ? nil : package, includeDemo: !empty)
        await store.ready()
        return CollectionFixture(package: package, directory: directory, defaults: defaults, suite: suite, store: store)
    }
    @MainActor func cleanup() async {
        await store.flush()
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: directory)
    }
    func file(_ package: LessonPackage, name: String = "import.json") throws -> URL {
        let url = directory.appendingPathComponent(name)
        try JSONEncoder().encode(package).write(to: url)
        return url
    }
    func multiIdea(count: Int = 3) -> LessonPackage {
        var result = package
        result.book.id = "verification-collection"
        result.book.title = "The Art of Paying Attention"
        result.book.author = "Interface verification fixture"
        result.book.isDemo = nil
        result.book.coverageNote = "Synthetic verification collection. Repeats the reviewed starter to test import order, shared artwork and interface states; not a new book summary."
        result.book.lessons = (1...count).map { number in
            var lesson = package.book.lessons[0]; lesson.id = "fixture-\(number)"; lesson.title = "A different point of view · \(number)"
            return lesson
        }
        result.manifest = result.book.lessons.map { IdeaManifestEntry(id: $0.id, revision: $0.revision) }
        return result
    }
    @MainActor func commit(_ package: LessonPackage, acknowledge: Bool = false) async throws {
        await store.prepareImport(from: try file(package))
        let review = try XCTUnwrap(store.importReview, store.errorMessage ?? "Expected import review")
        await store.commitImport(review, acknowledgeRemovals: acknowledge)
        await store.flush()
    }
}

final class CollectionTests: XCTestCase {
    @MainActor func testWholeCollectionPreviewCancelImportAndIdenticalNoOp() async throws {
        let fixture = try await CollectionFixture.make()
        addTeardownBlock { await fixture.cleanup() }
        let package = fixture.multiIdea()
        await fixture.store.prepareImport(from: try fixture.file(package))
        XCTAssertEqual(fixture.store.books.count, 1)
        XCTAssertEqual(fixture.store.importReview?.added.count, 3)
        fixture.store.cancelImport()
        XCTAssertEqual(fixture.store.books.count, 1)
        try await fixture.commit(package)
        XCTAssertNil(fixture.store.errorMessage)
        let imported = try XCTUnwrap(fixture.store.books.first { $0.id == package.book.id })
        XCTAssertEqual(imported.lessons.map(\.id), package.manifest?.map(\.id))
        fixture.store.update(book: imported, lesson: imported.lessons[1]) { $0.pageIndex = 3 }
        try await fixture.commit(package)
        XCTAssertTrue(fixture.store.lastImportWasNoOp)
        XCTAssertEqual(fixture.store.books.count, 2)
        XCTAssertEqual(fixture.store.status(book: imported, lesson: imported.lessons[1]).pageIndex, 3)
        let reload = LibraryStore(documentsURL: fixture.directory, defaults: fixture.defaults, initialPackage: fixture.package)
        await reload.ready()
        XCTAssertEqual(reload.books.count, 2)
        XCTAssertEqual(reload.status(book: imported, lesson: imported.lessons[1]).pageIndex, 3)
    }

    @MainActor func testUpdateReordersPreservesUnchangedAndArchivesRevisedAndRemoved() async throws {
        let f = try await CollectionFixture.make(); addTeardownBlock { await f.cleanup() }
        let original = f.multiIdea()
        try await f.commit(original)
        for lesson in original.book.lessons {
            f.store.update(book: original.book, lesson: lesson) { $0.pageIndex = 3; $0.lastEngagedAt = Date(); $0.phase = .practice; $0.practice.attempted = true }
        }
        let oldKey = f.store.key(book: original.book, lesson: original.book.lessons[1])
        var update = original; update.collectionRevision = 2
        var changed = original.book.lessons[1]; changed.revision = 2; changed.title = "Revised idea"
        var added = original.book.lessons[0]; added.id = "added"
        update.book.lessons = [changed, added, original.book.lessons[0]]
        update.manifest = update.book.lessons.map { IdeaManifestEntry(id: $0.id, revision: $0.revision) }
        update.removedLessonIDs = [original.book.lessons[2].id]
        await f.store.prepareImport(from: try f.file(update))
        let review = try XCTUnwrap(f.store.importReview)
        XCTAssertEqual(review.unchanged.count, 1); XCTAssertEqual(review.revised.count, 1)
        XCTAssertEqual(review.removed.count, 1); XCTAssertEqual(review.added.count, 1)
        await f.store.commitImport(review)
        XCTAssertNotNil(f.store.errorMessage)
        XCTAssertEqual(f.store.package(for: original.book)?.collectionNumber, 1)
        await f.store.commitImport(review, acknowledgeRemovals: true)
        await f.store.flush()
        XCTAssertNil(f.store.errorMessage)
        XCTAssertEqual(f.store.status(book: update.book, lesson: update.book.lessons[2]).pageIndex, 3)
        let revised = f.store.status(book: update.book, lesson: changed)
        XCTAssertTrue(revised.updated); XCTAssertEqual(revised.pageIndex, 0); XCTAssertNil(revised.practice.selectedID)
        XCTAssertEqual(f.store.continueLearning?.lesson.id, changed.id)
        XCTAssertEqual(f.store.continueLearning?.position, "Updated · review this idea again")
        XCTAssertEqual(f.store.progress[oldKey]?.pageIndex, 3)
        XCTAssertEqual(f.store.status(book: original.book, lesson: original.book.lessons[2]).pageIndex, 3)
        // Reinstatement with an unchanged revision recovers its archived state.
        var restored = update; restored.collectionRevision = 3; restored.book.lessons.append(original.book.lessons[2]); restored.removedLessonIDs = []
        restored.manifest = restored.book.lessons.map { IdeaManifestEntry(id: $0.id, revision: $0.revision) }
        try await f.commit(restored)
        XCTAssertEqual(f.store.status(book: restored.book, lesson: original.book.lessons[2]).pageIndex, 3)
    }

    @MainActor func testRevisionRulesAndDeterministicContentComparison() async throws {
        let f = try await CollectionFixture.make(); addTeardownBlock { await f.cleanup() }
        let original = f.multiIdea(); try await f.commit(original)
        let catalog = f.store.catalog
        var metadata = original; metadata.collectionRevision = 2; metadata.book.synopsis += " Updated description."
        XCTAssertEqual(try CollectionComparison.review(metadata, catalog: catalog).unchanged.count, 3)
        var invalid = original; invalid.book.title += " Changed"
        XCTAssertThrowsError(try CollectionComparison.review(invalid, catalog: catalog))
        invalid = original; invalid.collectionRevision = 0
        XCTAssertThrowsError(try CollectionComparison.review(invalid, catalog: catalog))
        invalid = original; invalid.collectionRevision = 2; invalid.book.lessons[0].pages[1].text += " Changed."
        XCTAssertThrowsError(try CollectionComparison.review(invalid, catalog: catalog))
        invalid = original; invalid.collectionRevision = 2; invalid.book.lessons[0].revision = 0
        XCTAssertThrowsError(try CollectionComparison.review(invalid, catalog: catalog))
        invalid = original; invalid.collectionRevision = 2; invalid.book.lessons.removeLast(); invalid.manifest?.removeLast()
        XCTAssertThrowsError(try CollectionComparison.review(invalid, catalog: catalog))
        invalid = original; invalid.collectionRevision = 2
        let key = try XCTUnwrap(invalid.assets?.keys.first)
        invalid.assets?[key]?.data.append(0)
        XCTAssertThrowsError(try CollectionComparison.review(invalid, catalog: catalog), "Illustration bytes are content, not just asset IDs")
        let pretty = JSONEncoder(); pretty.outputFormatting = [.prettyPrinted, .sortedKeys]
        let reordered = try JSONDecoder().decode(LessonPackage.self, from: pretty.encode(original))
        XCTAssertTrue(try CollectionComparison.review(reordered, catalog: catalog).alreadyImported)
    }

    @MainActor func testValidatorRejectsIncompleteDuplicateMissingAndOversizedAssets() async throws {
        let f = try await CollectionFixture.make(); addTeardownBlock { await f.cleanup() }
        let package = f.multiIdea()
        var invalid = package; invalid.manifest?.removeLast(); XCTAssertThrowsError(try invalid.validated())
        invalid = package; invalid.book.lessons[1].id = invalid.book.lessons[0].id; XCTAssertThrowsError(try invalid.validated())
        invalid = package; invalid.book.lessons[0].pages[0].sourceIDs = ["unknown"]; XCTAssertThrowsError(try invalid.validated())
        invalid = package; invalid.fullCollection = false; XCTAssertThrowsError(try invalid.validated())
        invalid = package; invalid.assets = [:]; XCTAssertThrowsError(try invalid.validated())
        invalid = package; invalid.book.coverAssetID = "missing"; invalid.book.coverDescription = "Cover"; XCTAssertThrowsError(try invalid.validated())
        invalid = package; invalid.formatVersion = 1; XCTAssertThrowsError(try invalid.validated())
        let oversize = CollectionArtwork(mediaType: "image/png", data: Data(count: CollectionLimits.assetBytes + 1))
        XCTAssertThrowsError(try CollectionLimits.validateImage(oversize))
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 2049, height: 1), format: UIGraphicsImageRendererFormat.default())
        let data = renderer.pngData { $0.cgContext.fill(CGRect(x: 0, y: 0, width: 2049, height: 1)) }
        XCTAssertThrowsError(try CollectionLimits.validateImage(CollectionArtwork(mediaType: "image/png", data: data)))
        XCTAssertThrowsError(try LessonPackage.decodeImport(Data("{malformed".utf8)))
    }

    @MainActor func testFailedWriteLeavesCollectionAndProgressUsableAfterRelaunch() async throws {
        let f = try await CollectionFixture.make(); addTeardownBlock { await f.cleanup() }
        let lesson = f.package.book.lessons[0]
        f.store.update(book: f.package.book, lesson: lesson) { $0.pageIndex = 4 }
        await f.store.flush()
        await f.store.storage.setWriteFailure(true)
        try await f.commit(f.multiIdea())
        XCTAssertNotNil(f.store.errorMessage); XCTAssertEqual(f.store.books.count, 1)
        let reload = LibraryStore(documentsURL: f.directory, defaults: f.defaults, initialPackage: f.package)
        await reload.ready()
        XCTAssertEqual(reload.books.count, 1); XCTAssertEqual(reload.status(book: f.package.book, lesson: lesson).pageIndex, 4)
        await f.store.storage.setWriteFailure(false)
    }

    @MainActor func testLegacyMigrationKeepsProgressAndCorruptContentDoesNotEraseIt() async throws {
        let f = try await CollectionFixture.make(); addTeardownBlock { await f.cleanup() }
        let directory = f.directory.appendingPathComponent("legacy")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let key = LessonProgress.key(bookID: f.package.book.id, lesson: f.package.book.lessons[0])
        let legacyData = try JSONSerialization.data(withJSONObject: [key: ["pageIndex": 4, "readComplete": true, "practiceComplete": false, "firstTryCorrect": 0, "questionCount": 0]])
        f.defaults.set(legacyData, forKey: "lessonProgress.v1")
        let legacyFile = directory.appendingPathComponent("imported-books.json")
        try Data("unreadable content".utf8).write(to: legacyFile)
        let recovered = LibraryStore(documentsURL: directory, defaults: f.defaults, initialPackage: f.package)
        await recovered.ready()
        XCTAssertEqual(recovered.progress[key]?.pageIndex, 4)
        XCTAssertTrue(recovered.readOnly)
        recovered.update(book: f.package.book, lesson: f.package.book.lessons[0]) { $0.pageIndex = 0 }
        XCTAssertEqual(recovered.progress[key]?.pageIndex, 4)
        XCTAssertEqual(f.defaults.data(forKey: "lessonProgress.v1"), legacyData)
        XCTAssertEqual(try String(contentsOf: legacyFile), "unreadable content")
        // A clean migration creates one committed snapshot without changing old keys.
        let cleanDirectory = f.directory.appendingPathComponent("clean")
        let migrated = LibraryStore(documentsURL: cleanDirectory, defaults: f.defaults, initialPackage: f.package)
        await migrated.ready()
        XCTAssertEqual(migrated.progress[key]?.pageIndex, 4); XCTAssertFalse(migrated.readOnly)
        XCTAssertTrue(FileManager.default.fileExists(atPath: cleanDirectory.appendingPathComponent("Library-v2/CURRENT.json").path))
    }

    @MainActor func testSnapshotProgressRecoversIndependentlyAndUncommittedDirectoryIsIgnored() async throws {
        let f = try await CollectionFixture.make(); addTeardownBlock { await f.cleanup() }
        let lesson = f.package.book.lessons[0]
        f.store.update(book: f.package.book, lesson: lesson) { $0.pageIndex = 5 }
        await f.store.flush()
        let root = f.directory.appendingPathComponent("Library-v2")
        let pointer = try JSONDecoder().decode(CollectionStorage.Pointer.self, from: Data(contentsOf: root.appendingPathComponent("CURRENT.json")))
        // Replace rather than edit a shared hard link; only this committed copy is damaged.
        try Data("broken".utf8).write(to: root.appendingPathComponent(pointer.current).appendingPathComponent("collections.json"), options: .atomic)
        let orphan = root.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: orphan, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: orphan.appendingPathComponent("progress.json"))
        let reload = LibraryStore(documentsURL: f.directory, defaults: f.defaults, initialPackage: f.package)
        await reload.ready()
        XCTAssertEqual(reload.status(book: f.package.book, lesson: lesson).pageIndex, 5)
        XCTAssertEqual(reload.books.count, 1); XCTAssertFalse(reload.readOnly)
        XCTAssertNotNil(reload.errorMessage)
        XCTAssertEqual(try String(contentsOf: root.appendingPathComponent(pointer.current).appendingPathComponent("collections.json")), "broken")
        reload.update(book: f.package.book, lesson: lesson) { $0.pageIndex = 6 }
        await reload.flush()
        let savedAgain = LibraryStore(documentsURL: f.directory, defaults: f.defaults, initialPackage: f.package)
        await savedAgain.ready()
        XCTAssertEqual(savedAgain.status(book: f.package.book, lesson: lesson).pageIndex, 6)
        XCTAssertEqual(try String(contentsOf: root.appendingPathComponent(pointer.current).appendingPathComponent("collections.json")), "broken")
    }

    @MainActor func testMaximumRepresentativeCollectionImportKeepsMainActorResponsive() async throws {
        let f = try await CollectionFixture.make(empty: true); addTeardownBlock { await f.cleanup() }
        var package = f.multiIdea(count: 100)
        let imageKey = try XCTUnwrap(package.assets?.keys.sorted().first)
        let image = try XCTUnwrap(package.assets?[imageKey])
        package.assets = Dictionary(uniqueKeysWithValues: (0..<32).map { ("shared-\($0)", image) })
        for i in package.book.lessons.indices {
            let original = package.book.lessons[i].pages
            package.book.lessons[i].pages = (0..<40).map { j in
                var page = original[j == 0 ? 0 : j == 39 ? original.count - 1 : 1]
                page.id = "page-\(j)"; page.imageID = "shared-\(j % 32)"; page.imageDescription = "Verification illustration"
                return page
            }
        }
        let url = try f.file(package)
        let started = Date()
        var ticks = 0
        let heartbeat = Task { @MainActor in
            while !Task.isCancelled { ticks += 1; try? await Task.sleep(nanoseconds: 10_000_000) }
        }
        await f.store.prepareImport(from: url)
        XCTAssertNil(f.store.errorMessage); XCTAssertEqual(f.store.importReview?.package.book.lessons.count, 100)
        let review = try XCTUnwrap(f.store.importReview)
        await f.store.commitImport(review)
        await f.store.flush()
        heartbeat.cancel()
        XCTAssertNil(f.store.errorMessage)
        XCTAssertEqual(f.store.books.first?.lessons.count, 100)
        let reloaded = LibraryStore(documentsURL: f.directory, defaults: f.defaults, includeDemo: false)
        await reloaded.ready()
        XCTAssertEqual(reloaded.books.first?.lessons.count, 100)
        XCTAssertEqual(reloaded.books.first?.lessons.last?.pages.count, 40)
        XCTAssertGreaterThan(ticks, 2, "Main actor should keep responding during collection validation")
        print("REPRESENTATIVE_COLLECTION bytes=\(try Data(contentsOf: url).count) ideas=100 pagesPerIdea=40 assets=32 seconds=\(Date().timeIntervalSince(started)) mainActorTicks=\(ticks)")
    }
}

extension CollectionTests {
    @MainActor func testInstalledLegacyCollectionReadableButFreshLegacyImportRejected() async throws {
        let f = try await CollectionFixture.make(); addTeardownBlock { await f.cleanup() }
        var legacy = f.package
        legacy.formatVersion = 1; legacy.collectionRevision = nil; legacy.fullCollection = nil
        legacy.manifest = nil; legacy.assets = nil; legacy.removedLessonIDs = nil
        legacy.book.id = "legacy-book"
        for index in legacy.book.lessons[0].pages.indices {
            if legacy.book.lessons[0].pages[index].imageID != nil {
                legacy.book.lessons[0].pages[index].imageID = nil
                legacy.book.lessons[0].pages[index].imageAsset = "priors-setup"
            }
        }
        let directory = f.directory.appendingPathComponent("legacy-readable")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode([legacy]).write(to: directory.appendingPathComponent("imported-books.json"))
        let migrated = LibraryStore(documentsURL: directory, defaults: f.defaults, initialPackage: f.package)
        await migrated.ready()
        XCTAssertNil(migrated.errorMessage)
        XCTAssertEqual(migrated.books.count, 2)
        XCTAssertEqual(migrated.package(for: legacy.book)?.formatVersion, 1)
        await migrated.prepareImport(from: try f.file(legacy))
        XCTAssertNil(migrated.importReview)
        XCTAssertTrue(migrated.errorMessage?.contains("formatVersion 2") == true)
        await migrated.flush()
    }

    @MainActor func testUnreadableProgressIsPreservedAndNeverOverwrittenWithEmptyState() async throws {
        let f = try await CollectionFixture.make(); addTeardownBlock { await f.cleanup() }
        let root = f.directory.appendingPathComponent("Library-v2")
        let pointer = try JSONDecoder().decode(CollectionStorage.Pointer.self, from: Data(contentsOf: root.appendingPathComponent("CURRENT.json")))
        let file = root.appendingPathComponent(pointer.current).appendingPathComponent("progress.json")
        try Data("unreadable progress".utf8).write(to: file, options: .atomic)
        let reloaded = LibraryStore(documentsURL: f.directory, defaults: f.defaults, initialPackage: f.package)
        await reloaded.ready()
        XCTAssertTrue(reloaded.readOnly); XCTAssertEqual(reloaded.books.count, 1)
        reloaded.update(book: f.package.book, lesson: f.package.book.lessons[0]) { $0.pageIndex = 2 }
        await reloaded.flush()
        XCTAssertEqual(try String(contentsOf: file), "unreadable progress")
        XCTAssertEqual(try JSONDecoder().decode(CollectionStorage.Pointer.self, from: Data(contentsOf: root.appendingPathComponent("CURRENT.json"))).current, pointer.current)
    }
}
