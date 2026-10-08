import Foundation

struct LibrarySnapshot: Sendable {
    var catalog: CollectionCatalog
    var progress: [String: LessonProgress]
    var cards: [String: IdeaCardRecord] = [:]
    var installed: [InstalledBookRecord] = []
    var history: [BookHistoryRecord] = []
    var needsCardMigration = false
    var recoveredCards = false
    var warning: String?
    var readOnly = false
}

/// Serial, off-main disk boundary. A single atomic CURRENT replacement commits
/// immutable content and progress files together. Older snapshots remain recoverable.
actor CollectionStorage {
    struct Pointer: Codable { var current: String; var previous: String?; var cardStateVersion: Int? = nil }
    let documents: URL
    private let root: URL
    private var injectedWriteFailure = false
    private var reusableCatalog: (version: UUID, file: URL)?

    init(documents: URL) {
        self.documents = documents
        root = documents.appendingPathComponent("Library-v2", isDirectory: true)
    }
    func setWriteFailure(_ value: Bool) { injectedWriteFailure = value }

    func load(seed: LessonPackage?, seedURL: URL?, legacyProgress: Data?, saveMigratedCards: Bool = true) -> LibrarySnapshot {
        var snapshot = loadCore(seed: seed, seedURL: seedURL, legacyProgress: legacyProgress)
        if snapshot.needsCardMigration || (snapshot.recoveredCards && !snapshot.readOnly) {
            let earned = migrateCards(catalog: snapshot.catalog, progress: snapshot.progress, seed: seed, seedURL: seedURL)
            for (id, record) in earned {
                if var previous = snapshot.cards[id] {
                    if record.lastEarnedRevision > previous.lastEarnedRevision {
                        previous.lastEarnedRevision = record.lastEarnedRevision
                        previous.snapshot = record.snapshot
                        snapshot.cards[id] = previous
                    }
                } else { snapshot.cards[id] = record }
            }
            if saveMigratedCards && snapshot.needsCardMigration && !snapshot.readOnly {
                do { try save(catalog: snapshot.catalog, progress: snapshot.progress, cards: snapshot.cards) }
                catch { snapshot.warning = "The library could not be saved: \(error.localizedDescription)" }
            }
        }
        return snapshot
    }

    private func loadCore(seed: LessonPackage?, seedURL: URL?, legacyProgress: Data?) -> LibrarySnapshot {
        var warnings: [String] = []
        var progress: [String: LessonProgress] = [:]
        var progressReadable = true
        // Decode progress independently, before attempting any content.
        if let legacyProgress {
            do { progress = try JSONDecoder().decode([String: LessonProgress].self, from: legacyProgress) }
            catch { warnings.append("Saved legacy progress is unreadable and has been preserved for recovery."); progressReadable = false }
        }
        var packages: [LessonPackage] = []
        do {
            if let seed { packages = [try seed.validated(for: .storedContent)] }
            else if let seedURL {
                packages = [try JSONDecoder().decode(LessonPackage.self, from: Data(contentsOf: seedURL)).validated(for: .storedContent)]
            }
        } catch { warnings.append("The demo could not load: \(error.localizedDescription)") }
        var catalog = CollectionCatalog(packages: packages)
        let currentURL = root.appendingPathComponent("CURRENT.json")
        if FileManager.default.fileExists(atPath: currentURL.path) {
            do {
                let pointer = try JSONDecoder().decode(Pointer.self, from: Data(contentsOf: currentURL))
                guard pointer.cardStateVersion == nil || pointer.cardStateVersion == 1 else {
                    throw PackageError.invalid("This library uses a newer idea-card format.")
                }
                let ids = [pointer.current, pointer.previous].compactMap { $0 }
                // Uncommitted directories are deliberately never candidates.
                var loadedProgress = false
                var loadedCatalog = false
                var cards: [String: IdeaCardRecord] = [:]
                let needsCardMigration = pointer.cardStateVersion == nil
                var loadedCards = needsCardMigration
                var recoveredCards = false
                for id in ids {
                    guard UUID(uuidString: id) != nil else { continue }
                    let directory = root.appendingPathComponent(id)
                    if !loadedCards {
                        do {
                            let candidate = try JSONDecoder().decode([String: IdeaCardRecord].self,
                                from: Data(contentsOf: directory.appendingPathComponent("cards.json")))
                            guard candidate.allSatisfy({ $0.key == $0.value.id && $0.value.lastEarnedRevision > 0 }) else {
                                throw PackageError.invalid("Invalid idea card identity.")
                            }
                            cards = candidate; loadedCards = true
                            if id != pointer.current { recoveredCards = true; warnings.append("Recovered the previous idea-card snapshot; the damaged file is preserved. Recent favorite changes may need to be repeated.") }
                        } catch { warnings.append("An idea-card snapshot is unreadable; checking its recovery copy.") }
                    }
                    if !loadedProgress {
                        do {
                            progress = try JSONDecoder().decode([String: LessonProgress].self,
                                       from: Data(contentsOf: directory.appendingPathComponent("progress.json")))
                            loadedProgress = true; progressReadable = true
                            if id != pointer.current { warnings.append("Recovered the previous progress snapshot; the damaged file is preserved.") }
                        } catch { warnings.append("A progress snapshot is unreadable; checking its recovery copy.") }
                    }
                    if !loadedCatalog {
                        do {
                            let candidate = try JSONDecoder().decode(CollectionCatalog.self,
                                            from: Data(contentsOf: directory.appendingPathComponent("collections.json")))
                            for package in candidate.packages { _ = try package.validated(for: .storedContent) }
                            catalog = candidate; loadedCatalog = true
                            reusableCatalog = (candidate.version, directory.appendingPathComponent("collections.json"))
                            if id != pointer.current { warnings.append("Recovered the previous collection snapshot; the damaged file is preserved.") }
                        } catch { warnings.append("A collection snapshot is unreadable; checking its recovery copy.") }
                    }
                }
                if !loadedProgress { progressReadable = false }
                if !loadedCatalog { warnings.append("Showing the demo while the saved collections await recovery.") }
                // Do not replace a partially recovered library with a new incomplete snapshot.
                let readOnly = !loadedProgress || !loadedCatalog || !loadedCards
                return LibrarySnapshot(catalog: catalog, progress: progress, cards: cards, needsCardMigration: needsCardMigration, recoveredCards: recoveredCards,
                    warning: warnings.isEmpty ? nil : warnings.joined(separator: " "), readOnly: readOnly)
            } catch {
                warnings.append("The library index is unreadable. Original files are preserved; saving is paused until recovery.")
                return LibrarySnapshot(catalog: catalog, progress: progress, warning: warnings.joined(separator: " "), readOnly: true)
            }
        }
        let legacy = documents.appendingPathComponent("imported-books.json")
        var contentReadable = true
        if FileManager.default.fileExists(atPath: legacy.path) {
            do {
                let old = try JSONDecoder().decode([LessonPackage].self, from: Data(contentsOf: legacy))
                for package in old {
                    let validated = try package.validated(for: .storedContent)
                    packages.removeAll { $0.book.id == package.book.id }
                    packages.append(validated)
                }
                catalog.packages = packages
            } catch {
                warnings.append("Legacy collections could not load. Saved progress and the original content file are preserved; saving is paused until recovery.")
                contentReadable = false
            }
        }
        do { for package in catalog.packages { try catalog.record(package) } }
        catch { warnings.append(error.localizedDescription); contentReadable = false }
        let readOnly = !contentReadable || !progressReadable
        return LibrarySnapshot(catalog: catalog, progress: progress, needsCardMigration: true,
            warning: warnings.isEmpty ? nil : warnings.joined(separator: " "), readOnly: readOnly)
    }

    func save(catalog: CollectionCatalog, progress: [String: LessonProgress], cards: [String: IdeaCardRecord]) throws {
        if injectedWriteFailure { throw CocoaError(.fileWriteNoPermission) }
        let manager = FileManager.default
        try manager.createDirectory(at: root, withIntermediateDirectories: true)
        let currentURL = root.appendingPathComponent("CURRENT.json")
        let old: Pointer?
        if manager.fileExists(atPath: currentURL.path) {
            old = try JSONDecoder().decode(Pointer.self, from: Data(contentsOf: currentURL))
        } else { old = nil }
        let id = UUID().uuidString
        let directory = root.appendingPathComponent(id, isDirectory: true)
        try manager.createDirectory(at: directory, withIntermediateDirectories: false)
        // No publication before every file is complete. An interruption leaves an
        // unreferenced directory, never a half-installed collection.
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let catalogURL = directory.appendingPathComponent("collections.json")
        if let reusableCatalog, reusableCatalog.version == catalog.version {
            try manager.linkItem(at: reusableCatalog.file, to: catalogURL)
        } else {
            try encoder.encode(catalog).write(to: catalogURL, options: .atomic)
        }
        try encoder.encode(progress).write(to: directory.appendingPathComponent("progress.json"), options: .atomic)
        try encoder.encode(cards).write(to: directory.appendingPathComponent("cards.json"), options: .atomic)
        let pointer = Pointer(current: id, previous: old?.current, cardStateVersion: 1)
        try encoder.encode(pointer).write(to: currentURL, options: .atomic)
        reusableCatalog = (catalog.version, catalogURL)
    }

    func prepare(url: URL, catalog: CollectionCatalog) throws -> ImportReview {
        let granted = url.startAccessingSecurityScopedResource()
        defer { if granted { url.stopAccessingSecurityScopedResource() } }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        try CollectionLimits.require(size <= CollectionLimits.packageBytes, "Keep complete collection files under 64 MiB. Optimize shared images before exporting.")
        return try CollectionComparison.review(LessonPackage.decodeImport(Data(contentsOf: url)), catalog: catalog)
    }

    func review(package: LessonPackage, catalog: CollectionCatalog) throws -> ImportReview {
        try CollectionComparison.review(package.validated(), catalog: catalog)
    }
}
