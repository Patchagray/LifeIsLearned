#if DEBUG
import Foundation

/// Synthetic UI/performance fixture. Invoked only from an explicitly isolated
/// UUID test installation; never populates a person's normal library.
@MainActor enum IdeaCardFixture {
    static func installSixStages(in store: LibraryStore) async throws {
        await store.ready()
        guard !store.books.contains(where: { $0.id == "six-stage-fixture" }),
              let url = Bundle.main.url(forResource: "starter", withExtension: "json") else { return }
        var package = try JSONDecoder().decode(LessonPackage.self, from: Data(contentsOf: url))
        let original = package.book.lessons[0].pages[0]
        package.book.id = "six-stage-fixture"
        package.book.title = "Six-stage interface fixture"
        package.book.author = "Synthetic verification only"
        package.book.isDemo = nil
        package.book.synopsis = "A synthetic reader journey."
        package.book.coverageNote = "Existing illustration reused for UI verification only. Not an authored release or book summary."
        package.book.lessons[0].id = "six-stage-idea"
        package.book.lessons[0].title = "Six-stage reader"
        package.book.lessons[0].pages = (0..<6).map { index in
            var page = original
            page.id = "stage-\(index)"; page.kind = SixStageLesson.kinds[index]
            page.role = (index == 2 || index == 3) ? .storyteller : .guide
            page.title = SixStageLesson.readerLabels[index]
            page.text = "Synthetic screen for interface verification. Existing artwork is reused here solely to check layout and accessibility. This is not an authored lesson."
            page.imageDescription = "Synthetic illustration for stage \(index + 1)"
            return page
        }
        package.manifest = package.book.lessons.map { IdeaManifestEntry(id: $0.id, revision: $0.revision) }
        let review = try await store.storage.review(package: package, catalog: store.catalog)
        await store.commitImport(review)
        store.importedBook = nil
        guard store.errorMessage == nil else { throw PackageError.invalid(store.errorMessage!) }
        await store.flush()
    }

    static func install(in store: LibraryStore) async throws {
        await store.ready()
        guard !store.books.contains(where: { $0.id == "card-fixture-a" }) else { return }
        guard let url = Bundle.main.url(forResource: "starter", withExtension: "json") else { return }
        let seed = try JSONDecoder().decode(LessonPackage.self, from: Data(contentsOf: url))
        let titles = ["Leave room for another explanation", "Listen before deciding", "Notice your starting point", "Make space for a question", "Look for a different view", "Pause before the answer", "Hold an idea lightly", "Let evidence change your mind", "Consider the context", "Return to what matters", "Take a smaller step", "Keep learning"]
        for number in 0..<2 {
            var package = seed
            package.book.id = number == 0 ? "card-fixture-a" : "card-fixture-b"
            package.book.title = number == 0 ? "The Art of Paying Attention" : "A Practice of Curiosity"
            package.book.author = "Synthetic interface fixture"
            package.book.isDemo = nil
            package.book.coverageNote = "Synthetic UI fixture; repeats starter content. Not a book summary or reviewed new lesson collection."
            package.book.lessons = (0..<12).map { index in
                var lesson = seed.book.lessons[0]
                lesson.id = "card-\(index)"; lesson.title = titles[index]
                return lesson
            }
            package.manifest = package.book.lessons.map { IdeaManifestEntry(id: $0.id, revision: $0.revision) }
            let review = try await store.storage.review(package: package, catalog: store.catalog)
            await store.commitImport(review)
            store.importedBook = nil
            guard store.errorMessage == nil else { throw PackageError.invalid(store.errorMessage!) }
            for (index, lesson) in package.book.lessons.enumerated() {
                let earned = number == 0 ? index >= 2 : index < 10
                store.update(book: package.book, lesson: lesson) {
                    $0.phase = earned ? .complete : index == 0 ? .practice : .reading
                    $0.pageIndex = earned ? lesson.pages.count - 1 : index == 1 ? 2 : 0
                    $0.practiceComplete = earned; $0.questionCount = earned ? 2 : 0
                    $0.firstTryCorrect = earned ? 1 : 0
                    $0.practicedAt = earned ? Date(timeIntervalSince1970: 1_770_000_000 + Double(number * 12 + index) * 86400) : nil
                }
                if earned && index % 3 == 0 {
                    store.toggleFavorite(LessonProgress.identity(bookID: package.book.id, lessonID: lesson.id))
                }
            }
        }
        store.importedBook = nil
        await store.flush()
    }
}
#endif
