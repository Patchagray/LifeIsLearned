import Foundation

struct CatalogIdentity: Codable, Sendable {
    struct Shelf: Codable, Identifiable, Sendable { var id: String; var name: String; var order: Int }
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
        try RemoteURL.validate(url)
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
    var author: String { authors.joined(separator: ", ") }
    func state(installed: InstalledBookRecord?, history: BookHistoryRecord?) -> DiscoveryBookState {
        if let installed {
            if availability == .available, let package, package.collectionRevision > installed.collectionRevision { return .update }
            return .inLibrary
        }
        if availability == .available { return history == nil ? .download : .downloadAgain }
        return availability == .planned ? .comingSoon : .request
    }
}
enum DiscoveryBookState: String, Sendable {
    case download = "Download", downloadAgain = "Download Again", update = "Update", inLibrary = "In Library"
    case comingSoon = "Coming Soon", request = "Request"
    var canDownload: Bool { self == .download || self == .downloadAgain || self == .update }
}
struct DiscoveryCatalog: Codable, Sendable {
    var schemaVersion: Int
    var catalogID: String
    var catalogRevision: Int
    var books: [DiscoveryBook]
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
        for book in books {
            guard let approved = identity.books.first(where: { $0.id == book.id }) else { throw PackageError.invalid("An unapproved book identity was supplied.") }
            try CollectionLimits.require(!book.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !book.authors.isEmpty && book.authors.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }, "Book title and authors are required.")
            try CollectionLimits.require(book.primaryShelfID == approved.primaryShelfID && book.secondaryShelfIDs == approved.secondaryShelfIDs,
                                         "Discovery shelf assignments must match Catalog 001.")
            try CollectionLimits.require(book.isbn13.allSatisfy(ISBN.isValid), "Invalid ISBN-13 in discovery metadata.")
            if let thumbnail = book.thumbnail { try thumbnail.validate(limit: 512 * 1_024) }
            if book.availability == .available { try CollectionLimits.require(book.package != nil, "An available book needs package metadata.") }
            if let package = book.package {
                try CollectionLimits.require(package.collectionRevision > 0, "Package collection revision must be positive.")
                try package.asset.validate(limit: CollectionLimits.packageBytes)
            }
        }
        return self
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
