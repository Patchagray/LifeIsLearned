import Foundation

struct CatalogIdentity: Codable, Sendable {
    struct Shelf: Codable, Identifiable, Equatable, Sendable { var id: String; var name: String; var order: Int }
    struct Book: Codable, Sendable { var id: String; var primaryShelfID: String; var secondaryShelfIDs: [String] }
    var catalogID: String
    var catalogRevision: Int
    var shelves: [Shelf]
    var books: [Book]
    static func bundled() throws -> Self {
        guard let url = Bundle.main.url(forResource: "Catalog-001", withExtension: "json") else { throw PackageError.invalid("The catalog identity reference is missing.") }
        return try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
    }
}

struct RemoteAsset: Codable, Hashable, Sendable {
    var url: URL
    var sha256: String
    var bytes: Int
    func validate(limit: Int) throws {
        try DistributionURL.validate(url)
        try CollectionLimits.require((1...limit).contains(bytes) && sha256.range(of: #"^[a-f0-9]{64}$"#, options: .regularExpression) != nil,
                                     "Remote assets require a bounded byte size and SHA-256.")
    }
}
struct RemotePackage: Codable, Equatable, Sendable {
    var collectionRevision: Int
    var url: URL
    var sha256: String
    var bytes: Int
    var asset: RemoteAsset { RemoteAsset(url: url, sha256: sha256, bytes: bytes) }
}
struct DiscoveryBook: Codable, Identifiable, Sendable {
    enum Availability: String, Codable, Sendable { case available, planned, unavailable }
    var id: String
    var title: String
    var authors: [String]
    var primaryShelfID: String
    var secondaryShelfIDs: [String]
    var tags: [String]
    var isbn13: [String]
    var availability: Availability
    var thumbnail: RemoteAsset? = nil
    var package: RemotePackage? = nil
    var description: String? = nil
    var updatedAt: String? = nil
    var author: String { authors.joined(separator: ", ") }
    func state(installed: InstalledBookRecord?, history: BookHistoryRecord?) -> DiscoveryBookState {
        if let installed {
            if availability == .available, let package, package.collectionRevision > installed.collectionRevision { return .update }
            return .inLibrary
        }
        if availability == .available { return history == nil ? .download : .downloadAgain }
        if history != nil { return .offloadedUnavailable }
        return availability == .planned ? .comingSoon : .request
    }
}
enum DiscoveryBookState: String, Sendable {
    case download = "Download", downloadAgain = "Download Again", update = "Update", inLibrary = "In Library"
    case comingSoon = "Coming Soon", request = "Request", offloadedUnavailable = "Offloaded"
    var status: String {
        switch self {
        case .download: return "Available for download"
        case .downloadAgain: return "Offloaded · Restore"
        case .update: return "Update available"
        case .inLibrary: return "Installed"
        case .comingSoon: return "Coming soon"
        case .request: return "Unavailable · Request"
        case .offloadedUnavailable: return "Offloaded · release unavailable"
        }
    }
    var canDownload: Bool { self == .download || self == .downloadAgain || self == .update }
}
struct DiscoveryCatalog: Codable, Sendable {
    var schemaVersion: Int
    var catalogID: String
    var catalogRevision: Int
    var books: [DiscoveryBook]
    var updatedAt: String? = nil
    var shelves: [CatalogIdentity.Shelf]? = nil
    static let maximumBytes = 2 * 1_024 * 1_024
    static func decode(_ bytes: Data, identity: CatalogIdentity) throws -> Self {
        try CollectionLimits.require(bytes.count <= maximumBytes, "The discovery catalog is too large.")
        return try JSONDecoder().decode(Self.self, from: bytes).validated(identity: identity)
    }
    func validated(identity: CatalogIdentity) throws -> Self {
        try CollectionLimits.require(schemaVersion == 1 && catalogID == "catalog-001" && catalogRevision == 1 &&
            catalogID == identity.catalogID && catalogRevision == identity.catalogRevision, "Unsupported discovery schema or identity catalog revision.")
        try CollectionLimits.require(books.count <= identity.books.count && Set(books.map(\.id)).count == books.count,
                                    "Discovery book identities must be unique and approved.")
        if let shelves { try CollectionLimits.require(shelves == identity.shelves, "Discovery shelves must match the canonical shelf order.") }
        try Self.validateTimestamp(updatedAt)
        for book in books {
            try Self.validateTimestamp(book.updatedAt)
            guard let approved = identity.books.first(where: { $0.id == book.id }) else { throw PackageError.invalid("An unapproved book identity was supplied.") }
            try CollectionLimits.require(!book.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !book.authors.isEmpty && book.authors.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }, "Book title and authors are required.")
            try CollectionLimits.require(book.primaryShelfID == approved.primaryShelfID && book.secondaryShelfIDs == approved.secondaryShelfIDs,
                                         "Discovery shelf assignments must match Catalog 001.")
            try CollectionLimits.require(book.isbn13.allSatisfy(ISBN.isValid), "Invalid ISBN-13 in discovery metadata.")
            if let thumbnail = book.thumbnail { try thumbnail.validate(limit: 512 * 1_024) }
            if book.availability == .available { try CollectionLimits.require(book.package != nil, "An available book needs package metadata.") }
            try CollectionLimits.require(book.availability == .available || book.package == nil, "Only available books may include a package URL.")
            if let package = book.package {
                try CollectionLimits.require(package.collectionRevision > 0, "Package collection revision must be positive.")
                try package.asset.validate(limit: CollectionLimits.packageBytes)
            }
        }
        let order = Dictionary(uniqueKeysWithValues: identity.books.enumerated().map { ($0.element.id, $0.offset) })
        var ordered = self
        ordered.books.sort { order[$0.id, default: 0] < order[$1.id, default: 0] }
        return ordered
    }
    private static func validateTimestamp(_ value: String?) throws {
        guard let value else { return } // Legacy preview/cache compatibility.
        try CollectionLimits.require(value.range(of: #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$"#, options: .regularExpression) != nil && ISO8601DateFormatter().date(from: value) != nil, "Catalog updatedAt must be a UTC ISO-8601 timestamp.")
    }
    func validateUpdate(from previous: Self) throws {
        for book in books {
            guard let new = book.package, let old = previous.books.first(where: { $0.id == book.id })?.package else { continue }
            try CollectionLimits.require(new.collectionRevision >= old.collectionRevision, "Catalog refresh contains an older book revision.")
            if new.collectionRevision == old.collectionRevision {
                try CollectionLimits.require(new.sha256 == old.sha256 && new.bytes == old.bytes, "A published book revision cannot change its bytes. Publish a new collection revision.")
            }
        }
        if let old = previous.updatedAt, let new = updatedAt {
            try CollectionLimits.require(new >= old, "Catalog refresh is older than the saved catalog.")
        }
    }
    func filtered(query: String, shelfID: String?) -> [DiscoveryBook] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return books.filter { book in
            (q.isEmpty || (book.title + " " + book.author).localizedStandardContains(q)) &&
            (shelfID == nil || book.primaryShelfID == shelfID || book.secondaryShelfIDs.contains(shelfID!))
        }
    }
}
enum RemoteURL {
    static func validate(_ url: URL) throws {
        try CollectionLimits.require(url.scheme?.lowercased() == "https" && url.host?.isEmpty == false && url.user == nil && url.password == nil,
                                     "Remote library URLs must use HTTPS without embedded credentials.")
    }
}
enum ISBN {
    static func normalized(_ value: String) -> String { value.filter { $0 >= "0" && $0 <= "9" } }
    static func isValid(_ value: String) -> Bool {
        let digits = value.compactMap { $0.wholeNumberValue }
        guard value.count == 13, normalized(value) == value, digits.count == 13, value.hasPrefix("978") || value.hasPrefix("979") else { return false }
        return digits.enumerated().reduce(0) { $0 + $1.element * ($1.offset.isMultiple(of: 2) ? 1 : 3) } % 10 == 0
    }
}

/// The reviewer provisions one Worker endpoint. Catalog and asset routes share its
/// exact HTTPS origin; private GitHub URLs and redirects never reach the client.
enum DistributionURL {
    static var catalog: URL? {
        guard let text = Bundle.main.object(forInfoDictionaryKey: "DiscoveryCatalogURL") as? String,
              let url = URL(string: text), (try? validateEndpoint(url)) != nil else { return nil }
        return url
    }
    static func validateEndpoint(_ url: URL) throws {
        try RemoteURL.validate(url)
        let host = url.host?.lowercased() ?? ""
        try CollectionLimits.require(url.path == "/v1/catalog" && url.query == nil && url.fragment == nil &&
            (url.port == nil || url.port == 443) && !["github.com", "api.github.com", "raw.githubusercontent.com", "release-assets.githubusercontent.com", "objects.githubusercontent.com"].contains(host),
            "Configure the library's HTTPS catalog service endpoint.")
    }
    static func validate(_ url: URL, redirect: Bool = false, catalogURL: URL? = catalog) throws {
        try RemoteURL.validate(url)
        #if DEBUG
        if ["fixture.invalid", "h005-fixture.invalid"].contains(url.host?.lowercased() ?? "") { return }
        #endif
        guard let endpoint = catalogURL else { throw PackageError.invalid("The remote library is not configured yet.") }
        try validateEndpoint(endpoint)
        let route = url.path == "/v1/catalog" || url.path.range(of: #"^/v1/(covers/[a-z0-9-]+|books/[a-z0-9-]+/download)$"#, options: .regularExpression) != nil
        try CollectionLimits.require(url.host?.lowercased() == endpoint.host?.lowercased() &&
            (url.port == nil || url.port == 443) && url.query == nil && url.fragment == nil && route &&
            !url.absoluteString.contains("%"), "The library URL is outside the configured catalog service.")
    }
}
