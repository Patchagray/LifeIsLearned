import Foundation

enum LearningPhase: String, Codable, Sendable { case reading, practice, complete }

struct PracticePosition: Codable, Sendable {
    var questionIndex = 0
    var selectedID: String?
    var attempted = false
    var firstTryCorrect = 0
}

struct LessonProgress: Codable, Sendable {
    var pageIndex = 0
    var readComplete = false
    var practiceComplete = false
    var firstTryCorrect = 0
    var practicedAt: Date?
    var questionCount = 0
    var phase: LearningPhase = .reading
    var practice = PracticePosition()
    var lastEngagedAt: Date?
    var updated = false
    var takeawayRevealed = false
    var needsReview: Bool { practiceComplete && firstTryCorrect < questionCount }

    static func identity(bookID: String, lessonID: String) -> String {
        "\(bookID.utf8.count):\(bookID)\(lessonID.utf8.count):\(lessonID)"
    }
    static func key(bookID: String, lesson: Lesson) -> String { identity(bookID: bookID, lessonID: lesson.id) + ":\(lesson.revision)" }

    var label: String {
        if updated && !practiceComplete { return "Updated · review again" }
        if practiceComplete { return "Practiced" }
        if readComplete { return "Ready to practice" }
        if lastEngagedAt != nil || pageIndex > 0 { return "In progress" }
        return "Not started"
    }

    init() {}
    enum CodingKeys: String, CodingKey {
        case pageIndex, readComplete, practiceComplete, firstTryCorrect, practicedAt, questionCount
        case phase, practice, lastEngagedAt, updated, takeawayRevealed
    }
    init(from decoder: Decoder) throws {
        let d = try decoder.container(keyedBy: CodingKeys.self)
        pageIndex = try d.decodeIfPresent(Int.self, forKey: .pageIndex) ?? 0
        readComplete = try d.decodeIfPresent(Bool.self, forKey: .readComplete) ?? false
        practiceComplete = try d.decodeIfPresent(Bool.self, forKey: .practiceComplete) ?? false
        firstTryCorrect = try d.decodeIfPresent(Int.self, forKey: .firstTryCorrect) ?? 0
        practicedAt = try d.decodeIfPresent(Date.self, forKey: .practicedAt)
        questionCount = try d.decodeIfPresent(Int.self, forKey: .questionCount) ?? 0
        phase = try d.decodeIfPresent(LearningPhase.self, forKey: .phase) ?? (practiceComplete ? .complete : .reading)
        practice = try d.decodeIfPresent(PracticePosition.self, forKey: .practice) ?? PracticePosition()
        // Old installs did not save engagement times. Never fabricate recency.
        lastEngagedAt = try d.decodeIfPresent(Date.self, forKey: .lastEngagedAt)
        updated = try d.decodeIfPresent(Bool.self, forKey: .updated) ?? false
        takeawayRevealed = try d.decodeIfPresent(Bool.self, forKey: .takeawayRevealed) ?? false
    }
}
