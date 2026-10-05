import Foundation

/// Shared with playback so estimates include the exact spoken prefixes and labels.
enum LessonNarration {
    static func page(_ page: LessonPage) -> String { page.title + ". " + page.text }
    static func question(_ question: PracticeQuestion) -> String {
        question.prompt + "\n" + question.choices.enumerated().map {
            "Option \($0.offset + 1). \($0.element.text)"
        }.joined(separator: "\n")
    }
    static func feedback(_ choice: AnswerChoice, correct: Bool) -> String {
        (correct ? "That's right. " : "Let's reconsider. ") + choice.feedback
    }
    static func completion(correct: Int, total: Int) -> String {
        "Lesson complete. You've practiced a new idea. \(correct) of \(total) correct on the first try."
    }
}

/// Reference planning estimate, not a playback deadline or an import restriction.
/// Keep the word definition and constants aligned with Tools/lesson_timing.py.
struct LessonTiming {
    private static let wordExpression = try! NSRegularExpression(pattern: #"[\p{L}\p{N}]+(?:['’][\p{L}\p{N}]+)*"#)
    static let wordsPerMinute = 130.0
    static let referencePause = 2.0
    static let answerSecondsPerQuestion = 20.0
    static let help = "Approximate whole-idea time includes narration, all choices, one feedback response per question, 2-second page pauses, and 20 seconds to answer each question. Planned at 130 words per minute. Slower voices or speeds, longer pauses, deliberation, replays, and retries can take longer. Nothing is cut short."
    struct Segment {
        let id: String
        let role: NarrationRole
        let text: String
    }
    let segments: [Segment]
    let transitionCount: Int
    let questionCount: Int
    var spokenWords: Int { segments.reduce(0) { $0 + Self.wordCount($1.text) } }
    var speechSeconds: Double { Double(spokenWords) * 60 / Self.wordsPerMinute }
    var pauseSeconds: Double { Double(transitionCount) * Self.referencePause }
    var answerSeconds: Double { Double(questionCount) * Self.answerSecondsPerQuestion }
    var totalSeconds: Double { speechSeconds + pauseSeconds + answerSeconds }
    var approximateMinutes: Int { max(1, Int(ceil(totalSeconds / 60))) }
    var label: String { "About \(approximateMinutes) min · whole idea" }

    init(lesson: Lesson) {
        var script = lesson.pages.map { Segment(id: "page:" + $0.id, role: $0.role, text: LessonNarration.page($0)) }
        for question in lesson.questions {
            script.append(Segment(id: "question:" + question.id, role: .guide, text: LessonNarration.question(question)))
            // Include the longest single response, including its spoken prefix.
            let response = question.choices.reduce("") { longest, choice in
                let text = LessonNarration.feedback(choice, correct: choice.id == question.correctChoiceID)
                // Keep the first response on ties, matching Python's max().
                return Self.wordCount(text) > Self.wordCount(longest) ? text : longest
            }
            script.append(Segment(id: "feedback:" + question.id, role: .guide, text: response))
        }
        script.append(Segment(id: "completion", role: .guide,
                              text: LessonNarration.completion(correct: lesson.questions.count, total: lesson.questions.count)))
        segments = script
        transitionCount = max(0, lesson.pages.count - 1)
        questionCount = lesson.questions.count
    }
    static func wordCount(_ text: String) -> Int {
        // Count without allocating a match object array for large stored lessons.
        wordExpression.numberOfMatches(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text))
    }
}

extension LearningBook {
    var selectionPreface: String {
        "This companion presents \(lessons.count) selected \(lessons.count == 1 ? "idea" : "ideas") from the material described below. It is a curated selection, not an exhaustive summary or the author's own ranking."
    }
}
