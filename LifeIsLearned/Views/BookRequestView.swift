import SwiftUI

@MainActor struct BookRequestView: View {
    @StateObject private var model: BookRequestModel
    init(book: RecognizedBook, catalogBookID: String? = nil, source: String = "scanner") {
        var client: any BookRequestSubmitting = HTTPBookRequestClient(endpoint: RemoteConfiguration.bundled().requestURL)
        #if DEBUG
        if DiscoveryFixtureProtocol.enabled {
            client = HTTPBookRequestClient(endpoint: URL(string: "https://h005-fixture.invalid/requests"), session: URLSession(configuration: DiscoveryFixtureProtocol.configuration()))
        }
        #endif
        _model = StateObject(wrappedValue: BookRequestModel(book: book, catalogBookID: catalogBookID, source: source, client: client))
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Eyebrow(text: "Help shape the library")
                Text("An idea for what comes next.").font(.system(.largeTitle, design: .serif))
                if model.receipt != nil {
                    Label("Requested", systemImage: "checkmark.circle.fill").font(.title2).foregroundStyle(Palette.teal)
                    Text("We'll use requests to prioritize the library.").accessibilityIdentifier("request-success")
                    Text("Every collection is prepared and reviewed before it becomes available.").foregroundStyle(Palette.secondary)
                } else {
                    Text("Review these details before sending. Only this book metadata is shared; camera images stay on your device.").foregroundStyle(Palette.secondary)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Title").font(.caption); TextField("Book title", text: $model.title).textFieldStyle(.roundedBorder).accessibilityIdentifier("request-title")
                        Text("Author · optional").font(.caption); TextField("Author", text: $model.author).textFieldStyle(.roundedBorder)
                        Text("ISBN-13 · optional").font(.caption); TextField("978…", text: $model.isbn).textFieldStyle(.roundedBorder).keyboardType(.numbersAndPunctuation)
                    }.disabled(model.sending || model.catalogBookID != nil)
                    if let error = model.error { Text(error).foregroundStyle(Palette.amber).font(.subheadline) }
                    if model.sending { ProgressView("Sending request…") }
                    PrimaryButton(title: "Request this book", symbol: "paperplane") { Task { await model.request() } }.disabled(model.sending)
                }
            }.padding(24).readingWidth()
        }.readingCanvas().navigationTitle("Request a Book").navigationBarTitleDisplayMode(.inline)
    }
}
