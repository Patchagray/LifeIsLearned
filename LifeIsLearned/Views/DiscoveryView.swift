import SwiftUI

/// Owned by the home screen: switching sections keeps filters, cache and transfers alive.
@MainActor final class ExploreSession: ObservableObject {
    @Published var query = ""
    @Published var shelfID: String?
    @Published var focusID: String?
    let discovery: DiscoveryStore
    let download: BookDownloadManager
    private var opened = false
    init() {
        var endpoint = RemoteConfiguration.bundled().catalogURL
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
        discovery = DiscoveryStore(endpoint: endpoint, directory: directory, identity: identity, session: URLSession(configuration: configuration))
        download = BookDownloadManager(directory: directory, configuration: configuration)
    }
    func open() { guard !opened else { return }; opened = true; discovery.open() }
}

/// In-place section, intentionally without its own navigation or scroll container.
@MainActor struct DiscoveryView: View {
    @EnvironmentObject private var library: LibraryStore
    @ObservedObject var session: ExploreSession
    @ObservedObject private var discovery: DiscoveryStore
    @ObservedObject private var download: BookDownloadManager
    let openBook: (LearningBook) -> Void
    init(session: ExploreSession, openBook: @escaping (LearningBook) -> Void) {
        self.session = session; self.openBook = openBook
        discovery = session.discovery; download = session.download
    }
    private var books: [DiscoveryBook] {
        guard let catalog = discovery.catalog else { return [] }
        return session.focusID.map { id in catalog.books.filter { $0.id == id } }
            ?? catalog.filtered(query: session.query, shelfID: session.shelfID)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .firstTextBaseline) {
                Text("Find your next idea.").font(.system(.title2, design: .serif))
                Spacer()
                Button { discovery.refresh() } label: { Image(systemName: "arrow.clockwise").frame(minWidth: 44, minHeight: 44) }
                    .accessibilityLabel("Refresh catalog").disabled(discovery.refreshing)
            }
            Text("Prepared collections, ready when you are. Download a whole book to learn offline.").font(.subheadline).foregroundStyle(Palette.secondary)
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(Palette.secondary)
                TextField("Search Explore", text: Binding(get: { session.query }, set: { session.focusID = nil; session.query = $0 })).textInputAutocapitalization(.never).autocorrectionDisabled().submitLabel(.search)
                    .accessibilityLabel("Search Explore").accessibilityIdentifier("explore-search")
                if !session.query.isEmpty {
                    Button { session.query = "" } label: { Image(systemName: "xmark.circle.fill").frame(minWidth: 44, minHeight: 44) }.accessibilityLabel("Clear Explore search")
                }
            }.padding(.horizontal, 14).frame(minHeight: 48).background(Palette.surface, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.rule, lineWidth: 1))
            if session.focusID != nil { Button("Show all books") { session.focusID = nil } }
            Picker("Shelf", selection: Binding(get: { session.shelfID }, set: { session.focusID = nil; session.shelfID = $0 })) {
                Text("All shelves").tag(String?.none)
                ForEach(discovery.identity.shelves) { Text($0.name).tag(Optional($0.id)) }
            }.pickerStyle(.menu).accessibilityIdentifier("discovery-shelf")
            Text("\(books.count) \(books.count == 1 ? "title" : "titles")").font(.caption).foregroundStyle(Palette.secondary).accessibilityIdentifier("explore-count")
            if let status = discovery.status { Label(status, systemImage: "info.circle").font(.footnote).foregroundStyle(Palette.secondary).accessibilityIdentifier("discovery-status") }
            if discovery.refreshing { HStack { ProgressView("Refreshing catalog"); Spacer(); Button("Cancel refresh") { discovery.cancelRefresh() } } }
            if books.isEmpty { EmptyLearningView(title: "No matching books.", message: session.focusID == nil ? "Try another title, author or shelf. Refresh to check for new releases." : "This book is not in the current public catalog. Your progress and cards remain saved. You can re-import its complete book file.") }
            LazyVStack(alignment: .leading, spacing: 24) {
                ForEach(books) { book in
                    DiscoveryBookRow(book: book, service: discovery.service,
                        shelf: discovery.identity.shelves.first { $0.id == book.primaryShelfID }?.name ?? "",
                        state: book.state(installed: library.installed.first { $0.bookID == book.id }, history: library.history.first { $0.bookID == book.id }),
                        busy: download.busy, canCancel: download.canCancel, progress: download.bookID == book.id ? download.progress : nil,
                        message: download.bookID == book.id ? download.message : nil,
                        failed: download.bookID == book.id && download.failed, resumable: download.bookID == book.id && download.resumable,
                        start: {
                            guard let catalog = discovery.catalog else { return }
                            download.start(book, source: BookSourceRecord(kind: .remoteCatalog, catalogID: catalog.catalogID, catalogURL: discovery.endpoint), library: library)
                        }, cancel: { download.cancel() }, open: {
                            if let installed = library.books.first(where: { $0.id == book.id }) { openBook(installed) }
                        })
                    FineRule()
                }
            }
        }.onAppear { session.open() }

    }
}

