import Foundation

extension CollectionStorage {
    /// Committed progress is the sole ownership authority. Historical content is
    /// consulted only for an exact completed idea/revision; never installed as a library.
    func migrateCards(catalog: CollectionCatalog, progress: [String: LessonProgress], seed: LessonPackage?, seedURL: URL?) -> [String: IdeaCardRecord] {
        var records: [String: IdeaCardRecord] = [:]
        var candidates = catalog.packages
        if let seed { candidates.append(seed) }
        else if let seedURL, let data = try? Data(contentsOf: seedURL), let p = try? JSONDecoder().decode(LessonPackage.self, from: data) { candidates.append(p) }
        // Only inspect history when committed completed keys cannot be resolved from current content.
        let available = Set(candidates.flatMap { p in p.book.lessons.map { LessonProgress.key(bookID: p.book.id, lesson: $0) } })
        if progress.contains(where: { $0.value.practiceComplete && !available.contains($0.key) }) {
            candidates += historicalPackages()
        }
        let lessons = candidates.flatMap { p in p.book.lessons.map { (p.book, $0) } }.sorted { $0.1.revision < $1.1.revision }
        for (book, lesson) in lessons {
            guard let state = progress[LessonProgress.key(bookID: book.id, lesson: lesson)], state.practiceComplete else { continue }
            IdeaCardRecord.earn(book: book, lesson: lesson, date: state.practicedAt, into: &records)
        }
        return records
    }

    func archivedSource(for record: IdeaCardRecord) -> LessonPackage? {
        historicalPackages().first { p in
            p.book.id == record.bookID && p.book.lessons.contains { $0.id == record.lessonID && $0.revision == record.lastEarnedRevision }
        }
    }

    private func historicalPackages() -> [LessonPackage] {
        let root = documents.appendingPathComponent("Library-v2")
        let files = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        var seenFiles = Set<UInt64>(), seenVersions = Set<UUID>(), result: [LessonPackage] = []
        for directory in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) where UUID(uuidString: directory.lastPathComponent) != nil {
            let url = directory.appendingPathComponent("collections.json")
            // Progress-only saves hard-link the catalog. Decode each inode once.
            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path), let inode = attrs[.systemFileNumber] as? UInt64 {
                guard seenFiles.insert(inode).inserted else { continue }
            }
            guard let data = try? Data(contentsOf: url), let catalog = try? JSONDecoder().decode(CollectionCatalog.self, from: data),
                  seenVersions.insert(catalog.version).inserted else { continue }
            for package in catalog.packages {
                if let valid = try? package.validated(for: .storedContent) { result.append(valid) }
            }
        }
        return result
    }
}
