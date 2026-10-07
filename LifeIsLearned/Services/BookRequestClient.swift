import Foundation
import Combine

protocol BookRequestSubmitting: Sendable { func submit(_ request: BookRequest) async throws -> BookRequestReceipt }
struct HTTPBookRequestClient: BookRequestSubmitting {
    let endpoint: URL?
    var session: URLSession = .shared
    func submit(_ value: BookRequest) async throws -> BookRequestReceipt {
        guard let endpoint else { throw PackageError.invalid("Book requests are not connected yet. Your book details have not been sent.") }
        try RemoteURL.validate(endpoint)
        var request = URLRequest(url: endpoint); request.httpMethod = "POST"; request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(value.validated())
        try CollectionLimits.require(request.httpBody!.count <= 2_048, "Book details exceed the request size limit.")
        let (bytes, response) = try await session.bytes(for: request, delegate: HTTPSRedirectDelegate())
        defer { bytes.task.cancel() }
        guard let http = response as? HTTPURLResponse, let final = http.url else { throw PackageError.invalid("The request service did not respond.") }
        try RemoteURL.validate(final)
        if http.statusCode == 429 { throw PackageError.invalid("Too many requests right now. Please wait a minute before trying again.") }
        guard http.statusCode == 200 || http.statusCode == 201 else { throw PackageError.invalid("Your request could not be confirmed. Please try again later.") }
        var data = Data()
        for try await byte in bytes {
            try CollectionLimits.require(data.count < 4_096, "The request response is too large.")
            data.append(byte)
        }
        let receipt = try JSONDecoder().decode(BookRequestReceipt.self, from: data)
        try CollectionLimits.require(receipt.status == "accepted" && !receipt.requestKey.isEmpty && receipt.requestCount > 0,
                                     "Your request could not be confirmed.")
        return receipt
    }
}
@MainActor final class BookRequestModel: ObservableObject {
    @Published var title: String
    @Published var author: String
    @Published var isbn: String
    @Published private(set) var sending = false
    @Published private(set) var receipt: BookRequestReceipt?
    @Published private(set) var error: String?
    let catalogBookID: String?
    let source: String
    private let client: any BookRequestSubmitting
    init(book: RecognizedBook, catalogBookID: String? = nil, source: String = "scanner", client: any BookRequestSubmitting) {
        title = book.title; author = book.author; isbn = book.isbn13; self.catalogBookID = catalogBookID; self.source = source; self.client = client
    }
    // Called only by the learner's explicit Request action. No init/onAppear submission.
    func request() async {
        guard !sending, receipt == nil else { return }
        sending = true; error = nil; defer { sending = false }
        do { receipt = try await client.submit(BookRequest(catalogBookID: catalogBookID, title: title, author: author, isbn13: isbn, source: source).validated()) }
        catch { self.error = error.localizedDescription }
    }
}
