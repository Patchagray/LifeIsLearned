import XCTest
@testable import LifeIsLearned

final class RemoteFixtureProtocol: URLProtocol, @unchecked Sendable {
    static var response: (URLRequest) throws -> (Int, Data) = { _ in (500, Data()) }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    static var headers: [String: String] = [:]
    static var delayChunks = false
    private var work: Task<Void, Never>?
    override func startLoading() {
        work = Task { do {
            let (status, data) = try Self.response(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: Self.headers.merging(["Content-Length": String(data.count)]) { _, new in new })!
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
    func testAvailabilityFilterCombinesWithSearchAndShelf() throws {
        var value = try catalog()
        let id = "thinking-fast-and-slow"
        let index = try XCTUnwrap(value.books.firstIndex { $0.id == id })
        value.books[index].availability = .available
        XCTAssertEqual(value.filtered(query: "", shelfID: nil, showComingSoon: false).map(\.id), [id])
        XCTAssertEqual(value.filtered(query: "KAHNEMAN", shelfID: "psychology-human-behavior", showComingSoon: false).map(\.id), [id])
        XCTAssertTrue(value.filtered(query: "", shelfID: "money-personal-finance", showComingSoon: false).isEmpty)
        XCTAssertEqual(value.filtered(query: "", shelfID: nil, showComingSoon: true).count, 50)
        XCTAssertFalse(value.filtered(query: "", shelfID: "psychology-human-behavior", showComingSoon: true).isEmpty)
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
        RemoteFixtureProtocol.headers = ["X-Library-State": "planned-only"]
        do { _ = try await service.refresh(); XCTFail("Unavailable origin replaced the good cache") } catch { }
        RemoteFixtureProtocol.headers = [:]
        RemoteFixtureProtocol.response = { _ in (200, Data("broken".utf8)) }
        do { _ = try await service.refresh(); XCTFail("Malformed refresh accepted") } catch { }
        RemoteFixtureProtocol.response = { _ in throw URLError(.notConnectedToInternet) }
        do { _ = try await service.refresh(); XCTFail("Offline refresh accepted") } catch { }
        let cached = await service.cached(); XCTAssertEqual(cached?.catalog.books.count, 50)
        XCTAssertEqual(cached?.fetchedAt, fresh.fetchedAt)
    }
    func testThumbnailIntegrityAndNativeImageBudgets() async throws {
        let f = try await CollectionFixture.make(); addTeardownBlock { await f.cleanup() }
        let image = try XCTUnwrap(f.package.assets?.values.first { $0.data.count < 512 * 1024 }).data
        let service = DiscoveryService(endpoint: nil, directory: f.directory, identity: try CatalogIdentity.bundled(), session: URLSession(configuration: RemoteFixtureProtocol.configuration()))
        var asset = RemoteAsset(url: URL(string: "https://fixture.invalid/cover.png")!, sha256: LibraryDigest.sha256(image), bytes: image.count)
        RemoteFixtureProtocol.response = { _ in (200, image) }
        let valid = try await service.thumbnail(asset); XCTAssertEqual(valid, image)
        asset.sha256 = String(repeating: "0", count: 64)
        do { _ = try await service.thumbnail(asset); XCTFail("Bad checksum accepted") } catch { }
        let invalid = Data("not an image".utf8)
        asset.sha256 = LibraryDigest.sha256(invalid); asset.bytes = invalid.count
        RemoteFixtureProtocol.response = { _ in (200, invalid) }
        do { _ = try await service.thumbnail(asset); XCTFail("Invalid image accepted") } catch { }
    }
    func testApprovedThumbnailCacheWorksOfflineAndRejectsTampering() async throws {
        let f = try await CollectionFixture.make(); addTeardownBlock { await f.cleanup() }
        let image = try XCTUnwrap(f.package.assets?.values.first { $0.data.count < 512 * 1024 }).data
        let asset = RemoteAsset(url: URL(string: "https://fixture.invalid/cover.png")!, sha256: LibraryDigest.sha256(image), bytes: image.count)
        let service = DiscoveryService(endpoint: nil, directory: f.directory, identity: try CatalogIdentity.bundled(), session: URLSession(configuration: RemoteFixtureProtocol.configuration()))
        var requests = 0
        RemoteFixtureProtocol.response = { _ in requests += 1; return (200, image) }
        let first = try await service.thumbnail(asset); XCTAssertEqual(first, image)
        RemoteFixtureProtocol.response = { _ in requests += 1; throw URLError(.notConnectedToInternet) }
        let second = try await service.thumbnail(asset); XCTAssertEqual(second, image); XCTAssertEqual(requests, 1)
        let file = f.directory.appendingPathComponent("Discovery/Thumbnails/" + asset.sha256)
        try Data(repeating: 0, count: image.count).write(to: file)
        do { _ = try await service.thumbnail(asset); XCTFail("Corrupt cached cover accepted") } catch { }
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
    func testManagerCancellationCannotReachInstall() async throws {
        let f = try await CollectionFixture.make(empty: true); addTeardownBlock { await f.cleanup() }
        let bytes = try f.package.canonicalData(), book = try remote(f.package)
        RemoteFixtureProtocol.response = { _ in (200, bytes) }; RemoteFixtureProtocol.delayChunks = true
        defer { RemoteFixtureProtocol.delayChunks = false }
        let manager = BookDownloadManager(directory: f.directory, configuration: RemoteFixtureProtocol.configuration())
        manager.start(book, source: .manual, library: f.store)
        for _ in 0..<100 { if manager.progress > 0 { break }; try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertGreaterThan(manager.progress, 0)
        manager.cancel()
        while manager.busy { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertTrue(f.store.books.isEmpty); XCTAssertNil(f.store.importReview)
        XCTAssertTrue(manager.message?.contains("cancelled") == true)
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

@MainActor final class ExploreContractTests: XCTestCase {
    private func catalog() throws -> DiscoveryCatalog {
        try DiscoveryCatalog.decode(Data(contentsOf: XCTUnwrap(Bundle.main.url(forResource: "Remote-Catalog-001", withExtension: "json"))), identity: CatalogIdentity.bundled())
    }
    func testNetworkErrorsUseActionableCopy() {
        XCTAssertEqual(RemoteResponse.message(URLError(.notConnectedToInternet)), "You’re offline. Reconnect and try again when ready.")
        XCTAssertTrue(RemoteResponse.message(URLError(.timedOut)).contains("retry"))
        XCTAssertFalse(RemoteResponse.message(URLError(.cannotFindHost)).contains("NSURLError"))
        XCTAssertTrue(RemoteResponse.message(RemoteResponse.error(404)).contains("Refresh Explore"))
    }
    func testWorkerOriginTrustBoundary() throws {
        let endpoint = URL(string: "https://catalog.example/v1/catalog")!
        for path in ["/v1/catalog", "/v1/covers/atomic-habits", "/v1/books/atomic-habits/download"] {
            try DistributionURL.validate(URL(string: "https://catalog.example" + path)!, catalogURL: endpoint)
        }
        for text in ["https://github.com/Patchagray/LifeIsLearned-Published/private.json", "https://raw.githubusercontent.com/Other/Repo/main/catalog.json", "https://release-assets.githubusercontent.com/asset?signature=x", "https://evil.test/v1/catalog", "http://catalog.example/v1/catalog", "https://user:password@catalog.example/v1/catalog", "https://catalog.example/arbitrary", "https://catalog.example/v1/catalog?path=private", "https://catalog.example/v1/covers/%2e%2e"] {
            XCTAssertThrowsError(try DistributionURL.validate(URL(string: text)!, redirect: true, catalogURL: endpoint))
        }
        XCTAssertThrowsError(try DistributionURL.validateEndpoint(URL(string: "https://github.com/v1/catalog")!))
    }
    func testCanonicalOrderAvailabilityAndImmutableRevision() throws {
        var original = try catalog()
        let identity = try CatalogIdentity.bundled()
        original.shelves = identity.shelves.reversed()
        XCTAssertThrowsError(try original.validated(identity: identity))
        original.shelves = identity.shelves
        original.updatedAt = "not-a-date"
        XCTAssertThrowsError(try original.validated(identity: identity))
        original.updatedAt = "2026-10-09T00:00:00Z"
        let ids = original.books.map(\.id)
        original.books.reverse()
        XCTAssertEqual(try original.validated(identity: CatalogIdentity.bundled()).books.map(\.id), ids)
        let metadata = RemotePackage(collectionRevision: 2, url: URL(string: "https://fixture.invalid/book.json")!, sha256: String(repeating: "a", count: 64), bytes: 100)
        original.books[0].package = metadata
        XCTAssertThrowsError(try original.validated(identity: CatalogIdentity.bundled()), "Planned title cannot advertise a package")
        original.books[0].availability = .available
        _ = try original.validated(identity: CatalogIdentity.bundled())
        var revised = original; revised.books[0].package!.collectionRevision = 1
        XCTAssertThrowsError(try revised.validateUpdate(from: original))
        revised = original; revised.books[0].package!.sha256 = String(repeating: "b", count: 64)
        XCTAssertThrowsError(try revised.validateUpdate(from: original))
        revised.books[0].package!.collectionRevision = 3
        XCTAssertNoThrow(try revised.validateUpdate(from: original))
    }
    func testETag304AndRejectedRollbackRetainLastGoodCache() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory); RemoteFixtureProtocol.headers = [:] }
        var original = try catalog(); original.updatedAt = "2026-10-09T00:00:00Z"
        let bytes = try JSONEncoder().encode(original)
        RemoteFixtureProtocol.headers = ["ETag": "\"catalog-006\""]
        RemoteFixtureProtocol.response = { _ in (200, bytes) }
        let service = DiscoveryService(endpoint: URL(string: "https://fixture.invalid/catalog.json"), directory: directory, identity: try CatalogIdentity.bundled(), session: URLSession(configuration: RemoteFixtureProtocol.configuration()))
        let first = try await service.refresh(); XCTAssertEqual(first.etag, "\"catalog-006\"")
        RemoteFixtureProtocol.response = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "If-None-Match"), "\"catalog-006\"")
            return (304, Data())
        }
        let unchanged = try await service.refresh(); XCTAssertEqual(unchanged.catalog.books.count, 50)
        original.updatedAt = "2026-10-08T00:00:00Z"
        let stale = try JSONEncoder().encode(original)
        RemoteFixtureProtocol.response = { _ in (200, stale) }
        do { _ = try await service.refresh(); XCTFail("Rollback accepted") } catch { }
        let cached = await service.cached(); XCTAssertEqual(cached?.catalog.updatedAt, "2026-10-09T00:00:00Z")
        XCTAssertEqual(cached?.etag, first.etag)
    }
    func testRemoteReinstallRetainsLearnerStateAndCardIdentity() async throws {
        let f = try await CollectionFixture.make(empty: true); addTeardownBlock { await f.cleanup() }
        var review = try await f.store.storage.review(package: f.package, catalog: f.store.catalog)
        review.source = BookSourceRecord(kind: .remoteCatalog, catalogID: "catalog-001", catalogURL: DistributionURL.catalog)
        await f.store.commitImport(review)
        let book = f.package.book, lesson = book.lessons[0]
        var progress = f.store.status(book: book, lesson: lesson); progress.practiceComplete = true; progress.firstTryCorrect = 1
        f.store.update(book: book, lesson: lesson) { $0 = progress }
        await f.store.flush()
        let before = f.store.status(book: book, lesson: lesson)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let cards = try encoder.encode(f.store.cards)
        XCTAssertEqual(f.store.cards.count, 1)
        let offloaded = await f.store.offload(book); XCTAssertTrue(offloaded)
        XCTAssertEqual(f.store.source(for: book.id).kind, .remoteCatalog)
        var reinstall = try await f.store.storage.review(package: f.package, catalog: f.store.catalog)
        reinstall.source = review.source
        await f.store.commitImport(reinstall)
        XCTAssertNil(f.store.errorMessage)
        XCTAssertEqual(f.store.status(book: book, lesson: lesson).practiceComplete, before.practiceComplete)
        XCTAssertEqual(f.store.status(book: book, lesson: lesson).firstTryCorrect, before.firstTryCorrect)
        XCTAssertEqual(try encoder.encode(f.store.cards), cards)
        XCTAssertEqual(f.store.history.filter { $0.bookID == book.id }.count, 1)
    }
}
