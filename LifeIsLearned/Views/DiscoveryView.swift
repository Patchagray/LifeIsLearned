import SwiftUI

@MainActor struct DiscoveryView: View {
    @EnvironmentObject private var library: LibraryStore
    @StateObject private var discovery: DiscoveryStore
    @StateObject private var download: BookDownloadManager
    @State private var query = ""
    @State private var shelfID: String?
    @State private var focusedID: String?
    init(endpoint: URL? = RemoteConfiguration.bundled().catalogURL, focusID: String? = nil) {
        _focusedID = State(initialValue: focusID)
        var endpoint = endpoint
        var directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        var configuration = URLSessionConfiguration.ephemeral
        #if DEBUG
        if DiscoveryFixtureProtocol.enabled {
            endpoint = URL(string: "https://h005-fixture.invalid/catalog.json")
            directory = FileManager.default.temporaryDirectory.appendingPathComponent(ProcessInfo.processInfo.environment["LIL_UI_TEST_RUN_ID"]!)
            configuration = DiscoveryFixtureProtocol.configuration()
        }
        #endif
        let identity = (try? CatalogIdentity.bundled()) ?? CatalogIdentity(catalogID: "catalog-001", catalogRevision: 1, shelves: [], books: [])
        _discovery = StateObject(wrappedValue: DiscoveryStore(endpoint: endpoint, directory: directory, identity: identity, session: URLSession(configuration: configuration)))
        _download = StateObject(wrappedValue: BookDownloadManager(directory: directory, configuration: configuration))
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Eyebrow(text: "The prepared library")
                Text("Find your next idea.").font(.system(.largeTitle, design: .serif))
                Text("Explore thoughtfully prepared collections. Each download includes the whole book collection.")
                    .foregroundStyle(Palette.secondary)
                if focusedID != nil { Button("Show all books") { focusedID = nil } }
                if let status = discovery.status { Label(status, systemImage: "info.circle").font(.footnote).foregroundStyle(Palette.secondary).accessibilityIdentifier("discovery-status") }
                Picker("Shelf", selection: $shelfID) {
                    Text("All shelves").tag(String?.none)
                    ForEach(discovery.identity.shelves) { Text($0.name).tag(Optional($0.id)) }
                }.pickerStyle(.menu).accessibilityIdentifier("discovery-shelf")
                if discovery.refreshing { HStack { ProgressView("Refreshing catalog"); Spacer(); Button("Cancel") { discovery.cancelRefresh() } } }
                if let catalog = discovery.catalog {
                    let books = focusedID.map { id in catalog.books.filter { $0.id == id } } ?? catalog.filtered(query: query, shelfID: shelfID)
                    if books.isEmpty { EmptyLearningView(title: "No matching books.", message: "Try another title, author or shelf.") }
                    LazyVStack(alignment: .leading, spacing: 24) {
                        ForEach(books) { book in
                            DiscoveryBookRow(book: book, service: discovery.service,
                                state: book.state(installed: library.installed.first { $0.bookID == book.id }, history: library.history.first { $0.bookID == book.id }),
                                busy: download.busy, canCancel: download.canCancel, progress: download.bookID == book.id ? download.progress : nil,
                                message: download.bookID == book.id ? download.message : nil, resumable: download.resumable,
                                start: { download.start(book, source: BookSourceRecord(kind: .remoteCatalog, catalogID: catalog.catalogID, catalogURL: discovery.endpoint), library: library) },
                                cancel: { download.cancel() })
                            FineRule()
                        }
                    }
                }
            }.padding(24).readingWidth()
        }.readingCanvas().navigationTitle("Browse Library").navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Title or author")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { discovery.refresh() } label: { Image(systemName: "arrow.clockwise") }.accessibilityLabel("Refresh catalog").disabled(discovery.refreshing || discovery.endpoint == nil) } }
            .onAppear { discovery.open() }
            .onChange(of: query) { _, _ in focusedID = nil }
            .onChange(of: shelfID) { _, _ in focusedID = nil }
            .onDisappear { discovery.cancelRefresh(); download.cancel() }
    }
}

private struct DiscoveryBookRow: View {
    let book: DiscoveryBook
    let service: DiscoveryService
    let state: DiscoveryBookState
    let busy: Bool
    let canCancel: Bool
    let progress: Double?
    let message: String?
    let resumable: Bool
    let start: () -> Void
    let cancel: () -> Void
    @State private var thumbnail: UIImage?
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 16) {
                Group {
                    if let thumbnail { Image(uiImage: thumbnail).resizable().scaledToFit() }
                    else { Image(systemName: "book.closed").font(.system(size: 30)).foregroundStyle(Palette.teal).frame(maxWidth: .infinity, maxHeight: .infinity).background(Palette.tint) }
                }.frame(width: 64, height: 88).clipShape(RoundedRectangle(cornerRadius: 7)).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(book.title).font(.system(.title3, design: .serif).weight(.medium)).fixedSize(horizontal: false, vertical: true)
                    Text(book.author).font(.subheadline).foregroundStyle(Palette.secondary)
                    Text(state.rawValue).font(.caption.weight(.semibold)).foregroundStyle(Palette.teal)
                }
            }
            if let progress, busy {
                ProgressView(value: progress).accessibilityLabel("Download progress").accessibilityValue("\(Int(progress * 100)) percent")
                if canCancel { Button("Cancel download", action: cancel).frame(minHeight: 44) }
            } else if state.canDownload {
                Button(resumable && progress != nil ? "Resume download" : state.rawValue, action: start)
                    .buttonStyle(.borderedProminent).foregroundStyle(Palette.onTeal).disabled(busy).accessibilityIdentifier("download-" + book.id)
            }
            if state == .comingSoon || state == .request {
                NavigationLink("Request this book") { BookRequestView(book: RecognizedBook(title: book.title, author: book.author, isbn13: book.isbn13.first ?? ""), catalogBookID: book.id, source: "library") }.frame(minHeight: 44)
            }
            if let message, message != "In Library" { Text(message).font(.footnote).foregroundStyle(Palette.secondary).accessibilityIdentifier("download-message") }
        }.accessibilityElement(children: .contain).accessibilityIdentifier("discovery-" + book.id)
            .task(id: book.thumbnail) {
                if let asset = book.thumbnail, let data = try? await service.thumbnail(asset) { thumbnail = UIImage(data: data) }
            }
    }
}
