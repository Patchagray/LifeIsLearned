import Foundation
import Combine

@MainActor final class LibraryStore: ObservableObject {
    @Published private(set) var books: [LearningBook] = []
    @Published private(set) var progress: [String: LessonProgress] = [:]
    @Published var errorMessage: String?
    private let documents: URL
    private let defaults: UserDefaults

    init(documentsURL: URL? = nil, defaults: UserDefaults = .standard, initialPackage: LessonPackage? = nil) {
        self.defaults = defaults
        documents = documentsURL ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        do {
            let package: LessonPackage
            if let initialPackage {
                package = try initialPackage.validated()
            } else {
                guard let seed = Bundle.main.url(forResource: "starter", withExtension: "json") else {
                    throw PackageError.invalid("The starter lesson is missing from this app build.")
                }
                package = try JSONDecoder().decode(LessonPackage.self, from: Data(contentsOf: seed)).validated()
            }
            books = [package.book]
            let imported = documents.appendingPathComponent("imported-books.json")
            if FileManager.default.fileExists(atPath: imported.path) {
                let packages = try JSONDecoder().decode([LessonPackage].self, from: Data(contentsOf: imported))
                for package in packages {
                    let book = try package.validated().book
                    books.removeAll { $0.id == book.id }
                    books.append(book)
                }
            }
            if let saved = defaults.data(forKey: "lessonProgress.v1") {
                progress = try JSONDecoder().decode([String: LessonProgress].self, from: saved)
            }
        } catch { errorMessage = "Couldn't load saved content: \(error.localizedDescription)" }
    }

    func key(book: LearningBook, lesson: Lesson) -> String {
        // Length-prefixed fields prevent collisions even when imported IDs contain separators.
        "\(book.id.utf8.count):\(book.id)\(lesson.id.utf8.count):\(lesson.id):\(lesson.revision)"
    }
    func status(book: LearningBook, lesson: Lesson) -> LessonProgress {
        progress[key(book: book, lesson: lesson)] ?? LessonProgress()
    }
    func update(book: LearningBook, lesson: Lesson, change: (inout LessonProgress) -> Void) {
        let id = key(book: book, lesson: lesson)
        var state = progress[id] ?? LessonProgress()
        change(&state)
        progress[id] = state
        do { defaults.set(try JSONEncoder().encode(progress), forKey: "lessonProgress.v1") }
        catch { errorMessage = "Couldn't save progress: \(error.localizedDescription)" }
    }

    func importPackage(from url: URL) {
        let granted = url.startAccessingSecurityScopedResource()
        defer { if granted { url.stopAccessingSecurityScopedResource() } }
        do {
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= 25_000_000 else { throw PackageError.invalid("Keep lesson packages under 25 MB.") }
            let data = try Data(contentsOf: url)
            guard data.count <= 25_000_000 else { throw PackageError.invalid("Keep lesson packages under 25 MB.") }
            let package = try JSONDecoder().decode(LessonPackage.self, from: data).validated()
            var nextBooks = books.filter { $0.id != package.book.id }
            nextBooks.append(package.book)
            let saved = nextBooks.map { LessonPackage(formatVersion: 1, book: $0) }
            let encoded = try JSONEncoder().encode(saved)
            try encoded.write(to: documents.appendingPathComponent("imported-books.json"), options: .atomic)
            books = nextBooks
        } catch {
            errorMessage = "Package wasn't imported. \(error.localizedDescription)"
        }
    }
}
