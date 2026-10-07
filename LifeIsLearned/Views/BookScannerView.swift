import SwiftUI
import VisionKit
import AVFoundation

@MainActor struct BookScannerView: View {
    @StateObject private var discovery: DiscoveryStore
    @State private var recognized = RecognizedBook()
    @State private var matches: [BookMatch] = []
    @State private var searched = false
    @State private var camera = false
    @State private var cameraMessage: String?
    @State private var denied = false
    @FocusState private var editing: Bool
    init() {
        let identity = (try? CatalogIdentity.bundled()) ?? CatalogIdentity(catalogID: "catalog-001", catalogRevision: 1, shelves: [], books: [])
        var endpoint = RemoteConfiguration.bundled().catalogURL
        var config = URLSessionConfiguration.ephemeral
        #if DEBUG
        if DiscoveryFixtureProtocol.enabled { endpoint = URL(string: "https://h005-fixture.invalid/catalog.json"); config = DiscoveryFixtureProtocol.configuration() }
        #endif
        _discovery = StateObject(wrappedValue: DiscoveryStore(endpoint: endpoint, directory: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0], identity: identity, session: URLSession(configuration: config)))
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Eyebrow(text: "From your shelf to your library")
                Text("Find a book.").font(.system(.largeTitle, design: .serif))
                Text("Scan its ISBN barcode or cover text. Recognition stays on your device. You choose the match before downloading or requesting anything.").foregroundStyle(Palette.secondary)
                Button { Task { await openCamera() } } label: { Label("Open camera", systemImage: "viewfinder").frame(minHeight: 44) }
                if let cameraMessage { Text(cameraMessage).font(.subheadline).foregroundStyle(Palette.secondary).accessibilityIdentifier("scanner-fallback") }
                if denied { Button("Open Settings") { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } } }
                TextField("Title or cover text", text: $recognized.title).textFieldStyle(.roundedBorder).accessibilityIdentifier("scan-title").focused($editing)
                TextField("Author (optional)", text: $recognized.author).textFieldStyle(.roundedBorder).accessibilityIdentifier("scan-author").focused($editing)
                TextField("ISBN-13 (optional)", text: $recognized.isbn13).textFieldStyle(.roundedBorder).keyboardType(.numbersAndPunctuation).accessibilityIdentifier("scan-isbn").focused($editing)
                PrimaryButton(title: "Find matches", symbol: "magnifyingglass") {
                    editing = false
                    matches = discovery.catalog.map { BookMatcher.matches(recognized, catalog: $0) } ?? []; searched = true
                }
                if let status = discovery.status { Text(status).font(.footnote).foregroundStyle(Palette.secondary) }
                if searched {
                    FineRule()
                    Text(matches.isEmpty ? "No prepared match yet." : BookMatcher.isAmbiguous(matches) ? "Choose the book you meant." : "Review your match.").font(.system(.title2, design: .serif))
                    ForEach(matches.prefix(8)) { match in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(match.book.title).font(.headline)
                            Text(match.book.author).foregroundStyle(Palette.secondary)
                            Text(match.exactISBN ? "Exact ISBN match" : "Title / author match").font(.caption).foregroundStyle(Palette.teal)
                            if match.book.availability == .available {
                                NavigationLink("View prepared book") { DiscoveryView(endpoint: discovery.endpoint, focusID: match.id) }
                            } else {
                                NavigationLink("Request this book") { BookRequestView(book: RecognizedBook(title: match.book.title, author: match.book.author, isbn13: match.book.isbn13.first ?? ""), catalogBookID: match.id) }
                            }
                        }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(Palette.surface, in: RoundedRectangle(cornerRadius: 16))
                    }
                    NavigationLink(matches.isEmpty ? "Review details & request" : "None of these? Review your details") { BookRequestView(book: recognized) }
                        .frame(minHeight: 44)
                }
            }.padding(24).readingWidth()
        }.readingCanvas().navigationTitle("Scan a Book").navigationBarTitleDisplayMode(.inline)
            .onAppear { discovery.open() }.onDisappear { discovery.cancelRefresh() }
            .sheet(isPresented: $camera) { BookCameraView { recognized = $0; searched = false; camera = false } }
    }
    private func openCamera() async {
        guard DataScannerViewController.isSupported else { cameraMessage = BookCameraAvailability.unsupported.message; return }
        var allowed = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined { allowed = await AVCaptureDevice.requestAccess(for: .video) }
        let availability = BookCameraAvailability.evaluate(supported: true, permissionGranted: allowed, available: DataScannerViewController.isAvailable)
        denied = availability == .denied; cameraMessage = availability.message
        camera = availability == .ready
    }
}

private struct BookCameraView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var value = RecognizedBook()
    @State private var error: String?
    let use: (RecognizedBook) -> Void
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Eyebrow(text: "Look for a new idea")
                    Text("Hold the cover or ISBN barcode inside the frame.").font(.system(.title2, design: .serif))
                    NativeBookScanner(value: $value, error: $error).frame(height: 330)
                        .clipShape(RoundedRectangle(cornerRadius: 24)).overlay(RoundedRectangle(cornerRadius: 24).stroke(Palette.teal, lineWidth: 2))
                    if let error { Text(error).foregroundStyle(Palette.amber) }
                    Text(value.isbn13.isEmpty ? value.title : "ISBN " + value.isbn13).font(.subheadline).lineLimit(5)
                    Text("On-device recognition · no images are uploaded").font(.footnote).foregroundStyle(Palette.secondary)
                    PrimaryButton(title: "Review recognized details", symbol: "checkmark") { use(value) }
                        .disabled(value.title.isEmpty && value.isbn13.isEmpty)
                }.padding(24).readingWidth()
            }.readingCanvas().navigationTitle("Scan a Book").toolbar { Button("Cancel") { dismiss() } }
        }
    }
}
private struct NativeBookScanner: UIViewControllerRepresentable {
    @Binding var value: RecognizedBook
    @Binding var error: String?
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(recognizedDataTypes: [.barcode(symbologies: [.ean13]), .text()], qualityLevel: .accurate,
                                               recognizesMultipleItems: true, isGuidanceEnabled: false, isHighlightingEnabled: true)
        scanner.delegate = context.coordinator
        do { try scanner.startScanning() } catch { DispatchQueue.main.async { self.error = "Recognition could not start. Close the camera and type the book details." } }
        return scanner
    }
    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) { context.coordinator.parent = self }
    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) { scanner.stopScanning() }
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var parent: NativeBookScanner
        init(_ parent: NativeBookScanner) { self.parent = parent }
        func update(_ items: [RecognizedItem]) {
            var titles: [String] = [], isbn = ""
            for item in items {
                switch item {
                case .text(let text): titles.append(text.transcript)
                case .barcode(let barcode): if let payload = barcode.payloadStringValue, ISBN.isValid(payload) { isbn = payload }
                @unknown default: break
                }
            }
            parent.value = RecognizedBook(title: titles.joined(separator: " "), isbn13: isbn)
        }
        func dataScanner(_ scanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) { update(allItems) }
        func dataScanner(_ scanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem], allItems: [RecognizedItem]) { update(allItems) }
        func dataScanner(_ scanner: DataScannerViewController, becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable) { parent.error = "Camera recognition is unavailable. Close the camera to use text search." }
    }
}
