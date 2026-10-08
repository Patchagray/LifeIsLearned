import Foundation

/// V3 owns removable payload separately from immutable, lightweight learner snapshots.
/// V2 is used only as a read-only migration source until a verified v3 launch.
actor LibraryStorage {
    struct Pointer: Codable { var schemaVersion = 3; var current: String; var previous: String? }
    struct OffloadJournal: Codable { var old: Pointer; var next: Pointer; var packageFile: String }
    enum Fault { case write, migrationBeforePublication, deletion, offloadAfterJournal, offloadAfterPointer, offloadAfterDeletion }
    let documents: URL
    let root: URL
    private let manager = FileManager.default
    private let legacy: CollectionStorage
    private var fault: Fault?
    private var cachedVersion: UUID?
    private var cachedInstalled: [InstalledBookRecord] = []
    private var canCleanLegacy = false

    init(documents: URL) {
        self.documents = documents; root = documents.appendingPathComponent("Library-v3", isDirectory: true)
        legacy = CollectionStorage(documents: documents)
    }
    func setWriteFailure(_ value: Bool) { fault = value ? .write : nil }
    func setFault(_ value: Fault?) { fault = value }
    private var currentURL: URL { root.appendingPathComponent("CURRENT.json") }
    private var journalURL: URL { root.appendingPathComponent("OFFLOAD.json") }
    private func snapshotDirectory(_ id: String) throws -> URL {
        try CollectionLimits.require(UUID(uuidString: id) != nil, "Invalid library snapshot identity.")
        return root.appendingPathComponent("StateSnapshots/" + id, isDirectory: true)
    }
    private func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }
    private func read<T: Decodable>(_ type: T.Type, _ url: URL) throws -> T {
        try JSONDecoder().decode(type, from: Data(contentsOf: url))
    }
    private func pointer() throws -> Pointer {
        let p = try read(Pointer.self, currentURL)
        try CollectionLimits.require(p.schemaVersion == 3, "Unsupported library-state version.")
        _ = try snapshotDirectory(p.current)
        if let previous = p.previous { _ = try snapshotDirectory(previous) }
        return p
    }
    private func payloadURL(_ path: String) throws -> URL {
        // Stable book IDs never become filesystem paths. All path components are generated hashes.
        let pattern = #"^Packages/[a-f0-9]{64}/[0-9]+-[a-f0-9]{64}\.(json|lilbook)$"#
        try CollectionLimits.require(path.range(of: pattern, options: .regularExpression) != nil, "Invalid package reference.")
        return root.appendingPathComponent(path)
    }

    func load(seed: LessonPackage?, seedURL: URL?, legacyProgress: Data?) async -> LibrarySnapshot {
        do {
            try recoverOffload()
            if manager.fileExists(atPath: currentURL.path) {
                let result = try loadCurrent()
                canCleanLegacy = !result.readOnly && result.warning == nil
                return result
            }
        } catch {
            return LibrarySnapshot(catalog: CollectionCatalog(packages: []), progress: [:],
                                   warning: "The library index needs recovery. Original files are preserved. \(error.localizedDescription)", readOnly: true)
        }
        var old = await legacy.load(seed: seed, seedURL: seedURL, legacyProgress: legacyProgress, saveMigratedCards: false)
        guard !old.readOnly else { return old }
        do {
            old.catalog.knownBooks = old.catalog.knownBooks ?? [:]
            for package in old.catalog.packages { try old.catalog.record(package) }
            old.history = old.catalog.packages.map {
                BookHistoryRecord.refresh($0, progress: old.progress, source: .manual, previous: nil)
            }
            let prepared = try prepareSnapshot(catalog: old.catalog, progress: old.progress, cards: old.cards, history: old.history)
            let verified = try loadExact(prepared.id)
            try CollectionLimits.require(try encode(verified.catalog) == encode(old.catalog) &&
                encode(verified.progress) == encode(old.progress) && encode(verified.cards) == encode(old.cards) &&
                encode(verified.history) == encode(old.history), "Library migration did not preserve all identities and learner state.")
            if fault == .migrationBeforePublication { throw CocoaError(.fileWriteNoPermission) }
            try encode(Pointer(current: prepared.id)).write(to: currentURL, options: .atomic)
            cachedVersion = old.catalog.version; cachedInstalled = prepared.installed
            // A second successful load is required before obsolete v2 bytes are removed.
            canCleanLegacy = false
            return verified
        } catch {
            cachedVersion = nil; cachedInstalled = []
            old.warning = "Library migration could not finish. The original library is intact; saving is paused. \(error.localizedDescription)"
            old.readOnly = true
            return old
        }
    }

    /// Called only after the store has made a verified v3 library available on a
    /// subsequent launch. First migration publication never deletes the v2 source.
    func confirmLaunch() throws {
        guard canCleanLegacy else { return }
        let verified = try loadExact(pointer().current)
        try CollectionLimits.require(!verified.readOnly, "Library must verify before cleanup.")
        for name in ["Library-v2", "imported-books.json"] {
            let url = documents.appendingPathComponent(name)
            if manager.fileExists(atPath: url.path) { try manager.removeItem(at: url) }
        }
        canCleanLegacy = false
        try garbageCollect()
    }

    private func readState(_ id: String) throws -> (LibraryState, CollectionCatalog) {
        let state = try read(LibraryState.self, snapshotDirectory(id).appendingPathComponent("library-state.json"))
        try CollectionLimits.require(state.schemaVersion == 3 && Set(state.installed.map(\.bookID)).count == state.installed.count,
                                    "Invalid library-state schema or duplicate books.")
        var packages: [LessonPackage] = []
        for record in state.installed {
            let url = try payloadURL(record.packageFile)
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? -1
            try CollectionLimits.require(size == record.packageBytes && size <= CollectionLimits.packageBytes, "A saved package has an unexpected size.")
            let bytes = try Data(contentsOf: url)
            try CollectionLimits.require(LibraryDigest.sha256(bytes) == record.packageSHA256, "A saved package checksum does not match.")
            let package = try InstalledPayload.decode(bytes, encoding: record.payloadEncoding).validated(for: .storedContent)
            try CollectionLimits.require(package.book.id == record.bookID && package.collectionNumber == record.collectionRevision &&
                record.packageFile == packagePath(bookID: record.bookID, revision: record.collectionRevision, sha: record.packageSHA256, encoding: record.payloadEncoding), "Saved package identity mismatch.")
            packages.append(package)
        }
        return (state, CollectionCatalog(packages: packages, knownLessons: state.knownLessons, knownBooks: state.knownBooks, version: state.version))
    }
    private func validCards(_ id: String) throws -> [String: IdeaCardRecord] {
        let cards = try read([String: IdeaCardRecord].self, snapshotDirectory(id).appendingPathComponent("cards.json"))
        try CollectionLimits.require(cards.allSatisfy { $0.key == $0.value.id && $0.value.lastEarnedRevision > 0 }, "Invalid card identity.")
        return cards
    }
    private func validHistory(_ id: String) throws -> [BookHistoryRecord] {
        let history = try read([BookHistoryRecord].self, snapshotDirectory(id).appendingPathComponent("history.json"))
        try CollectionLimits.require(Set(history.map(\.bookID)).count == history.count && history.allSatisfy {
            !$0.bookID.isEmpty && $0.lastKnownIdeaCount >= 0 && $0.lastKnownPracticedCount >= 0 &&
            $0.lastKnownPracticedCount <= $0.lastKnownIdeaCount && Set($0.ideas.map(\.id)).count == $0.ideas.count
        }, "Invalid book History metadata.")
        return history
    }
    private func loadExact(_ id: String) throws -> LibrarySnapshot {
        let (state, catalog) = try readState(id)
        return try LibrarySnapshot(catalog: catalog,
            progress: read([String: LessonProgress].self, snapshotDirectory(id).appendingPathComponent("progress.json")),
            cards: validCards(id), installed: state.installed, history: validHistory(id))
    }
    private func loadCurrent() throws -> LibrarySnapshot {
        let p = try pointer(), ids = [p.current, p.previous].compactMap { $0 }
        var result = LibrarySnapshot(catalog: CollectionCatalog(packages: []), progress: [:])
        var loadedState = false, loadedProgress = false, loadedCards = false, loadedHistory = false
        var warnings: [String] = []
        for id in ids {
            if !loadedState {
                do {
                    let (state, catalog) = try readState(id)
                    result.catalog = catalog; result.installed = state.installed; loadedState = true
                    if id != p.current { warnings.append("Recovered the previous collection snapshot; the damaged file is preserved.") }
                } catch { warnings.append("A library-state or package file is unreadable; checking its recovery copy.") }
            }
            if !loadedProgress {
                do {
                    result.progress = try read([String: LessonProgress].self, snapshotDirectory(id).appendingPathComponent("progress.json")); loadedProgress = true
                    if id != p.current { warnings.append("Recovered the previous progress snapshot; the damaged file is preserved.") }
                } catch { warnings.append("A progress snapshot is unreadable; checking its recovery copy.") }
            }
            if !loadedCards {
                do {
                    result.cards = try validCards(id); loadedCards = true
                    if id != p.current { result.recoveredCards = true; warnings.append("Recovered the previous idea-card snapshot. Recent favorites may need to be repeated.") }
                } catch { warnings.append("An idea-card snapshot is unreadable; checking its recovery copy.") }
            }
            if !loadedHistory {
                do { result.history = try validHistory(id); loadedHistory = true }
                catch { warnings.append("A History snapshot is unreadable; checking its recovery copy.") }
            }
        }
        if result.recoveredCards && loadedProgress && loadedState {
            for package in result.catalog.packages {
                for lesson in package.book.lessons {
                    if let state = result.progress[LessonProgress.key(bookID: package.book.id, lesson: lesson)], state.practiceComplete {
                        IdeaCardRecord.earn(book: package.book, lesson: lesson, date: state.practicedAt, into: &result.cards)
                    }
                }
            }
        }
        result.readOnly = !loadedState || !loadedProgress || !loadedCards || !loadedHistory
        result.warning = warnings.isEmpty ? nil : warnings.joined(separator: " ")
        if loadedState { cachedVersion = result.catalog.version; cachedInstalled = result.installed }
        return result
    }

    private func packagePath(bookID: String, revision: Int, sha: String, encoding: String? = nil) -> String {
        "Packages/\(LibraryDigest.bookDirectory(bookID))/\(revision)-\(sha)." + (encoding == nil ? "json" : "lilbook")
    }
    private func prepareSnapshot(catalog: CollectionCatalog, progress: [String: LessonProgress],
                                 cards: [String: IdeaCardRecord], history: [BookHistoryRecord]) throws -> (id: String, installed: [InstalledBookRecord]) {
        if fault == .write { throw CocoaError(.fileWriteNoPermission) }
        var installed: [InstalledBookRecord] = []
        if cachedVersion == catalog.version { installed = cachedInstalled }
        else {
            for package in catalog.packages {
                let encoded = try InstalledPayload.encode(package)
                let bytes = encoded.bytes, sha = LibraryDigest.sha256(bytes)
                let path = packagePath(bookID: package.book.id, revision: package.collectionNumber, sha: sha, encoding: encoded.encoding)
                let url = try payloadURL(path)
                try manager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                if !manager.fileExists(atPath: url.path) { try bytes.write(to: url, options: .atomic) }
                else { try CollectionLimits.require(LibraryDigest.sha256(Data(contentsOf: url)) == sha, "Existing package checksum mismatch.") }
                installed.append(InstalledBookRecord(bookID: package.book.id, collectionRevision: package.collectionNumber,
                    packageFile: path, packageSHA256: sha, packageBytes: bytes.count, source: .manual, payloadEncoding: encoded.encoding))
            }
        }
        for index in installed.indices {
            installed[index].source = history.first { $0.bookID == installed[index].bookID }?.source ?? installed[index].source
        }
        let state = LibraryState(installed: installed, knownLessons: catalog.knownLessons, knownBooks: catalog.knownBooks ?? [:], version: catalog.version)
        let id = UUID().uuidString, dir = try snapshotDirectory(id)
        try manager.createDirectory(at: dir, withIntermediateDirectories: true)
        try encode(state).write(to: dir.appendingPathComponent("library-state.json"), options: .atomic)
        try encode(progress).write(to: dir.appendingPathComponent("progress.json"), options: .atomic)
        try encode(cards).write(to: dir.appendingPathComponent("cards.json"), options: .atomic)
        try encode(history).write(to: dir.appendingPathComponent("history.json"), options: .atomic)
        return (id, installed)
    }
    @discardableResult func save(catalog: CollectionCatalog, progress: [String: LessonProgress],
                                cards: [String: IdeaCardRecord], history: [BookHistoryRecord]) throws -> [InstalledBookRecord] {
        try recoverOffload()
        let previous = manager.fileExists(atPath: currentURL.path) ? try pointer().current : nil
        let prepared = try prepareSnapshot(catalog: catalog, progress: progress, cards: cards, history: history)
        try encode(Pointer(current: prepared.id, previous: previous)).write(to: currentURL, options: .atomic)
        cachedVersion = catalog.version; cachedInstalled = prepared.installed
        // A cleanup failure must not roll back a successfully published installation.
        // Offload uses a throwing collector and never reports reclaimed bytes prematurely.
        try? garbageCollect()
        return prepared.installed
    }

    func offload(bookID: String, catalog: CollectionCatalog, progress: [String: LessonProgress],
                 cards: [String: IdeaCardRecord], history: [BookHistoryRecord]) throws -> LibrarySnapshot {
        try recoverOffload()
        // Offload may be requested before a second launch. Verify the published v3
        // library now before permitting any legacy payload cleanup or reclamation.
        let active = try loadExact(pointer().current)
        cachedVersion = active.catalog.version; cachedInstalled = active.installed
        canCleanLegacy = true; try confirmLaunch()
        guard let record = cachedInstalled.first(where: { $0.bookID == bookID }) else { throw PackageError.invalid("This book is no longer installed.") }
        if fault == .write { throw CocoaError(.fileWriteNoPermission) }
        let old = try pointer(), url = try payloadURL(record.packageFile)
        var next = catalog; next.packages.removeAll { $0.book.id == bookID }; next.version = UUID()
        // Old revisions may be reclaimed first: current installed content stays intact
        // if deleting any of these obsolete payloads fails.
        for other in try manager.contentsOfDirectory(at: url.deletingLastPathComponent(), includingPropertiesForKeys: nil) where other != url {
            try manager.removeItem(at: other)
        }
        let prepared = try prepareSnapshot(catalog: next, progress: progress, cards: cards, history: history)
        let recovery = try prepareSnapshot(catalog: next, progress: progress, cards: cards, history: history)
        let nextPointer = Pointer(current: prepared.id, previous: recovery.id)
        let result = try loadExact(prepared.id)
        let journal = OffloadJournal(old: old, next: nextPointer, packageFile: record.packageFile)
        try encode(journal).write(to: journalURL, options: .atomic)
        if fault == .offloadAfterJournal { throw CocoaError(.userCancelled) }
        try encode(nextPointer).write(to: currentURL, options: .atomic)
        if fault == .offloadAfterPointer { throw CocoaError(.userCancelled) }
        do {
            if fault == .deletion { throw CocoaError(.fileWriteNoPermission) }
            // A single file unlink is the commit decision. It either leaves the entire
            // active payload present or removes it; the journal makes crashes recoverable.
            try manager.removeItem(at: url)
        } catch {
            try recoverOffload() // file exists -> restore old installed state
            throw error
        }
        if fault == .offloadAfterDeletion { throw CocoaError(.userCancelled) }
        cachedVersion = next.version; cachedInstalled = prepared.installed
        try? manager.removeItem(at: journalURL)
        try? garbageCollect()
        return result
    }
    private func recoverOffload() throws {
        guard manager.fileExists(atPath: journalURL.path) else { return }
        let journal = try read(OffloadJournal.self, journalURL)
        let exists = manager.fileExists(atPath: try payloadURL(journal.packageFile).path)
        let resolved = exists ? journal.old : journal.next
        _ = try loadExact(resolved.current)
        try encode(resolved).write(to: currentURL, options: .atomic)
        try manager.removeItem(at: journalURL)
        cachedVersion = nil; cachedInstalled = []
    }
    func garbageCollect() throws {
        guard !manager.fileExists(atPath: journalURL.path) else { return }
        let p = try pointer()
        var referenced = Set<String>()
        for id in [p.current, p.previous].compactMap({ $0 }) {
            let state = try read(LibraryState.self, snapshotDirectory(id).appendingPathComponent("library-state.json"))
            referenced.formUnion(state.installed.map(\.packageFile))
        }
        let packages = root.appendingPathComponent("Packages")
        guard let enumerator = manager.enumerator(at: packages, includingPropertiesForKeys: [.isRegularFileKey]) else { return }
        for case let url as URL in enumerator {
            guard try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else { continue }
            let relative = "Packages/" + url.path.dropFirst(packages.path.count + 1)
            if !referenced.contains(relative) { try manager.removeItem(at: url) }
        }
    }
    func packageBytes(bookID: String) throws -> Int {
        let folder = root.appendingPathComponent("Packages/" + LibraryDigest.bookDirectory(bookID))
        guard manager.fileExists(atPath: folder.path) else { return 0 }
        return try manager.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.fileSizeKey]).reduce(0) {
            $0 + (try $1.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
        }
    }
    func prepare(url: URL, catalog: CollectionCatalog) async throws -> ImportReview { try await legacy.prepare(url: url, catalog: catalog) }
    func review(package: LessonPackage, catalog: CollectionCatalog) throws -> ImportReview { try CollectionComparison.review(package.validated(), catalog: catalog) }
    func record(package: LessonPackage, in catalog: CollectionCatalog) throws -> CollectionCatalog { var next = catalog; try next.record(package); return next }
}
