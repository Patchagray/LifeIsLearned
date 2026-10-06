import SwiftUI

@MainActor struct IdeaCollectionView: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var settings: PlaybackSettings
    @EnvironmentObject private var speech: SpeechPlayer
    @State private var selectedID: String?
    @State private var detailsID: String?
    @State private var carousel: Bool
    @State private var favoritesOnly = false
    @State private var bookID: String?
    @State private var sort: IdeaCardSort = .recent
    @State private var launch: LessonLaunch?
    @State private var selectedBook: LearningBook?
    @State private var unavailableSource = false
    @State private var openingSource = false
    init(initialCardID: String? = nil) {
        _selectedID = State(initialValue: initialCardID)
        _carousel = State(initialValue: initialCardID != nil)
    }
    private var orderedCards: [IdeaCardRecord] {
        IdeaCardCollection.ordered(Array(library.cards.values), books: library.books, sort: sort)
    }
    private var cards: [IdeaCardPresentation] {
        IdeaCardCollection.select(from: orderedCards, favoritesOnly: favoritesOnly, bookID: bookID).map(library.cardPresentation)
    }
    private var bookOptions: [(id: String, title: String)] {
        let groups = Dictionary(grouping: orderedCards, by: \.bookID)
        return groups.keys.sorted().compactMap { id in groups[id]?.first.map { (id, $0.snapshot.bookTitle) } }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }
    var body: some View {
        GeometryReader { proxy in
            let viewport = proxy.frame(in: .global)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 10) {
                        Eyebrow(text: "Keep the useful things")
                        Text("Your ideas.").font(.system(.largeTitle, design: .serif))
                        Text("\(library.cards.count) collected · a little wisdom to return to")
                            .font(.subheadline).foregroundStyle(Palette.secondary)
                        controls
                    }.padding(.horizontal, 24).readingWidth(868)
                    if cards.isEmpty {
                        VStack(spacing: 22) {
                            Image(systemName: favoritesOnly ? "star" : "rectangle.stack").font(.system(size: 42, weight: .light)).foregroundStyle(Palette.teal)
                            Text(favoritesOnly ? "Star an idea you want to keep close." : library.cards.isEmpty ? "Finish an idea to collect your first card." : "No ideas in this selection.")
                                .font(.system(.title2, design: .serif)).multilineTextAlignment(.center)
                            if favoritesOnly || bookID != nil { Button("Show all ideas") { favoritesOnly = false; bookID = nil }.frame(minHeight: 44) }
                        }.padding(28).padding(.vertical, 40).frame(maxWidth: .infinity)
                    } else if carousel {
                        IdeaCardCarousel(cards: cards, selectedID: $selectedID, viewport: viewport, availableWidth: proxy.size.width,
                                         detailsID: detailsID,
                                         canFavorite: !library.readOnly, favorite: library.toggleFavorite, review: review)
                    } else {
                        IdeaCardGrid(cards: cards, viewport: viewport, canFavorite: !library.readOnly,
                            favorite: library.toggleFavorite, open: { id in selectedID = id; detailsID = nil; carousel = true },
                            showDetails: { id in selectedID = id; detailsID = id; carousel = true },
                            availableWidth: max(0, proxy.size.width - 48))
                            .padding(.horizontal, 24)
                    }
                }.padding(.vertical, 24)
            }.accessibilityIdentifier("ideas-scroll")
        }.readingCanvas().navigationTitle("Ideas").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { carousel.toggle(); if selectedID == nil { selectedID = cards.first?.id } } label: {
                        Image(systemName: carousel ? "square.grid.2x2" : "rectangle.portrait.on.rectangle.portrait").frame(width: 44, height: 44)
                    }.accessibilityLabel(carousel ? "Show grid" : "Show carousel")
                }
            }
            .onChange(of: cards.map(\.id)) { _, ids in
                if !ids.contains(selectedID ?? "") { selectedID = ids.first }
            }
            .onAppear { speech.stop() }
            .overlay { if openingSource { ProgressView("Opening the lesson…").padding(24).background(Palette.surface, in: RoundedRectangle(cornerRadius: 16)) } }
            .fullScreenCover(item: $launch) { selected in
                LessonJourneyView(launch: selected, store: library, speech: speech, settings: settings, onBook: { book in
                    selectedBook = library.books.first { $0.id == book.id }
                })
            }
            .navigationDestination(item: $selectedBook) { BookDetailView(book: $0) }
            .alert("Your collected idea", isPresented: $unavailableSource) {
                Button("OK", role: .cancel) { }
            } message: { Text("The original lesson is no longer available in saved content. Your collected card and favorite are preserved.") }
    }
    private var controls: some View {
        ViewThatFits(in: .horizontal) {
            HStack { scopeControls; Spacer(minLength: 8); filterMenu }
            VStack(alignment: .leading) { scopeControls; filterMenu }
        }.padding(.top, 12)
    }
    private var scopeControls: some View {
        HStack(spacing: 8) {
            scopeButton("All", selected: !favoritesOnly) { favoritesOnly = false; bookID = nil }
            scopeButton("Favorites", selected: favoritesOnly) { favoritesOnly = true }
        }
    }
    private func scopeButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(title).font(.subheadline.weight(.medium)).padding(.horizontal, 16).frame(minHeight: 44)
                .background(selected ? Palette.teal : Palette.surface, in: Capsule()).foregroundStyle(selected ? Palette.onTeal : Palette.ink) }
            .buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }
    private var filterMenu: some View {
        Menu {
            Picker("Sort", selection: $sort) { ForEach(IdeaCardSort.allCases) { Text($0.rawValue).tag($0) } }
            Picker("Book", selection: $bookID) {
                Text("All books").tag(String?.none)
                ForEach(bookOptions, id: \.id) { Text($0.title).tag(Optional($0.id)) }
            }
        } label: {
            Label(bookID == nil ? "Sort & book" : "Book selected", systemImage: "line.3.horizontal.decrease")
                .font(.subheadline).frame(minHeight: 44)
        }.accessibilityLabel("Filter and sort ideas")
    }
    private func review(_ record: IdeaCardRecord) {
        guard !openingSource else { return }
        speech.stop(); openingSource = true
        Task {
            let destination = await library.cardReview(record)
            openingSource = false
            if let destination { launch = destination } else { unavailableSource = true }
        }
    }
}
