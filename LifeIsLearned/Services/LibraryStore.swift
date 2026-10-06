import Foundation
import Combine

@MainActor final class LibraryStore: ObservableObject {
    @Published private(set) var books: [LearningBook] = []
    @Published private(set) var cards: [String: IdeaCardRecord] = [:]
    @Published private(set) var progress: [String: LessonProgress] = [:]
    @Published private(set) var isLoading = true
    @Published private(set) var isPreparingImport = false
    @Published private(set) var isCommitting = false
    @Published private(set) var readOnly = false
    @Published var errorMessage: String?
    @Published var importReview: ImportReview?
    @Published var importedBook: LearningBook?
    @Published private(set) var lastImportWasNoOp = false
    private(set) var catalog = CollectionCatalog(packages: [])
    let storage: CollectionStorage
    private var loadTask: Task<Void, Never>?
    private var saveTask: Task<Void, Never>?
    private var preparationID = UUID()

    init(documentsURL: URL? = nil, defaults: UserDefaults = .standard,
         initialPackage: LessonPackage? = nil, includeDemo: Bool = true) {
        let documents = documentsURL ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        storage = CollectionStorage(documents: documents)
        let seedURL = includeDemo && initialPackage == nil ? Bundle.main.url(forResource: "starter", withExtension: "json") : nil
        let legacyProgress = defaults.data(forKey: "lessonProgress.v1")
        loadTask = Task { [weak self, storage] in
            let result = await storage.load(seed: initialPackage, seedURL: seedURL, legacyProgress: legacyProgress)
            guard let self else { return }
            self.catalog = result.catalog; self.books = result.catalog.packages.map(\.book)
            self.cards = result.cards; self.progress = result.progress; self.readOnly = result.readOnly
            self.errorMessage = result.warning; self.isLoading = false
        }
    }
    func ready() async { await loadTask?.value }
    func flush() async { await saveTask?.value }
    func package(for book: LearningBook) -> LessonPackage? { catalog.packages.first { $0.book.id == book.id } }
    func key(book: LearningBook, lesson: Lesson) -> String { LessonProgress.key(bookID: book.id, lesson: lesson) }
    func status(book: LearningBook, lesson: Lesson) -> LessonProgress { progress[key(book: book, lesson: lesson)] ?? LessonProgress() }

    func update(book: LearningBook, lesson: Lesson, change: (inout LessonProgress) -> Void) {
        guard !isLoading, !readOnly else { return }
        let id = key(book: book, lesson: lesson)
        var state = progress[id] ?? LessonProgress()
        change(&state); progress[id] = state
        if state.practiceComplete {
            IdeaCardRecord.earn(book: book, lesson: lesson, date: state.practicedAt, into: &cards)
        }
        if !isCommitting { enqueueSave() }
    }
    private func enqueueSave() {
        let previous = saveTask
        let snapshot = catalog; let savedProgress = progress; let savedCards = cards
        saveTask = Task { [weak self, storage] in
            await previous?.value
            do { try await storage.save(catalog: snapshot, progress: savedProgress, cards: savedCards) }
            catch { self?.errorMessage = "Progress could not be saved. Free some device storage and try again. Your prior saved library is intact." }
        }
    }
    func toggleFavorite(_ id: String) {
        guard !isLoading, !readOnly, var card = cards[id] else { return }
        card.isFavorite.toggle(); cards[id] = card
        if !isCommitting { enqueueSave() }
    }
    func cardPresentation(_ record: IdeaCardRecord) -> IdeaCardPresentation {
        let book = books.first { $0.id == record.bookID }
        return IdeaCardPresentation(record: record, activeBook: book, activeLesson: book?.lessons.first { $0.id == record.lessonID })
    }
    func cardReview(_ record: IdeaCardRecord) async -> LessonLaunch? {
        if let book = books.first(where: { $0.id == record.bookID }), let lesson = book.lessons.first(where: { $0.id == record.lessonID }) {
            return LessonLaunch(book: book, lesson: lesson, review: true)
        }
        guard let package = await storage.archivedSource(for: record),
              let lesson = package.book.lessons.first(where: { $0.id == record.lessonID && $0.revision == record.lastEarnedRevision }) else { return nil }
        return LessonLaunch(book: package.book, lesson: lesson, review: true, archivedPackage: package)
    }
    func prepareImport(from url: URL) async {
        guard !isPreparingImport && !isCommitting && !readOnly else { return }
        let token = UUID(); preparationID = token
        isPreparingImport = true; errorMessage = nil; importedBook = nil
        do {
            let review = try await storage.prepare(url: url, catalog: catalog)
            guard token == preparationID else { return }
            importReview = review
        } catch {
            guard token == preparationID else { return }
            errorMessage = "Collection wasn't imported. \(error.localizedDescription)"
        }
        isPreparingImport = false
    }
    func cancelImport() {
        guard !isCommitting else { return }
        preparationID = UUID(); importReview = nil; isPreparingImport = false
    }
    func commitImport(_ staged: ImportReview, acknowledgeRemovals: Bool = false) async {
        guard !isCommitting && !readOnly else { return }
        isCommitting = true; errorMessage = nil
        defer { isCommitting = false }
        do {
            await flush()
            guard staged.catalogVersion == catalog.version else {
                throw PackageError.invalid("The library changed while this preview was open. Select the collection again to review current changes.")
            }
            let checked = try await storage.review(package: staged.package, catalog: catalog)
            guard checked.removed.isEmpty || acknowledgeRemovals else {
                throw PackageError.invalid("Acknowledge the listed removals before importing this update.")
            }
            if checked.alreadyImported { lastImportWasNoOp = true; importedBook = checked.package.book; importReview = nil; return }
            var next = catalog
            if let index = next.packages.firstIndex(where: { $0.book.id == checked.package.book.id }) {
                next.packages[index] = checked.package
            } else { next.packages.append(checked.package) }
            next.version = UUID()
            // Hashing/image comparison is performed by the storage actor; the new
            // records are small value data, prepared off the main actor as well.
            next = try await storage.record(package: checked.package, in: next)
            var nextProgress = progress
            for lesson in checked.revised {
                let identity = LessonProgress.identity(bookID: checked.package.book.id, lessonID: lesson.id)
                let previous = progress.filter { $0.key.hasPrefix(identity + ":") }.values.max {
                    ($0.lastEngagedAt ?? .distantPast) < ($1.lastEngagedAt ?? .distantPast)
                }
                var fresh = LessonProgress(); fresh.updated = true; fresh.lastEngagedAt = previous?.lastEngagedAt
                nextProgress[LessonProgress.key(bookID: checked.package.book.id, lesson: lesson)] = fresh
            }
            try await storage.save(catalog: next, progress: nextProgress, cards: cards)
            // Preserve any foreground progress changes made while disk work ran.
            let revisions = checked.revised.map { LessonProgress.key(bookID: checked.package.book.id, lesson: $0) }
            for id in revisions { progress[id] = nextProgress[id] }
            catalog = next; books = next.packages.map(\.book)
            lastImportWasNoOp = false
            importedBook = checked.package.book; importReview = nil
            enqueueSave()
        } catch {
            errorMessage = "Collection wasn't imported. \(error.localizedDescription)"
            enqueueSave()
        }
    }
}

extension CollectionStorage {
    func record(package: LessonPackage, in catalog: CollectionCatalog) throws -> CollectionCatalog {
        var next = catalog; try next.record(package); return next
    }
}
