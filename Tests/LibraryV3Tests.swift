import XCTest
@testable import LifeIsLearned

@MainActor final class LibraryV3Tests: XCTestCase {
    private func data<T: Encodable>(_ value: T) throws -> Data {
        let e = JSONEncoder(); e.outputFormatting = [.sortedKeys]; return try e.encode(value)
    }
    private func complete(_ package: LessonPackage, in store: LibraryStore) async {
        for lesson in package.book.lessons {
            store.update(book: package.book, lesson: lesson) {
                $0.practiceComplete = true; $0.readComplete = true; $0.phase = .complete
                $0.firstTryCorrect = 1; $0.questionCount = 2
                $0.practicedAt = Date(timeIntervalSince1970: 1_780_000_000)
            }
        }
        if let card = store.cards.values.first { store.toggleFavorite(card.id) }
        await store.flush()
    }

    func testSymlinkedDocumentsCleanupPreservesInstalledAndPreviousPayloadsAcrossLaunches() async throws {
        let f = try await CollectionFixture.make(); addTeardownBlock { await f.cleanup() }
        let actual = f.directory.appendingPathComponent("actual-documents-with-a-long-name")
        let alias = f.directory.appendingPathComponent("docs")
        try FileManager.default.createDirectory(at: actual, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: actual)
        let storage = LibraryStorage(documents: alias)
        let initial = await storage.load(seed: f.package, seedURL: nil, legacyProgress: nil)
        XCTAssertFalse(initial.readOnly)
        let original = try XCTUnwrap(initial.installed.first)
        var updated = f.package; updated.collectionRevision = 2
        updated.book.lessons[0].revision += 1; updated.book.lessons[0].title += " updated"
        updated.manifest = updated.book.lessons.map { IdeaManifestEntry(id: $0.id, revision: $0.revision) }
        var catalog = initial.catalog; catalog.packages = [updated]; catalog.version = UUID(); try catalog.record(updated)
        let history = [BookHistoryRecord.refresh(updated, progress: initial.progress, source: .manual, previous: initial.history.first)]
        let installed = try await storage.save(catalog: catalog, progress: initial.progress, cards: initial.cards, history: history)
        let current = try XCTUnwrap(installed.first)
        let root = actual.appendingPathComponent("Library-v3")
        let currentURL = root.appendingPathComponent(current.packageFile)
        let previousURL = root.appendingPathComponent(original.packageFile)
        XCTAssertTrue(FileManager.default.fileExists(atPath: currentURL.path), "Cleanup must retain the installed file through a symlinked Documents path")
        XCTAssertTrue(FileManager.default.fileExists(atPath: previousURL.path), "Previous committed state remains recoverable")
        let orphan = currentURL.deletingLastPathComponent().appendingPathComponent("unreferenced.json")
        try Data("orphan".utf8).write(to: orphan)
        try await storage.garbageCollect()
        XCTAssertFalse(FileManager.default.fileExists(atPath: orphan.path))
        XCTAssertEqual(LibraryDigest.sha256(try Data(contentsOf: currentURL)), current.packageSHA256)
        XCTAssertEqual(LibraryDigest.sha256(try Data(contentsOf: previousURL)), original.packageSHA256)
        for _ in 0..<4 {
            let next = LibraryStorage(documents: alias)
            let loaded = await next.load(seed: nil, seedURL: nil, legacyProgress: nil)
            XCTAssertFalse(loaded.readOnly, loaded.warning ?? "")
            XCTAssertNil(loaded.warning); XCTAssertEqual(loaded.catalog.packages.count, 1)
            XCTAssertEqual(try data(loaded.progress), try data(initial.progress))
            XCTAssertEqual(try data(loaded.cards), try data(initial.cards))
            try await next.confirmLaunch()
            _ = try await next.save(catalog: loaded.catalog, progress: loaded.progress, cards: loaded.cards, history: loaded.history)
        }
        let final = await LibraryStorage(documents: alias).load(seed: nil, seedURL: nil, legacyProgress: nil)
        XCTAssertFalse(final.readOnly); XCTAssertEqual(final.installed.first?.packageSHA256, current.packageSHA256)
    }