private struct DiscoveryBookRow: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let book: DiscoveryBook
    let service: DiscoveryService
    let shelf: String
    let state: DiscoveryBookState
    let busy: Bool
    let canCancel: Bool
    let progress: Double?
    let message: String?
    let failed: Bool
    let resumable: Bool
    let start: () -> Void
    let cancel: () -> Void
    let open: () -> Void
    @State private var thumbnail: UIImage?
    @State private var details = false
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button { details.toggle() } label: {
                Group {
                    if typeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(alignment: .top) { cover; Spacer(); disclosure }
                            bookHeading
                        }
                    } else {
                        HStack(alignment: .top, spacing: 16) {
                            cover; bookHeading; Spacer(minLength: 0); disclosure
                        }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel("\(book.title), \(book.author), \(state.status), book details")
                .accessibilityIdentifier("details-" + book.id).accessibilityValue((details ? "Expanded" : "Collapsed") + (thumbnail != nil ? ", cover preview loaded" : ""))
            if details {
                Text(shelf).font(.caption.weight(.semibold)).foregroundStyle(Palette.teal)
                if let description = book.description, !description.isEmpty { Text(description).font(.subheadline) }
                else { Text(book.availability == .available ? "Download this complete collection for offline learning. Review the book’s coverage and sources before starting." : "A prepared collection is planned for this title. Full coverage details appear when a release is available.").font(.subheadline).foregroundStyle(Palette.secondary) }
                if !book.tags.isEmpty { Text(book.tags.joined(separator: " · ")).font(.caption).foregroundStyle(Palette.secondary) }
                if let package = book.package { Text("Collection revision \(package.collectionRevision) · \(ByteCountFormatter.string(fromByteCount: Int64(package.bytes), countStyle: .file))").font(.caption) }
            }
            if let progress, busy {
                ProgressView(value: progress).accessibilityLabel("Download progress").accessibilityValue("\(Int(progress * 100)) percent")
                if canCancel { Button("Cancel download", action: cancel).frame(minHeight: 44) }
            } else if state.canDownload {
                Button(resumable ? "Resume download" : failed ? "Retry download" : state.rawValue, action: start)
                    .buttonStyle(.borderedProminent).foregroundStyle(Palette.onTeal).disabled(busy).accessibilityIdentifier("download-" + book.id)
            }
            if state == .inLibrary || state == .update { Button("Open book", action: open).frame(minHeight: 44).accessibilityIdentifier("open-discovery-" + book.id) }
            if state == .comingSoon || state == .request || state == .offloadedUnavailable {
                NavigationLink("Request this book") { BookRequestView(book: RecognizedBook(title: book.title, author: book.author, isbn13: book.isbn13.first ?? ""), catalogBookID: book.id, source: "library") }.frame(minHeight: 44)
            }
            if let message, message != "In Library" { Text(message).font(.footnote).foregroundStyle(Palette.secondary).accessibilityIdentifier("download-message") }
        }.accessibilityElement(children: .contain).accessibilityIdentifier("discovery-" + book.id)
            .task(id: book.thumbnail) {
                thumbnail = nil
                if let asset = book.thumbnail, let data = try? await service.thumbnail(asset) { thumbnail = UIImage(data: data) }
            }
    }
    private var cover: some View {
        Group {
            if let thumbnail { Image(uiImage: thumbnail).resizable().scaledToFit() }
            else { Image(systemName: "book.closed").font(.system(size: 30)).foregroundStyle(Palette.teal).frame(maxWidth: .infinity, maxHeight: .infinity).background(Palette.tint) }
        }.frame(width: 64, height: 88).clipShape(RoundedRectangle(cornerRadius: 7)).accessibilityHidden(true)
    }
    private var bookHeading: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(book.title).font(.system(.title3, design: .serif).weight(.medium)).fixedSize(horizontal: false, vertical: true)
            Text(book.author).font(.subheadline).foregroundStyle(Palette.secondary)
            Text(failed ? "Failed · try again" : progress != nil && busy ? "Downloading" : state.status)
                .font(.caption.weight(.semibold)).foregroundStyle(failed ? Palette.amber : Palette.teal)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private var disclosure: some View {
        Image(systemName: "chevron.down").rotationEffect(.degrees(details ? 180 : 0))
            .font(.caption).foregroundStyle(Palette.secondary).accessibilityHidden(true)
            .transaction { $0.animation = nil }
    }

}
