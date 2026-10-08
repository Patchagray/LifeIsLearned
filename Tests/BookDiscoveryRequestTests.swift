import XCTest
@testable import LifeIsLearned

private actor RequestSpy: BookRequestSubmitting {
    var values: [BookRequest] = []
    func submit(_ request: BookRequest) async throws -> BookRequestReceipt {
        values.append(request)
        return BookRequestReceipt(status: "accepted", requestKey: "fixture", requestCount: 2)
    }
    func count() -> Int { values.count }
    func last() -> BookRequest? { values.last }
}
@MainActor final class BookDiscoveryRequestTests: XCTestCase {
    private func catalog() throws -> DiscoveryCatalog {
        try DiscoveryCatalog.decode(Data(contentsOf: XCTUnwrap(Bundle.main.url(forResource: "Remote-Catalog-001", withExtension: "json"))), identity: CatalogIdentity.bundled())
    }
    func testISBNOutranksTextAndNormalizedAuthorMatching() throws {
        var catalog = try catalog()
        catalog.books[0].isbn13 = ["9780141033570"] // Synthetic association, never production metadata.
        let another = catalog.books[1]
        let matches = BookMatcher.matches(RecognizedBook(title: another.title, author: another.author, isbn13: "978-0-141-03357-0"), catalog: catalog)
        XCTAssertEqual(matches.first?.id, catalog.books[0].id); XCTAssertTrue(matches.first?.exactISBN == true)
        let text = BookMatcher.matches(RecognizedBook(title: another.title.uppercased().replacingOccurrences(of: ",", with: "—"), author: another.author.lowercased()), catalog: catalog)
        XCTAssertEqual(text.first?.id, another.id)
        XCTAssertTrue(BookMatcher.matches(RecognizedBook(title: "zxq-unrecognized-title"), catalog: catalog).isEmpty)
    }
    func testCameraPermissionAndUnsupportedFallbackPolicy() {
        XCTAssertEqual(BookCameraAvailability.evaluate(supported: true, permissionGranted: false, available: false), .denied)
        XCTAssertTrue(BookCameraAvailability.denied.message!.contains("typing"))
        XCTAssertTrue(BookCameraAvailability.denied.message!.contains("Settings"))
        XCTAssertEqual(BookCameraAvailability.evaluate(supported: false, permissionGranted: false, available: false), .unsupported)
        XCTAssertEqual(BookCameraAvailability.evaluate(supported: true, permissionGranted: true, available: false), .temporarilyUnavailable)
        XCTAssertEqual(BookCameraAvailability.evaluate(supported: true, permissionGranted: true, available: true), .ready)
    }
    func testAmbiguityDoesNotChooseAutomatically() throws {
        var catalog = try catalog(); catalog.books = Array(catalog.books.prefix(2))
        catalog.books[0].title = "A thoughtful life"; catalog.books[1].title = "A thoughtful life"
        let matches = BookMatcher.matches(RecognizedBook(title: "A thoughtful life"), catalog: catalog)
        XCTAssertEqual(matches.count, 2); XCTAssertTrue(BookMatcher.isAmbiguous(matches))
    }
    func testUnknownMetadataEditableAndOnlyExplicitActionSubmits() async throws {
        let spy = RequestSpy(), model = BookRequestModel(book: RecognizedBook(title: "Recognized draft"), client: RequestSpy())
        XCTAssertNil(model.receipt)
        let edited = BookRequestModel(book: RecognizedBook(title: "Recognized draft"), client: spy)
        edited.title = "Reviewed title"; edited.author = "Reviewed author"
        let before = await spy.count(); XCTAssertEqual(before, 0)
        await edited.request()
        let sent = await spy.last(); XCTAssertEqual(sent?.title, "Reviewed title"); XCTAssertNil(sent?.catalogBookID)
        XCTAssertEqual(edited.receipt?.requestCount, 2)
        await edited.request(); let after = await spy.count(); XCTAssertEqual(after, 1, "Accepted request cannot be accidentally replayed by this form")
    }
    func testRequestSuccessDuplicateRateLimitMalformedAndNetworkErrors() async throws {
        let client = HTTPBookRequestClient(endpoint: URL(string: "https://fixture.invalid/v1/book-requests"), session: URLSession(configuration: RemoteFixtureProtocol.configuration()))
        let request = BookRequest(title: "Reviewed title", source: "scanner")
        RemoteFixtureProtocol.response = { _ in (200, try JSONEncoder().encode(BookRequestReceipt(status: "accepted", requestKey: "same-key", requestCount: 2))) }
        let response = try await client.submit(request); XCTAssertEqual(response.requestCount, 2)
        RemoteFixtureProtocol.response = { _ in (429, Data()) }
        do { _ = try await client.submit(request); XCTFail("429 accepted") } catch { XCTAssertTrue(error.localizedDescription.contains("wait a minute")) }
        RemoteFixtureProtocol.response = { _ in (200, Data("malformed".utf8)) }
        do { _ = try await client.submit(request); XCTFail("Malformed response accepted") } catch { }
        RemoteFixtureProtocol.response = { _ in throw URLError(.notConnectedToInternet) }
        let model = BookRequestModel(book: RecognizedBook(title: "A book"), client: client)
        await model.request(); XCTAssertNil(model.receipt); XCTAssertNotNil(model.error); XCTAssertFalse(model.sending)
        do { _ = try await HTTPBookRequestClient(endpoint: nil).submit(request); XCTFail("Unconfigured request accepted") } catch { XCTAssertTrue(error.localizedDescription.contains("not been sent")) }
        XCTAssertThrowsError(try BookRequest(title: "", source: "scanner").validated())
        XCTAssertThrowsError(try BookRequest(title: "A", isbn13: "9780141033571", source: "scanner").validated())
    }
}
