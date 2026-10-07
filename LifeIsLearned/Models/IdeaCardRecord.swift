import Foundation

/// Ownership follows the semantic idea across revisions. No artwork is duplicated here.
struct IdeaCardRecord: Codable, Identifiable, Equatable, Sendable {
    struct Snapshot: Codable, Equatable, Sendable {
        var title: String
        var takeaway: String
        var application: String
        var bookTitle: String
        var author: String
        var hasDiveDeeper: Bool? = nil
        init(book: LearningBook, lesson: Lesson) {
            hasDiveDeeper = lesson.diveDeeper == nil ? nil : true
            title = lesson.title
            takeaway = lesson.pages.first { $0.kind == .takeaway }?.text ?? lesson.subtitle
            application = lesson.subtitle; bookTitle = book.title; author = book.author
        }
    }
    var bookID: String
    var lessonID: String
    var earnedAt: Date?
    var lastEarnedRevision: Int
    var isFavorite = false
    var snapshot: Snapshot
    var id: String { LessonProgress.identity(bookID: bookID, lessonID: lessonID) }
    var earnedLabel: String { earnedAt.map { "Earned " + $0.formatted(date: .abbreviated, time: .omitted) } ?? "Earned previously" }

    static func earn(book: LearningBook, lesson: Lesson, date: Date?, into records: inout [String: Self]) {
        let id = LessonProgress.identity(bookID: book.id, lessonID: lesson.id)
        if var old = records[id] {
            guard lesson.revision > old.lastEarnedRevision else { return }
            old.lastEarnedRevision = lesson.revision
            old.snapshot = Snapshot(book: book, lesson: lesson)
            records[id] = old // Preserve original date (including unknown) and favorite.
        } else {
            records[id] = Self(bookID: book.id, lessonID: lesson.id, earnedAt: date,
                lastEarnedRevision: lesson.revision, snapshot: Snapshot(book: book, lesson: lesson))
        }
    }
}

struct IdeaCardPresentation: Identifiable {
    let record: IdeaCardRecord
    let activeBook: LearningBook?
    let activeLesson: Lesson?
    var id: String { record.id }
    var archived: Bool { activeLesson == nil }
    var updated: Bool { (activeLesson?.revision ?? 0) > record.lastEarnedRevision }
    var stateLabel: String { archived ? "From an earlier collection" : updated ? "Updated · review again" : "Idea collected" }
    var accessibilityLabel: String {
        [record.snapshot.title, record.snapshot.takeaway, record.snapshot.bookTitle,
         record.snapshot.author, record.earnedLabel, stateLabel, record.isFavorite ? "Favorite" : "Not a favorite"].joined(separator: ". ")
    }
}

enum IdeaCardSort: String, CaseIterable, Identifiable {
    case recent = "Recently earned", book = "Book order", alphabetical = "Alphabetical"
    var id: String { rawValue }
}

enum IdeaCardCollection {
    static func select(from ordered: [IdeaCardRecord], favoritesOnly: Bool, bookID: String?) -> [IdeaCardRecord] {
        ordered.filter { (!favoritesOnly || $0.isFavorite) && (bookID == nil || $0.bookID == bookID) }
    }

    static func ordered(_ records: [IdeaCardRecord], books: [LearningBook], sort: IdeaCardSort, history: [BookHistoryRecord] = []) -> [IdeaCardRecord] {
        let retainedIDs = Set(history.map(\.bookID))
        let orderedIDs = history.flatMap { b in b.ideas.map { LessonProgress.identity(bookID: b.bookID, lessonID: $0.id) } }
            + books.filter { !retainedIDs.contains($0.id) }.flatMap { b in b.lessons.map { LessonProgress.identity(bookID: b.id, lessonID: $0.id) } }
        let positions = Dictionary(uniqueKeysWithValues: orderedIDs.enumerated().map { ($0.element, $0.offset) })
        return records.sorted { a, b in
            switch sort {
            case .recent:
                if a.earnedAt != b.earnedAt { return (a.earnedAt ?? .distantPast) > (b.earnedAt ?? .distantPast) }
            case .book:
                let left = positions[a.id] ?? Int.max, right = positions[b.id] ?? Int.max
                if left != right { return left < right }
            case .alphabetical:
                let order = a.snapshot.title.localizedStandardCompare(b.snapshot.title)
                if order != .orderedSame { return order == .orderedAscending }
            }
            return a.id < b.id
        }
    }
}

/// A changing collection must not turn "no selection yet" into an implicit choice.
/// Choose the current first card only when the learner opens the carousel.
enum IdeaCardSelection {
    static func reconcile(_ selectedID: String?, availableIDs: [String]) -> String? {
        guard let selectedID else { return nil }
        return availableIDs.contains(selectedID) ? selectedID : availableIDs.first
    }
}
