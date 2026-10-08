import Foundation
import CryptoKit

struct BookSourceRecord: Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable { case manualImport, remoteCatalog }
    var kind: Kind
    var catalogID: String? = nil
    var catalogURL: URL? = nil
    static let manual = BookSourceRecord(kind: .manualImport)
    var restoreTitle: String { kind == .remoteCatalog ? "Download current book" : "Re-import book" }
    var restoreMessage: String {
        kind == .remoteCatalog ? "Download the current book from Browse Library. Its current lessons may differ from your earned card."
            : "Re-import the complete book file to read its lessons again. Your Idea Cards, favorites, progress and History remain here."
    }
}

struct InstalledBookRecord: Codable, Equatable, Sendable {
    var bookID: String
    var collectionRevision: Int
    var packageFile: String
    var packageSHA256: String
    var packageBytes: Int
    var source: BookSourceRecord
    var payloadEncoding: String? = nil
}

/// No prose, source definitions, covers or illustration data in durable metadata.
struct BookIdeaIdentity: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var revision: Int
    var title: String
    init(_ lesson: Lesson) { id = lesson.id; revision = lesson.revision; title = lesson.title }
}

struct BookVersionRecord: Codable, Sendable {
    var revision: Int
    var packageSHA256: String
    var ideas: [BookIdeaIdentity]
}

struct BookHistoryRecord: Codable, Identifiable, Equatable, Sendable {
    var bookID: String
    var title: String
    var author: String
    var firstSeenAt: Date?
    var lastOpenedAt: Date?
    var firstCompletedAt: Date?
    var lastKnownCollectionRevision: Int
    var lastKnownIdeaCount: Int
    var lastKnownPracticedCount: Int
    var source: BookSourceRecord
    var ideas: [BookIdeaIdentity]
    var hasCompletedBefore: Bool? = nil
    var id: String { bookID }
    var hasUpdates: Bool { (hasCompletedBefore == true || firstCompletedAt != nil) && lastKnownPracticedCount < lastKnownIdeaCount }

    static func refresh(_ package: LessonPackage, progress: [String: LessonProgress],
                        source: BookSourceRecord, previous: Self?, seenAt: Date? = nil) -> Self {
        let book = package.book
        let states = book.lessons.map { progress[LessonProgress.key(bookID: book.id, lesson: $0)] ?? LessonProgress() }
        let completed = states.filter(\.practiceComplete)
        // Unknown historical dates remain unknown; only infer a completion event when
        // every current idea has an actual recorded practice date.
        let completion = completed.count == states.count && completed.allSatisfy { $0.practicedAt != nil }
            ? completed.compactMap(\.practicedAt).max() : nil
        let lastOpened = ([previous?.lastOpenedAt] + states.map(\.lastEngagedAt)).compactMap { $0 }.max()
        let hadCompleted = previous.map { $0.hasCompletedBefore == true || $0.firstCompletedAt != nil || ($0.lastKnownIdeaCount > 0 && $0.lastKnownPracticedCount == $0.lastKnownIdeaCount) } ?? false
        let oldIdeas = previous?.ideas.filter { old in !book.lessons.contains { $0.id == old.id } } ?? []
        return Self(bookID: book.id, title: book.title, author: book.author,
                    firstSeenAt: previous == nil ? seenAt : previous?.firstSeenAt, lastOpenedAt: lastOpened,
                    firstCompletedAt: hadCompleted ? previous?.firstCompletedAt : completion,
                    lastKnownCollectionRevision: package.collectionNumber, lastKnownIdeaCount: book.lessons.count,
                    lastKnownPracticedCount: completed.count, source: source,
                    ideas: book.lessons.map(BookIdeaIdentity.init) + oldIdeas, hasCompletedBefore: hadCompleted || completed.count == states.count)
    }
}

struct LibraryState: Codable, Sendable {
    var schemaVersion = 3
    var installed: [InstalledBookRecord]
    var knownLessons: [String: LessonVersionRecord]
    var knownBooks: [String: BookVersionRecord]
    var version: UUID
}

enum LibraryDigest {
    static func sha256(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    static func bookDirectory(_ bookID: String) -> String { sha256(Data(bookID.utf8)) }
}