    func testSymlinkedDocumentsFailedOffloadKeepsActivePayloadAndSuccessReclaimsIt() async throws {
        let f = try await CollectionFixture.make(); addTeardownBlock { await f.cleanup() }
        let actual = f.directory.appendingPathComponent("offload-real-documents")
        let alias = f.directory.appendingPathComponent("alias")
        try FileManager.default.createDirectory(at: actual, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: actual)
        let storage = LibraryStorage(documents: alias)
        let initial = await storage.load(seed: f.package, seedURL: nil, legacyProgress: nil)
        let record = try XCTUnwrap(initial.installed.first)
        let payload = actual.appendingPathComponent("Library-v3/" + record.packageFile)
        await storage.setFault(.deletion)
        do {
            _ = try await storage.offload(bookID: f.package.book.id, catalog: initial.catalog,
                progress: initial.progress, cards: initial.cards, history: initial.history)
            XCTFail("Injected deletion failure")
        } catch { }
        XCTAssertEqual(LibraryDigest.sha256(try Data(contentsOf: payload)), record.packageSHA256)
        let reloaded = await LibraryStorage(documents: alias).load(seed: nil, seedURL: nil, legacyProgress: nil)
        XCTAssertFalse(reloaded.readOnly); XCTAssertEqual(reloaded.installed.count, 1)
        await storage.setFault(nil)
        _ = try await storage.offload(bookID: f.package.book.id, catalog: initial.catalog,
            progress: initial.progress, cards: initial.cards, history: initial.history)
        let bytes = try await storage.packageBytes(bookID: f.package.book.id)
        XCTAssertEqual(bytes, 0)
    }

    func testGarbageCollectionFailsClosedForInvalidReferenceBeforeDeletingAnything() async throws {
        let f = try await CollectionFixture.make(); addTeardownBlock { await f.cleanup() }
        let root = f.directory.appendingPathComponent("Library-v3")
        let pointer = try JSONDecoder().decode(LibraryStorage.Pointer.self, from: Data(contentsOf: root.appendingPathComponent("CURRENT.json")))
        let stateURL = root.appendingPathComponent("StateSnapshots/\(pointer.current)/library-state.json")
        var state = try JSONDecoder().decode(LibraryState.self, from: Data(contentsOf: stateURL))
        let installed = root.appendingPathComponent(try XCTUnwrap(state.installed.first).packageFile)
        let orphan = installed.deletingLastPathComponent().appendingPathComponent("unreferenced.json")
        try Data("keep until references validate".utf8).write(to: orphan)
        state.installed[0].packageFile = "../../outside.json"
        try data(state).write(to: stateURL)
        do { try await f.store.storage.garbageCollect(); XCTFail("Invalid references must stop cleanup") } catch { }
        XCTAssertTrue(FileManager.default.fileExists(atPath: installed.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: orphan.path))
    }

