import XCTest
@testable import LifeIsLearned

final class RemoteFixtureProtocol: URLProtocol, @unchecked Sendable {
    static var response: (URLRequest) throws -> (Int, Data) = { _ in (500, Data()) }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    static var delayChunks = false
    private var work: Task<Void, Never>?
    override func startLoading() {
        work = Task { do {
            let (status, data) = try Self.response(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Length": String(data.count)])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if Self.delayChunks {
                let chunk = max(1, data.count / 12)
                for start in stride(from: 0, to: data.count, by: chunk) {
                    try Task.checkCancellation(); try await Task.sleep(for: .milliseconds(80))
                    client?.urlProtocol(self, didLoad: data.subdata(in: start..<min(data.count, start + chunk)))
                }
            } else { client?.urlProtocol(self, didLoad: data) }
            client?.urlProtocolDidFinishLoading(self)
        } catch { if !Task.isCancelled { client?.urlProtocol(self, didFailWithError: error) } } }
    }
    override func stopLoading() { work?.cancel() }
    static func configuration() -> URLSessionConfiguration { let c = URLSessionConfiguration.ephemeral; c.protocolClasses = [Self.self]; return c }
}

@MainActor final class DiscoveryTests: XCTestCase {
    private func catalog() throws -> DiscoveryCatalog {
        try DiscoveryCatalog.decode(Data(contentsOf: XCTUnwrap(Bundle.main.url(forResource: "Remote-Catalog-001", withExtension: "json"))), identity: CatalogIdentity.bundled())
    }
    private func remote(_ package: LessonPackage) throws -> DiscoveryBook {
        let data = try package.canonicalData()
        var book = try XCTUnwrap(catalog().books.first { $0.id == package.book.id })
        book.availability = .available
        book.package = RemotePackage(collectionRevision: package.collectionNumber, url: URL(string: "https://fixture.invalid/book.json")!, sha256: LibraryDigest.sha256(data), bytes: data.count)
        return book
    }
    func testSchemaIdentityAssetValidationAndSearch() throws {
        let original = try catalog(), identity = try CatalogIdentity.bundled()
        XCTAssertEqual(original.books.count, 50)
        XCTAssertTrue(original.filtered(query: "KAHNEMAN", shelfID: nil).contains { $0.id == "thinking-fast-and-slow" })
        XCTAssertTrue(original.filtered(query: "", shelfID: "psychology-human-behavior").allSatisfy { $0.primaryShelfID == "psychology-human-behavior" || $0.secondaryShelfIDs.contains("psychology-human-behavior") })
        var c = original; c.schemaVersion = 2; XCTAssertThrowsError(try c.validated(identity: identity))
        c = original; c.catalogRevision = 2; XCTAssertThrowsError(try c.validated(identity: identity))
        c = original; c.books[0].id = "renamed"; XCTAssertThrowsError(try c.validated(identity: identity))
        c = original; c.books[0].availability = .available; XCTAssertThrowsError(try c.validated(identity: identity))
        for url in ["http://example.com/book", "https://user:secret@example.com/book"] { XCTAssertThrowsError(try RemoteURL.validate(URL(string: url)!)) }
        XCTAssertTrue(ISBN.isValid("9780141033570")); XCTAssertFalse(ISBN.isValid("9780141033571"))
    }
    func testLastGoodCacheSurvivesMalformedAndOfflineRefresh() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let value = try catalog(), bytes = try JSONEncoder().encode(value)
        var requests: [URL] = []
        RemoteFixtureProtocol.response = { request in requests.append(request.url!); return (200, bytes) }
        let service = DiscoveryService(endpoint: URL(string: "https://fixture.invalid/catalog.json"), directory: directory,
            identity: try CatalogIdentity.bundled(), session: URLSession(configuration: RemoteFixtureProtocol.configuration()))
        let fresh = try await service.refresh(); XCTAssertEqual(fresh.catalog.books.count, 50)
        XCTAssertEqual(requests.map(\.lastPathComponent), ["catalog.json"], "Browsing never fetches a package")
        RemoteFixtureProtocol.response = { _ in (200, Data("broken".utf8)) }
        do { _ = try await service.refresh(); XCTFail("Malformed refresh accepted") } catch { }
        RemoteFixtureProtocol.response = { _ in throw URLError(.notConnectedToInternet) }
        do { _ = try await service.refresh(); XCTFail("Offline refresh accepted") } catch { }
        let cached = await service.cached(); XCTAssertEqual(cached?.catalog.books.count, 50)
        XCTAssertEqual(cached?.fetchedAt, fresh.fetchedAt)
    }
    func testDownloadIntegrityBeforeDecodeAndInstallSource() async throws {
        let f = try await CollectionFixture.make(empty: true); addTeardownBlock { await f.cleanup() }
        let package = f.package; var book = try remote(package)
        let file = try f.file(package)
        try package.canonicalData().write(to: file)
        let valid = try PackageDownloadService.validate(file: file, book: book)
        var review = try await f.store.storage.review(package: valid, catalog: f.store.catalog)
        review.source = BookSourceRecord(kind: .remoteCatalog, catalogID: "catalog-001", catalogURL: URL(string: "https://fixture.invalid/catalog.json"))
        await f.store.commitImport(review)
        XCTAssertNil(f.store.errorMessage); XCTAssertEqual(f.store.source(for: book.id).kind, .remoteCatalog)
        XCTAssertEqual(book.state(installed: f.store.installed.first, history: f.store.history.first), .inLibrary)
        book.package!.collectionRevision += 1
        XCTAssertEqual(book.state(installed: f.store.installed.first, history: f.store.history.first), .update)
        book = try remote(package); book.package!.bytes += 1
        XCTAssertThrowsError(try PackageDownloadService.validate(file: file, book: book))
        book = try remote(package); book.package!.sha256 = String(repeating: "0", count: 64)
        XCTAssertThrowsError(try PackageDownloadService.validate(file: file, book: book))
        XCTAssertEqual(f.store.books.count, 1)
        let offloaded = await f.store.offload(package.book); XCTAssertTrue(offloaded)
        XCTAssertEqual(book.state(installed: nil, history: f.store.history.first), .downloadAgain)
        book.availability = .planned; XCTAssertEqual(book.state(installed: nil, history: nil), .comingSoon)
        book.availability = .unavailable; XCTAssertEqual(book.state(installed: nil, history: nil), .request)
    }
    func testCancellationProgressAndFailedDownloadNeverInstall() async throws {
        let f = try await CollectionFixture.make(empty: true); addTeardownBlock { await f.cleanup() }
        let bytes = try f.package.canonicalData(), book = try remote(f.package)
        RemoteFixtureProtocol.response = { _ in (200, bytes) }; RemoteFixtureProtocol.delayChunks = true
        defer { RemoteFixtureProtocol.delayChunks = false }
        let service = PackageDownloadService(directory: f.directory, configuration: RemoteFixtureProtocol.configuration())
        let progressed = expectation(description: "received partial download progress"); progressed.assertForOverFulfill = false
        let task = Task { try await service.download(book) { value in if value > 0 && value < 1 { progressed.fulfill() } } }
        await fulfillment(of: [progressed], timeout: 5)
        await service.cancel()
        do { _ = try await task.value; XCTFail("Cancelled download succeeded") } catch { }
        XCTAssertTrue(f.store.books.isEmpty)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: f.directory.appendingPathComponent("Library-v3/Downloads/staging").path), [])
        // A URLProtocol cancellation need not provide resume data. Retry must still work.
        RemoteFixtureProtocol.delayChunks = false
        RemoteFixtureProtocol.response = { _ in (200, Data("not a package".utf8)) }
        do { _ = try await service.download(book) { _ in }; XCTFail("Wrong size accepted") } catch { }
        XCTAssertTrue(f.store.books.isEmpty)
        let manager = BookDownloadManager(directory: f.directory, configuration: RemoteFixtureProtocol.configuration())
        RemoteFixtureProtocol.response = { _ in (200, bytes) }
        var mismatch = book; mismatch.package!.sha256 = String(repeating: "0", count: 64)
        manager.start(mismatch, source: .manual, library: f.store)
        while manager.busy { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertTrue(f.store.books.isEmpty); XCTAssertTrue(manager.message?.contains("SHA-256") == true)
    }
    func testRemoteUpdatePreservesRemovalAcknowledgement() async throws {
        let f = try await CollectionFixture.make(empty: true); addTeardownBlock { await f.cleanup() }
        var original = f.multiIdea(count: 2); original.book.id = f.package.book.id
        try await f.commit(original)
        var update = original; update.collectionRevision = 2
        update.removedLessonIDs = [update.book.lessons.removeLast().id]
        update.manifest = update.book.lessons.map { IdeaManifestEntry(id: $0.id, revision: $0.revision) }
        let bytes = try update.canonicalData(), book = try remote(update)
        RemoteFixtureProtocol.response = { _ in (200, bytes) }
        let manager = BookDownloadManager(directory: f.directory, configuration: RemoteFixtureProtocol.configuration())
        manager.start(book, source: BookSourceRecord(kind: .remoteCatalog, catalogID: "catalog-001"), library: f.store)
        while manager.busy { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertEqual(f.store.books.first?.lessons.count, 2)
        let review = try XCTUnwrap(f.store.importReview)
        XCTAssertEqual(review.removed.count, 1); XCTAssertEqual(review.source?.kind, .remoteCatalog)
        await f.store.commitImport(review)
        XCTAssertEqual(f.store.books.first?.lessons.count, 2)
        await f.store.commitImport(review, acknowledgeRemovals: true)
        XCTAssertEqual(f.store.books.first?.lessons.count, 1); XCTAssertNil(f.store.errorMessage)
    }
    func testDownloadTransportProgressAndStagingCleanup() async throws {
        let f = try await CollectionFixture.make(); addTeardownBlock { await f.cleanup() }
        let bytes = try f.package.canonicalData(), book = try remote(f.package)
        RemoteFixtureProtocol.response = { _ in (200, bytes) }
        let service = PackageDownloadService(directory: f.directory, configuration: RemoteFixtureProtocol.configuration())
        let result = try await service.download(book) { _ in }
        XCTAssertEqual(result.book.id, book.id)
        let staging = f.directory.appendingPathComponent("Library-v3/Downloads/staging")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: staging.path), [])
    }
}
