import Foundation
import UIKit

enum NarrationRole: String, Codable, CaseIterable, Identifiable {
    case guide, storyteller
    var id: String { rawValue }
    var label: String { self == .guide ? "Guide · intro & takeaway" : "Storyteller · lesson body" }
}

enum PageKind: String, Codable { case intro, story, explanation, takeaway }

struct ContentSource: Codable, Identifiable {
    let id: String
    let title: String
    let url: String
    let locator: String
    let scope: String
}

struct LessonPage: Codable, Identifiable {
    let id: String
    let kind: PageKind
    let role: NarrationRole
    let title: String
    let text: String
    let imageAsset: String?
    let imageBase64: String?
    let imageDescription: String?
    let sourceIDs: [String]
}

struct AnswerChoice: Codable, Identifiable {
    let id: String
    let text: String
    let feedback: String
}

struct PracticeQuestion: Codable, Identifiable {
    let id: String
    let prompt: String
    let choices: [AnswerChoice]
    let correctChoiceID: String
}

struct Lesson: Codable, Identifiable {
    let id: String
    let revision: Int
    let title: String
    let subtitle: String
    let estimatedMinutes: Int
    let scopeNote: String
    let pages: [LessonPage]
    let questions: [PracticeQuestion]
}

struct LearningBook: Codable, Identifiable {
    let id: String
    let title: String
    let author: String
    let synopsis: String
    let coverageNote: String
    let sources: [ContentSource]
    let lessons: [Lesson]
}

struct LessonPackage: Codable {
    let formatVersion: Int
    let book: LearningBook

    func validated() throws -> LessonPackage {
        func require(_ condition: Bool, _ message: String) throws {
            if !condition { throw PackageError.invalid(message) }
        }
        func clean(_ string: String) -> Bool { !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        func unique(_ ids: [String]) -> Bool { ids.allSatisfy(clean) && Set(ids).count == ids.count }
        try require(formatVersion == 1, "This package needs formatVersion 1.")
        try require(clean(book.id) && clean(book.title) && clean(book.author), "Book ID, title and author are required.")
        try require(clean(book.coverageNote), "Explain what source material was reviewed in coverageNote.")
        try require(!book.sources.isEmpty && unique(book.sources.map(\.id)), "Provide sources with unique IDs.")
        for source in book.sources {
            let url = URL(string: source.url)
            try require(url?.scheme == "https" && url?.host != nil, "Source \(source.id) needs a valid HTTPS link.")
            try require(clean(source.title) && clean(source.locator) && clean(source.scope), "Source \(source.id) needs title, locator and scope.")
        }
        try require(!book.lessons.isEmpty && book.lessons.count <= 100 && unique(book.lessons.map(\.id)), "Provide 1–100 lessons with unique IDs.")
        let sourceIDs = Set(book.sources.map(\.id))
        for lesson in book.lessons {
            try require(lesson.revision > 0 && clean(lesson.title) && clean(lesson.scopeNote), "Lesson \(lesson.id) needs title, positive revision and scopeNote.")
            try require(lesson.estimatedMinutes > 0, "Lesson \(lesson.id) needs a positive time estimate.")
            try require((2...40).contains(lesson.pages.count) && unique(lesson.pages.map(\.id)), "Lesson \(lesson.id) needs 2–40 unique screens.")
            try require(lesson.pages.first?.kind == .intro && lesson.pages.last?.kind == .takeaway, "Begin each lesson with intro and end with takeaway.")
            for page in lesson.pages {
                try require(clean(page.title) && clean(page.text) && page.text.count <= 6000, "Screen \(page.id) needs a title and 1–6000 characters of text.")
                try require(Set(page.sourceIDs).isSubset(of: sourceIDs), "Screen \(page.id) refers to an unknown source.")
                try require(page.kind == .story || !page.sourceIDs.isEmpty, "Teaching screen \(page.id) needs a source reference.")
                if let asset = page.imageAsset {
                    try require(["priors-setup", "priors-conflict", "priors-resolution"].contains(asset), "Unknown bundled image \(asset). Use imageBase64 for your own illustration.")
                }
                if let encoded = page.imageBase64 {
                    let data = Data(base64Encoded: encoded)
                    try require(data != nil && data!.count <= 2_000_000 && UIImage(data: data!) != nil, "Screen \(page.id) needs a valid PNG/JPEG under 2 MB.")
                }
                if page.imageAsset != nil || page.imageBase64 != nil {
                    try require(page.imageDescription.map(clean) == true, "Screen \(page.id) needs imageDescription for accessibility.")
                }
            }
            try require((2...10).contains(lesson.questions.count) && unique(lesson.questions.map(\.id)), "Provide 2–10 unique practice questions.")
            for question in lesson.questions {
                try require(clean(question.prompt) && (2...6).contains(question.choices.count) && unique(question.choices.map(\.id)), "Question \(question.id) needs a prompt and 2–6 unique choices.")
                try require(question.choices.contains { $0.id == question.correctChoiceID }, "Question \(question.id) has no matching correct answer.")
                try require(question.choices.allSatisfy { clean($0.text) && clean($0.feedback) }, "Every answer needs text and explanatory feedback.")
            }
        }
        return self
    }
}

enum PackageError: LocalizedError {
    case invalid(String)
    var errorDescription: String? {
        switch self { case .invalid(let message): return message }
    }
}

struct LessonProgress: Codable {
    var pageIndex = 0
    var readComplete = false
    var practiceComplete = false
    var firstTryCorrect = 0
    var practicedAt: Date?
    var needsReview: Bool { practiceComplete && firstTryCorrect < questionCount }
    var questionCount = 0
}
