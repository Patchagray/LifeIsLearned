import SwiftUI
import UniformTypeIdentifiers

@MainActor struct LibraryView: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var settings: PlaybackSettings
    @EnvironmentObject private var speech: NarrationController
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var importing = false
    @State private var showingIdeas = false
    @State private var showingHistory = false
    @State private var addingBooks = false
    @State private var exploring = false
    @StateObject private var explore = ExploreSession()
    @State private var scanning = false
    @State private var showingSettings = false
    @State private var search = ""
    @State private var launch: LessonLaunch?
    @State private var selectedBook: LearningBook?
    @State private var completedBook: LearningBook?
    init(initialSearch: String = "") { _search = State(initialValue: initialSearch) }
    private var filteredBooks: [LearningBook] {
        let term = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return term.isEmpty ? library.books : library.books.filter { ($0.title + " " + $0.author).localizedStandardContains(term) }
    }
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    if library.readOnly {
                        Label("Recovery mode: saved files are preserved. You can read, but progress and imports cannot be saved until recovery.", systemImage: "exclamationmark.circle")
                            .font(.subheadline).foregroundStyle(Palette.amber)
                    }
                    if library.isLoading {
                        ProgressView("Opening your reading room…").frame(maxWidth: .infinity).padding(.vertical, 80)
                    } else if let destination = library.continueLearning {
                        ContinueLearningFeature(destination: destination, assets: library.package(for: destination.book)?.artwork ?? [:]) {
                            // Show the selection/coverage preface before a first start.
                            if destination.action == .revisit || destination.action == .start { selectedBook = destination.book }
                            else { launch = LessonLaunch(book: destination.book, lesson: destination.lesson) }
                        }
                    } else {
                        EmptyLearningView(title: "Make room for a new idea.", message: "Add a prepared book collection to begin reading, listening, and practicing at your own pace.")
                        PrimaryButton(title: "Add your first book", symbol: "plus") { addingBooks = true }
                    }
                    FineRule()
                    VStack(alignment: .leading, spacing: 24) {
                        Picker("Library section", selection: $exploring) {
                            Text("Your Library").tag(false)
                            Text("Explore").tag(true)
                        }.pickerStyle(.segmented).accessibilityIdentifier("library-mode")
                        if exploring {
                            DiscoveryView(session: explore) { selectedBook = $0 }
                        } else { librarySection }
                    }.id("library-section")
                    if !library.history.isEmpty {
                        Button { speech.stop(); showingHistory = true } label: {
                            Label("History", systemImage: "clock.arrow.circlepath").font(.subheadline).frame(minHeight: 44)
                        }.accessibilityIdentifier("library-history")
                    }
                }.padding(24).readingWidth(Layout.homeWidth)
            }.readingCanvas()
                .onChange(of: exploring) { _, _ in proxy.scrollTo("library-section", anchor: .top) }
                .onChange(of: explore.focusID) { _, _ in proxy.scrollTo("library-section", anchor: .top) }
            }
                .navigationTitle("Life Is Learned").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { speech.stop(); showingIdeas = true } label: { Image(systemName: "rectangle.stack").frame(minWidth: 44, minHeight: 44) }
                            .accessibilityLabel("Ideas").disabled(library.isLoading)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { addingBooks = true } label: { Image(systemName: "plus").frame(minWidth: 44, minHeight: 44) }
                            .accessibilityLabel("Add Books").disabled(library.isLoading || library.readOnly)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { speech.stop(); showingSettings = true } label: { Image(systemName: "slider.horizontal.3").frame(minWidth: 44, minHeight: 44) }
                            .accessibilityLabel("Playback settings")
                    }
                }
                .navigationDestination(isPresented: $scanning) { BookScannerView { focusExplore($0) } }
                .navigationDestination(isPresented: $showingHistory) { BookHistoryView() }
                .navigationDestination(isPresented: $showingIdeas) { IdeaCollectionView() }
                .navigationDestination(item: $selectedBook) { BookDetailView(book: $0) }
                .overlay { if library.isPreparingImport { importLoading } }
        }
        .onChange(of: library.restoreBookID) { _, bookID in
            guard let bookID else { return }
            if library.source(for: bookID).kind == .manualImport { importing = true }
            else {
                focusExplore(bookID)
            }
            library.restoreBookID = nil
        }
        .confirmationDialog("Add Books", isPresented: $addingBooks, titleVisibility: .visible) {
            Button("Scan a Book") { scanning = true }
            Button("Import File") { importing = true }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showingSettings) { SettingsView() }
        .sheet(isPresented: Binding(get: { library.importReview != nil || library.importedBook != nil }, set: {
            if !$0 { library.cancelImport(); library.importedBook = nil }
        })) {
            if let book = library.importedBook {
                ImportSuccessView(book: book, alreadyImported: library.lastImportWasNoOp) { library.importedBook = nil; selectedBook = book }
            } else if let review = library.importReview {
                ImportReviewView(review: review).environmentObject(library)
            }
        }
        .fullScreenCover(item: $launch, onDismiss: {
            if let book = completedBook { selectedBook = book; completedBook = nil }
        }) { selected in
            LessonJourneyView(launch: selected, store: library, speech: speech, settings: settings,
                              onBook: { completedBook = $0 })
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url): Task { await library.prepareImport(from: url) }
            case .failure(let error): library.errorMessage = error.localizedDescription
            }
        }
        .alert("Your library", isPresented: Binding(get: { library.errorMessage != nil && library.importReview == nil }, set: { if !$0 { library.errorMessage = nil } })) {
            Button("OK") { library.errorMessage = nil }
        } message: { Text(library.errorMessage ?? "") }
    }
    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .firstTextBaseline) {
                Text("Your library").font(.system(.title2, design: .serif).weight(.medium))
                Spacer()
                Text("\(filteredBooks.count + offloadedBooks.count) \(filteredBooks.count + offloadedBooks.count == 1 ? "collection" : "collections")")
                    .accessibilityIdentifier("library-count")
                    .font(.caption).foregroundStyle(Palette.secondary)
            }
            Group {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(Palette.secondary)
                    TextField("Search your library", text: $search).textInputAutocapitalization(.never).autocorrectionDisabled().submitLabel(.search)
                        .accessibilityLabel("Search library").accessibilityIdentifier("library-search")
                    if !search.isEmpty {
                        Button { search = "" } label: { Image(systemName: "xmark.circle.fill").frame(minWidth: 44, minHeight: 44) }.accessibilityLabel("Clear search")
                    }
                }.padding(.horizontal, 14).frame(minHeight: 48)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.rule, lineWidth: 1))
            }
            if filteredBooks.isEmpty && offloadedBooks.isEmpty {
                EmptyLearningView(title: search.isEmpty ? "Your next idea starts here." : "No books found.", message: search.isEmpty ? "Explore prepared collections or import a book file. Your downloaded books will live here." : "Try another title or author, or clear your search.")
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 260 : 145, maximum: typeSize.isAccessibilitySize ? 360 : 230), spacing: 24, alignment: .top)], alignment: .leading, spacing: 32) {
                    ForEach(filteredBooks) { book in
                        Button { selectedBook = book } label: {
                            LibraryBookCard(book: book, assets: library.package(for: book)?.artwork ?? [:], practiced: book.lessons.filter { library.status(book: book, lesson: $0).practiceComplete }.count)
                        }.buttonStyle(EditorialButtonStyle()).accessibilityIdentifier("book-" + book.id)
                    }
                }
            }
            ForEach(offloadedBooks) { record in
                VStack(alignment: .leading, spacing: 10) {
                    Text(record.title).font(.system(.title3, design: .serif))
                    Text(record.author).font(.subheadline).foregroundStyle(Palette.secondary)
                    Label("Offloaded · \(record.lastKnownPracticedCount) / \(record.lastKnownIdeaCount) ideas practiced", systemImage: "icloud.and.arrow.down").font(.caption)
                    Button(record.source.kind == .remoteCatalog ? "Restore" : "Re-import book") { library.restoreBookID = record.bookID }
                        .frame(minHeight: 44).accessibilityIdentifier("local-restore-" + record.bookID)
                }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16))
            }
            Text("Thoughtfully prepared. One idea at a time.").font(.footnote).foregroundStyle(Palette.secondary)
        }
    }
    private var offloadedBooks: [BookHistoryRecord] {
        let term = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return library.history.filter { record in
            !library.books.contains { $0.id == record.bookID } &&
            (term.isEmpty || (record.title + " " + record.author).localizedStandardContains(term))
        }
    }
    private func focusExplore(_ id: String) {
        scanning = false; showingHistory = false; showingIdeas = false; selectedBook = nil
        explore.query = ""; explore.shelfID = nil; explore.focusID = id; exploring = true
    }
    private var importLoading: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Reviewing your collection…").font(.headline)
            Text("Checking ideas, sources, and shared artwork.").font(.subheadline).foregroundStyle(Palette.secondary)
            Button("Cancel") { library.cancelImport() }.frame(minHeight: 44)
        }.padding(28).background(Palette.surface, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Palette.rule, lineWidth: 1)).padding(24)
    }
}

extension LearningBook: Hashable {
    static func == (lhs: LearningBook, rhs: LearningBook) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
