import Foundation
import ImageIO

enum NarrationRole: String, Codable, CaseIterable, Identifiable, Sendable {
    case guide, storyteller
    var id: String { rawValue }
    var label: String { self == .guide ? "Guide · intro & takeaway" : "Storyteller · lesson body" }
}

enum PageKind: String, Codable, Sendable { case intro, story, explanation, application, takeaway }

struct ContentSource: Codable, Identifiable, Sendable {
    var id: String
    var title: String
    var url: String
    var locator: String
    var scope: String
}

struct LessonPage: Codable, Identifiable, Sendable {
    var id: String
    var kind: PageKind
    var role: NarrationRole
    var title: String
    var text: String
    var imageID: String? = nil
    var imageAsset: String?
    var imageBase64: String?
    var imageDescription: String?
    var sourceIDs: [String]
}

struct AnswerChoice: Codable, Identifiable, Sendable {
    var id: String
    var text: String
    var feedback: String
}

struct PracticeQuestion: Codable, Identifiable, Sendable {
    var id: String
    var prompt: String
    var choices: [AnswerChoice]
    var correctChoiceID: String
}

struct Lesson: Codable, Identifiable, Sendable {
    var id: String
    var revision: Int
    var title: String
    var subtitle: String
    var estimatedMinutes: Int
    var scopeNote: String
    var pages: [LessonPage]
    var questions: [PracticeQuestion]
}

struct LearningBook: Codable, Identifiable, Sendable {
    var id: String
    var title: String
    var author: String
    var synopsis: String
    var coverageNote: String
    var sources: [ContentSource]
    var lessons: [Lesson]
    var coverAssetID: String? = nil
    var coverDescription: String? = nil
    var isDemo: Bool? = nil
}

struct LessonPackage: Codable, Sendable {
    enum ValidationPurpose { case newImport, storedContent }
    var formatVersion: Int
    var book: LearningBook
    var collectionRevision: Int? = nil
    var fullCollection: Bool? = nil
    var manifest: [IdeaManifestEntry]? = nil
    var removedLessonIDs: [String]? = nil
    var assets: [String: CollectionArtwork]? = nil

    func validated(for purpose: ValidationPurpose = .newImport) throws -> LessonPackage {
        func require(_ condition: Bool, _ message: String) throws {
            if !condition { throw PackageError.invalid(message) }
        }
        func clean(_ string: String) -> Bool { !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        func unique(_ ids: [String]) -> Bool { ids.allSatisfy(clean) && Set(ids).count == ids.count }
        try require(formatVersion == 2 || (purpose == .storedContent && formatVersion == 1),
                    "New imports require formatVersion 2 and a complete collection manifest. Use Tools/convert_package.py to convert a reviewed legacy release.")
        // New editorial policy must never invalidate an already-installed library.
        if purpose == .newImport && book.lessons.count > 12 {
            throw PackageError.invalid("This collection contains \(book.lessons.count) ideas. Prepare a complete release with no more than 12 selected ideas.")
        }
        let maximumIdeas = purpose == .storedContent ? 100 : 12
        try require(!book.lessons.isEmpty && book.lessons.count <= maximumIdeas && unique(book.lessons.map(\.id)),
                    "Provide 1–\(maximumIdeas) ideas with unique, nonempty IDs.")
        if formatVersion == 2 {
            try require((collectionRevision ?? 0) > 0 && fullCollection == true, "Declare a positive collectionRevision and fullCollection: true.")
            try require(manifest == book.lessons.map { IdeaManifestEntry(id: $0.id, revision: $0.revision) },
                        "The manifest must list every idea ID/revision exactly once in the same order as book.lessons.")
            try require(unique(removedLessonIDs ?? []), "removedLessonIDs must contain unique, nonempty IDs.")
            try require(Set(removedLessonIDs ?? []).isDisjoint(with: Set(book.lessons.map(\.id))), "Removed ideas cannot also be in the collection.")
            try require(artwork.keys.allSatisfy(clean), "Shared images need nonempty asset IDs.")
            try require(artwork.values.reduce(0) { $0 + $1.data.count } <= CollectionLimits.allAssetBytes, "Shared images exceed 24 MiB decoded. Optimize images before export.")
            for image in artwork.values { try CollectionLimits.validateImage(image) }
            if let cover = book.coverAssetID {
                try require(artwork[cover] != nil && book.coverDescription.map(clean) == true, "The book cover needs a valid shared asset ID and coverDescription.")
            }
        }
        try require(clean(book.id) && clean(book.title) && clean(book.author), "Book ID, title and author are required.")
        try require(clean(book.coverageNote), "Explain what source material was reviewed in coverageNote.")
        try require(!book.sources.isEmpty && unique(book.sources.map(\.id)), "Provide sources with unique IDs.")
        for source in book.sources {
            let url = URL(string: source.url)
            try require(url?.scheme == "https" && url?.host != nil, "Source \(source.id) needs a valid HTTPS link.")
            try require(clean(source.title) && clean(source.locator) && clean(source.scope), "Source \(source.id) needs title, locator and scope.")
        }
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
                if formatVersion == 2 {
                    try require(page.imageAsset == nil && page.imageBase64 == nil, "Format 2 pages use imageID and the shared assets table; remove legacy inline images.")
                    if let id = page.imageID { try require(artwork[id] != nil, "Screen \(page.id) refers to missing artwork \(id).") }
                }
                if let asset = page.imageAsset {
                    try require(["priors-setup", "priors-conflict", "priors-resolution"].contains(asset), "Unknown bundled image \(asset). Use imageBase64 for your own illustration.")
                }
                if let encoded = page.imageBase64 {
                    let data = Data(base64Encoded: encoded)
                    try require(data != nil && data!.count <= 2_000_000 && CGImageSourceCreateWithData(data! as CFData, nil) != nil, "Screen \(page.id) needs a valid PNG/JPEG under 2 MB.")
                }
                if page.imageID != nil || page.imageAsset != nil || page.imageBase64 != nil {
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
