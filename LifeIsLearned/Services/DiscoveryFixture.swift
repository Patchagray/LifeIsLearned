#if DEBUG
import Foundation

/// Isolated UI-test transport. No real URL is contacted and release builds omit it.
final class DiscoveryFixtureProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    private static var refreshes = 0
    private var work: Task<Void, Never>?
    static var enabled: Bool {
        let env = ProcessInfo.processInfo.environment
        return env["LIL_DISCOVERY_FIXTURE"] == "1" && UUID(uuidString: env["LIL_UI_TEST_RUN_ID"] ?? "") != nil
    }
    static func configuration() -> URLSessionConfiguration { let c = URLSessionConfiguration.ephemeral; c.protocolClasses = [Self.self]; return c }
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "h005-fixture.invalid" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    private static func nextRefresh() -> Int { lock.lock(); defer { lock.unlock() }; refreshes += 1; return refreshes }
    override func startLoading() {
        work = Task {
            do {
                let raw = try Data(contentsOf: Bundle.main.url(forResource: "starter", withExtension: "json")!)
                var package = try LessonPackage.decodeImport(raw)
                package.book.id = "influence-the-psychology-of-persuasion"
                package.book.title = "Discovery verification fixture"
                package.book.author = "Synthetic interface fixture"
                let bytes = try package.canonicalData()
                let data: Data
                if request.url?.lastPathComponent == "catalog.json" {
                    let count = Self.nextRefresh()
                    if count > 2 { throw URLError(.notConnectedToInternet) }
                    let identity = try CatalogIdentity.bundled()
                    let original = try DiscoveryCatalog.decode(Data(contentsOf: Bundle.main.url(forResource: "Remote-Catalog-001", withExtension: "json")!), identity: identity)
                    var book = original.books.first { $0.id == package.book.id }!
                    book.title = "Discovery verification fixture"; book.authors = ["Synthetic interface fixture"]
                    book.availability = .available
                    book.package = RemotePackage(collectionRevision: count, url: URL(string: "https://h005-fixture.invalid/book.json")!, sha256: LibraryDigest.sha256(bytes), bytes: bytes.count)
                    data = try JSONEncoder().encode(DiscoveryCatalog(schemaVersion: 1, catalogID: "catalog-001", catalogRevision: 1, books: [book] + original.books.filter { $0.id != book.id }))
                } else { data = bytes }
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Length": String(data.count)])!
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                let step = max(1, data.count / 20)
                for start in stride(from: 0, to: data.count, by: step) {
                    try Task.checkCancellation()
                    if request.url?.lastPathComponent == "book.json" { try await Task.sleep(for: .milliseconds(180)) }
                    client?.urlProtocol(self, didLoad: data.subdata(in: start..<min(start + step, data.count)))
                }
                client?.urlProtocolDidFinishLoading(self)
            } catch { if !Task.isCancelled { client?.urlProtocol(self, didFailWithError: error) } }
        }
    }
    override func stopLoading() { work?.cancel() }
}
#endif