    func testOffloadReclaimsPayloadAndReinstallPreservesState() async throws {
        let f = try await CollectionFixture.make(); addTeardownBlock { await f.cleanup() }
        await complete(f.package, in: f.store)
        let cards = try data(f.store.cards), progress = try data(f.store.progress), history = try data(f.store.history)
        let bytes = try await f.store.storage.packageBytes(bookID: f.package.book.id)
        XCTAssertGreaterThan(bytes, 500_000, "Art-heavy deterministic bundled fixture")
        XCTAssertEqual(bytes, try f.package.canonicalData().count)
        let succeeded = await f.store.offload(f.package.book)
        XCTAssertTrue(succeeded, f.store.errorMessage ?? "")
        let remaining = try await f.store.storage.packageBytes(bookID: f.package.book.id)
        XCTAssertEqual(remaining, 0)
        XCTAssertTrue(f.store.books.isEmpty)
        XCTAssertEqual(try data(f.store.cards), cards); XCTAssertEqual(try data(f.store.progress), progress)
        XCTAssertEqual(try data(f.store.history), history)
        let stateAfterOffload = ["cards": try JSONSerialization.jsonObject(with: data(f.store.cards)),
                                 "progress": try JSONSerialization.jsonObject(with: data(f.store.progress)),
                                 "history": try JSONSerialization.jsonObject(with: data(f.store.history))]
        let reload = LibraryStore(documentsURL: f.directory, defaults: f.defaults, includeDemo: true)
        await reload.ready()
        XCTAssertTrue(reload.books.isEmpty, "Offloaded demo must not be automatically reinstalled")
        XCTAssertEqual(try data(reload.cards), cards); XCTAssertEqual(try data(reload.progress), progress)
        try await f.commit(f.package)
        XCTAssertNil(f.store.errorMessage)
        XCTAssertEqual(f.store.cards.count, 1)
        XCTAssertNil(f.store.history.first?.firstSeenAt, "Unknown original first-seen date is not fabricated on re-import")
        XCTAssertEqual(try data(f.store.cards), cards); XCTAssertEqual(try data(f.store.progress), progress)
        XCTAssertEqual(try data(f.store.history), history)
        XCTAssertEqual(f.store.history.first?.firstCompletedAt, Date(timeIntervalSince1970: 1_780_000_000))
        let afterReinstall = try await f.store.storage.packageBytes(bookID: f.package.book.id)
        XCTAssertEqual(afterReinstall, bytes)
        let report: [String: Any] = ["fixture": "bundled starter artwork, isolated temporary installation", "installedPayloadBytes": bytes,
            "offloadedPayloadBytes": remaining, "reinstalledPayloadBytes": afterReinstall,
            "cardsSHA256": LibraryDigest.sha256(cards), "progressSHA256": LibraryDigest.sha256(progress),
            "historySHA256": LibraryDigest.sha256(history), "cardCountAfterReinstall": f.store.cards.count]
        let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]), uniformTypeIdentifier: "public.json")
        attachment.name = "h005b-storage-proof"; attachment.lifetime = .keepAlways; add(attachment)
        let states: [String: Any] = ["before": ["cards": try JSONSerialization.jsonObject(with: cards),
            "progress": try JSONSerialization.jsonObject(with: progress), "history": try JSONSerialization.jsonObject(with: history)],
            "afterOffload": stateAfterOffload, "afterReinstall": ["cards": try JSONSerialization.jsonObject(with: data(f.store.cards)),
            "progress": try JSONSerialization.jsonObject(with: data(f.store.progress)), "history": try JSONSerialization.jsonObject(with: data(f.store.history))]]
        let stateEvidence = XCTAttachment(data: try JSONSerialization.data(withJSONObject: states, options: [.prettyPrinted, .sortedKeys]), uniformTypeIdentifier: "public.json")
        stateEvidence.name = "h005b-learner-state"; stateEvidence.lifetime = .keepAlways; add(stateEvidence)
    }

    func testFailedOffloadAndInterruptedOffloadRecoverAtomically() async throws {
        for fault in [LibraryStorage.Fault.deletion, .offloadAfterJournal, .offloadAfterPointer, .offloadAfterDeletion] {
            let f = try await CollectionFixture.make(); addTeardownBlock { await f.cleanup() }
            await complete(f.package, in: f.store)
            let cards = try data(f.store.cards), progress = try data(f.store.progress)
            await f.store.storage.setFault(fault)
            let result = await f.store.offload(f.package.book)
            XCTAssertFalse(result)
            let reload = LibraryStore(documentsURL: f.directory, defaults: f.defaults, includeDemo: false)
            await reload.ready()
            XCTAssertNil(reload.errorMessage); XCTAssertFalse(reload.readOnly)
            XCTAssertEqual(reload.books.isEmpty, fault == .offloadAfterDeletion)
            XCTAssertEqual(try data(reload.cards), cards); XCTAssertEqual(try data(reload.progress), progress)
            let bytes = try await reload.storage.packageBytes(bookID: f.package.book.id)
            XCTAssertEqual(bytes == 0, fault == .offloadAfterDeletion)
            if fault == .deletion { XCTAssertEqual(f.store.books.count, 1) }
        }
    }

    func testV2MigrationInterruptionRoundTripAndVerifiedCleanup() async throws {
        let f = try await CollectionFixture.make(); addTeardownBlock { await f.cleanup() }
        let dir = f.directory.appendingPathComponent("v2-migration")
        let legacy = CollectionStorage(documents: dir)
        var initial = await legacy.load(seed: f.package, seedURL: nil, legacyProgress: nil)
        let lesson = f.package.book.lessons[0]
        var done = LessonProgress(); done.practiceComplete = true; done.practicedAt = Date(timeIntervalSince1970: 1_780_000_000)
        initial.progress[LessonProgress.key(bookID: f.package.book.id, lesson: lesson)] = done
        IdeaCardRecord.earn(book: f.package.book, lesson: lesson, date: done.practicedAt, into: &initial.cards)
        let id = try XCTUnwrap(initial.cards.keys.first); initial.cards[id]?.isFavorite = true
        try await legacy.save(catalog: initial.catalog, progress: initial.progress, cards: initial.cards)
        let oldRoot = dir.appendingPathComponent("Library-v2")
        let oldPointer = try Data(contentsOf: oldRoot.appendingPathComponent("CURRENT.json"))
        func v2Tree() throws -> [String: String] {
            var result: [String: String] = [:]
            let files = FileManager.default.enumerator(at: oldRoot, includingPropertiesForKeys: [.isRegularFileKey])!
            for case let url as URL in files where try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
                result[String(url.path.dropFirst(oldRoot.path.count))] = LibraryDigest.sha256(try Data(contentsOf: url))
            }
            return result
        }
        let beforeV2 = try v2Tree()
        let storage = LibraryStorage(documents: dir)
        await storage.setFault(.migrationBeforePublication)
        let blocked = await storage.load(seed: nil, seedURL: nil, legacyProgress: nil)
        XCTAssertTrue(blocked.readOnly)
        XCTAssertEqual(try Data(contentsOf: oldRoot.appendingPathComponent("CURRENT.json")), oldPointer)
        XCTAssertEqual(try v2Tree(), beforeV2, "Every v2 byte remains unchanged before publication")
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent("Library-v3/CURRENT.json").path))
        let stillReadable = await legacy.load(seed: nil, seedURL: nil, legacyProgress: nil)
        XCTAssertEqual(try data(stillReadable.cards), try data(initial.cards))
        await storage.setFault(nil)
        let migrated = await storage.load(seed: nil, seedURL: nil, legacyProgress: nil)
        XCTAssertFalse(migrated.readOnly, migrated.warning ?? "")
        XCTAssertEqual(try data(migrated.cards), try data(initial.cards)); XCTAssertEqual(try data(migrated.progress), try data(initial.progress))
        XCTAssertEqual(migrated.installed.map(\.bookID), initial.catalog.packages.map { $0.book.id })
        try await storage.confirmLaunch()
        XCTAssertTrue(FileManager.default.fileExists(atPath: oldRoot.path), "First publication cannot remove v2")
        let nextLaunch = LibraryStorage(documents: dir)
        let loaded = await nextLaunch.load(seed: nil, seedURL: nil, legacyProgress: nil)
        XCTAssertEqual(try data(loaded.cards), try data(initial.cards))
        try await nextLaunch.confirmLaunch()
        XCTAssertFalse(FileManager.default.fileExists(atPath: oldRoot.path))
        let pointer = try JSONDecoder().decode(LibraryStorage.Pointer.self, from: Data(contentsOf: dir.appendingPathComponent("Library-v3/CURRENT.json")))
        let metadata = try String(contentsOf: dir.appendingPathComponent("Library-v3/StateSnapshots/\(pointer.current)/library-state.json"))
        XCTAssertFalse(metadata.contains("base64")); XCTAssertFalse(metadata.contains("coverageNote")); XCTAssertFalse(metadata.contains("pages"))
        XCTAssertLessThan(metadata.utf8.count, 10_000)
    }

    func testHistoryOrderingCompletionDatesAndSourceRecovery() async throws {
        let f = try await CollectionFixture.make(empty: true); addTeardownBlock { await f.cleanup() }
        let first = f.multiIdea(count: 2); try await f.commit(first); await complete(first, in: f.store)
        var second = first; second.book.id = "second-history-book"
        var review = try await f.store.storage.review(package: second, catalog: f.store.catalog)
        review.source = BookSourceRecord(kind: .remoteCatalog, catalogID: "catalog-001", catalogURL: URL(string: "https://example.test/catalog.json"))
        await f.store.commitImport(review); await complete(second, in: f.store)
        let before = IdeaCardCollection.ordered(Array(f.store.cards.values), books: f.store.books, sort: .book, history: f.store.history).map(\.id)
        let offloaded = await f.store.offload(first.book); XCTAssertTrue(offloaded)
        let after = IdeaCardCollection.ordered(Array(f.store.cards.values), books: f.store.books, sort: .book, history: f.store.history).map(\.id)
        XCTAssertEqual(before, after)
        XCTAssertEqual(f.store.source(for: first.book.id).restoreTitle, "Re-import book")
        XCTAssertEqual(f.store.source(for: second.book.id).restoreTitle, "Download current book")
        var update = first; update.collectionRevision = first.collectionNumber + 1
        update.book.lessons[0].revision += 1; update.book.lessons[0].title += " revised"
        update.manifest = update.book.lessons.map { IdeaManifestEntry(id: $0.id, revision: $0.revision) }
        try await f.commit(update)
        let history = try XCTUnwrap(f.store.history.first { $0.bookID == first.book.id })
        XCTAssertEqual(history.firstCompletedAt, Date(timeIntervalSince1970: 1_780_000_000))
        XCTAssertTrue(history.hasUpdates); XCTAssertEqual(history.lastKnownPracticedCount, 1)
        XCTAssertEqual(f.store.cards.count, 4)
    }

    func testUnknownHistoricalCompletionDateSurvivesLaterRevision() async throws {
        let f = try await CollectionFixture.make(); addTeardownBlock { await f.cleanup() }
        var done = LessonProgress(); done.practiceComplete = true
        let original = f.package
        let oldProgress = [LessonProgress.key(bookID: original.book.id, lesson: original.book.lessons[0]): done]
        let before = BookHistoryRecord.refresh(original, progress: oldProgress, source: .manual, previous: nil)
        XCTAssertTrue(before.hasCompletedBefore == true); XCTAssertNil(before.firstCompletedAt)
        var update = original; update.book.lessons[0].revision += 1; update.collectionRevision = original.collectionNumber + 1
        let pending = BookHistoryRecord.refresh(update, progress: oldProgress, source: .manual, previous: before, seenAt: Date())
        XCTAssertTrue(pending.hasUpdates); XCTAssertNil(pending.firstSeenAt)
        done.practicedAt = Date()
        let newProgress = [LessonProgress.key(bookID: update.book.id, lesson: update.book.lessons[0]): done]
        let after = BookHistoryRecord.refresh(update, progress: newProgress, source: .manual, previous: pending)
        XCTAssertNil(after.firstCompletedAt, "A later revision cannot invent an earlier completion date")
        XCTAssertTrue(after.hasCompletedBefore == true); XCTAssertFalse(after.hasUpdates)
    }

    func testOffloadCannotBypassRevisionOrRemovalRulesAndGCProtectsInstalledFiles() async throws {
        let f = try await CollectionFixture.make(empty: true); addTeardownBlock { await f.cleanup() }
        var original = f.multiIdea(); original.collectionRevision = 2
        try await f.commit(original)
        let result = await f.store.offload(original.book); XCTAssertTrue(result)
        var downgrade = original; downgrade.collectionRevision = 1
        do { _ = try await f.store.storage.review(package: downgrade, catalog: f.store.catalog); XCTFail("Downgrade") } catch { }
        var changed = original; changed.book.title += " changed"
        do { _ = try await f.store.storage.review(package: changed, catalog: f.store.catalog); XCTFail("Same revision changed") } catch { }
        changed = original; changed.collectionRevision = 3; let removed = changed.book.lessons.removeLast()
        changed.manifest = changed.book.lessons.map { IdeaManifestEntry(id: $0.id, revision: $0.revision) }
        do { _ = try await f.store.storage.review(package: changed, catalog: f.store.catalog); XCTFail("Missing removal declaration") } catch { }
        changed.removedLessonIDs = [removed.id]
        let review = try await f.store.storage.review(package: changed, catalog: f.store.catalog)
        XCTAssertEqual(review.removed.map(\.id), [removed.id])
        await f.store.commitImport(review); XCTAssertTrue(f.store.books.isEmpty)
        await f.store.commitImport(review, acknowledgeRemovals: true); await f.store.flush()
        XCTAssertEqual(f.store.books.count, 1)
        let record = try XCTUnwrap(f.store.installed.first)
        let root = f.directory.appendingPathComponent("Library-v3")
        let referenced = root.appendingPathComponent(record.packageFile)
        let orphan = referenced.deletingLastPathComponent().appendingPathComponent("unused.json")
        try Data("orphan".utf8).write(to: orphan)
        try await f.store.storage.garbageCollect()
        XCTAssertFalse(FileManager.default.fileExists(atPath: orphan.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: referenced.path))
    }
}
