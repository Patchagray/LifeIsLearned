import Foundation
import Combine

@MainActor final class LibraryStore: ObservableObject {
    @Published private(set) var books: [LearningBook] = []
    @Published private(set) var cards: [String: IdeaCardRecord] = [:]
    @Published private(set) var progress: [String: LessonProgress] = [:]
    @Published private(set) var history: [BookHistoryRecord] = []
    @Published private(set) var installed: [InstalledBookRecord] = []
    @Published var restoreBookID: String?
    @Published private(set) var isLoading = true
    @Published private(set) var isPreparingImport = false
    @Published private(set) var isCommitting = false
    @Published private(set) var readOnly = false
    @Published var errorMessage: String?
    @Published var importReview: ImportReview?
    @Published var importedBook: LearningBook?
    @Published private(set) var lastImportWasNoOp = false
    private(set) var catalog = CollectionCatalog(packages: [])
    let storage: LibraryStorage
    private var loadTask: Task<Void, Never>?
    private var saveTask: Task<Void, Never>?
    private var preparationID = UUID()

    init(documentsURL: URL? = nil, defaults: UserDefaults = .standard,
         initialPackage: LessonPackage? = nil, includeDemo: Bool = true) {
        let documents = documentsURL ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        storage = LibraryStorage(documents: documents)
        let seedURL = includeDemo && initialPackage == nil ? Bundle.main.url(forResource: "starter", withExtension: "json") : nil
        let legacyProgress = defaults.data(forKey: "lessonProgress.v1")
        loadTask = Task { [weak self, storage] in
            let result = await storage.load(seed: initialPackage, seedURL: seedURL, legacyProgress: legacyProgress)
            guard let self else { return }
            self.catalog = result.catalog; self.books = result.catalog.packages.map(\.book)
            self.cards = result.cards; self.progress = result.progress; self.readOnly = result.readOnly
            self.history = result.history; self.installed = result.installed
            self.errorMessage = result.warning; self.isLoading = false
            if !result.readOnly {
                do { try await storage.confirmLaunch() }
                catch { self.errorMessage = "Your library is available, but obsolete package cleanup needs another attempt. \(error.localizedDescription)" }
            }
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
        refreshHistory(book: book)
        if !isCommitting { enqueueSave() }
    }
    private func enqueueSave() {
        let previous = saveTask
        let snapshot = catalog; let savedProgress = progress; let savedCards = cards; let savedHistory = history
        saveTask = Task { [weak self, storage] in
            await previous?.value
            do { try await storage.save(catalog: snapshot, progress: savedProgress, cards: savedCards, history: savedHistory) }
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
    func deeperAccess(_ record: IdeaCardRecord) -> DiveDeeperAccess {
        guard let book = books.first(where: { $0.id == record.bookID }),
              let lesson = book.lessons.first(where: { $0.id == record.lessonID }) else {
            guard record.snapshot.hasDiveDeeper == true else { return .unavailable }
            return source(for: record.bookID).kind == .remoteCatalog ? .restoreRemote : .restoreManual
        }
        guard lesson.diveDeeper != nil else { return .unavailable }
        return status(book: book, lesson: lesson).practiceComplete ? .available : .locked
    }
    func deeperDestination(_ record: IdeaCardRecord) -> DiveDeeperDestination? {
        guard deeperAccess(record) == .available,
              let book = books.first(where: { $0.id == record.bookID }),
              let lesson = book.lessons.first(where: { $0.id == record.lessonID }), let content = lesson.diveDeeper else { return nil }
        return DiveDeeperDestination(content: content, sources: book.sources, lessonTitle: lesson.title)
    }
    func cardReview(_ record: IdeaCardRecord) async -> LessonLaunch? {
        if let book = books.first(where: { $0.id == record.bookID }), let lesson = book.lessons.first(where: { $0.id == record.lessonID }) {
            return LessonLaunch(book: book, lesson: lesson, review: true)
        }
        return nil
    }
    func source(for bookID: String) -> BookSourceRecord { history.first { $0.bookID == bookID }?.source ?? .manual }
    func refreshHistory(book: LearningBook) {
        guard let package = package(for: book) else { return }
        let index = history.firstIndex { $0.bookID == book.id }
        let previous = index.map { history[$0] }
        let updated = BookHistoryRecord.refresh(package, progress: progress, source: previous?.source ?? .manual, previous: previous)
        if let index { history[index] = updated } else { history.append(updated) }
    }
    func offload(_ book: LearningBook) async -> Bool {
        guard !readOnly, !isLoading, !isCommitting, !isPreparingImport else { return false }
        isCommitting = true; errorMessage = nil
        defer { isCommitting = false }
        await flush()
        do {
            let result = try await storage.offload(bookID: book.id, catalog: catalog, progress: progress, cards: cards, history: history)
            catalog = result.catalog; books = catalog.packages.map(\.book); installed = result.installed
            // Foreground learner-state changes remain authoritative even if disk work suspended.
            enqueueSave(); await flush()
            return true
        } catch {
            errorMessage = "Book could not be offloaded. Your installed book and learner state are preserved. \(error.localizedDescription)"
            return false
        }
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
            var nextHistory = history
            let historyIndex = nextHistory.firstIndex { $0.bookID == checked.package.book.id }
            let refreshed = BookHistoryRecord.refresh(checked.package, progress: nextProgress,
                source: staged.source ?? .manual, previous: historyIndex.map { nextHistory[$0] }, seenAt: Date())
            if let historyIndex { nextHistory[historyIndex] = refreshed } else { nextHistory.append(refreshed) }
            let nextInstalled = try await storage.save(catalog: next, progress: nextProgress, cards: cards, history: nextHistory)
            // Preserve any foreground progress changes made while disk work ran.
            let revisions = checked.revised.map { LessonProgress.key(bookID: checked.package.book.id, lesson: $0) }
            for id in revisions { progress[id] = nextProgress[id] }
            catalog = next; books = next.packages.map(\.book)
            // Preserve a completion event or actual engagement that occurred while
            // the import actor was writing; refreshed revision counts follow below.
            for index in nextHistory.indices {
                if let live = history.first(where: { $0.bookID == nextHistory[index].bookID }) {
                    if live.hasCompletedBefore == true {
                        nextHistory[index].hasCompletedBefore = true
                        nextHistory[index].firstCompletedAt = live.firstCompletedAt
                    }
                    nextHistory[index].lastOpenedAt = [live.lastOpenedAt, nextHistory[index].lastOpenedAt].compactMap { $0 }.max()
                }
            }
            history = nextHistory; installed = nextInstalled
            for book in books { refreshHistory(book: book) }
            lastImportWasNoOp = false
            importedBook = checked.package.book; importReview = nil
            enqueueSave()
        } catch {
            errorMessage = "Collection wasn't imported. \(error.localizedDescription)"
            enqueueSave()
        }
    }
}
