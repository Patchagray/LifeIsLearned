import Foundation

struct RecognizedBook: Equatable, Sendable {
    var title = ""
    var author = ""
    var isbn13 = ""
}
struct BookMatch: Identifiable, Sendable {
    var book: DiscoveryBook
    var score: Double
    var exactISBN: Bool
    var id: String { book.id }
}
enum BookMatcher {
    static func normalized(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: " ")
    }
    static func matches(_ recognized: RecognizedBook, catalog: DiscoveryCatalog) -> [BookMatch] {
        let isbn = ISBN.normalized(recognized.isbn13)
        let title = normalized(recognized.title), author = normalized(recognized.author)
        let words = Set(title.split(separator: " ").map(String.init))
        return catalog.books.compactMap { book in
            let exact = ISBN.isValid(isbn) && book.isbn13.contains(isbn)
            if exact { return BookMatch(book: book, score: 1, exactISBN: true) }
            guard !words.isEmpty else { return nil }
            let candidate = normalized(book.title), tokens = Set(candidate.split(separator: " ").map(String.init))
            let overlap = Double(words.intersection(tokens).count) / Double(max(1, tokens.union(words).count))
            let titleScore = title == candidate ? 0.85 : overlap * 0.75
            let authorScore = !author.isEmpty && normalized(book.author).contains(author) ? 0.1 : 0
            let score = titleScore + authorScore
            return score >= 0.32 ? BookMatch(book: book, score: score, exactISBN: false) : nil
        }.sorted { $0.score == $1.score ? $0.id < $1.id : $0.score > $1.score }
    }
    static func isAmbiguous(_ matches: [BookMatch]) -> Bool { matches.count > 1 && matches[0].score - matches[1].score < 0.12 }
}

struct BookRequest: Codable, Equatable, Sendable {
    var catalogBookID: String?
    var title: String
    var author: String?
    var isbn13: String?
    var source: String
    func validated() throws -> Self {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let author = author?.trimmingCharacters(in: .whitespacesAndNewlines)
        let isbn = isbn13.map(ISBN.normalized)
        try CollectionLimits.require(!title.isEmpty && title.count <= 300 && (author?.count ?? 0) <= 200,
                                     "Enter a title (up to 300 characters) and an optional author (up to 200).")
        try CollectionLimits.require(isbn == nil || isbn == "" || ISBN.isValid(isbn!), "Check the 13-digit ISBN, or leave it empty.")
        try CollectionLimits.require(["scanner", "library"].contains(source), "Invalid request source.")
        return Self(catalogBookID: catalogBookID, title: title, author: author?.isEmpty == false ? author : nil,
                    isbn13: isbn?.isEmpty == false ? isbn : nil, source: source)
    }
}
struct BookRequestReceipt: Codable, Equatable, Sendable {
    var status: String
    var requestKey: String
    var requestCount: Int
}

enum BookCameraAvailability: Equatable {
    case ready, unsupported, denied, temporarilyUnavailable
    static func evaluate(supported: Bool, permissionGranted: Bool, available: Bool) -> Self {
        if !supported { return .unsupported }
        if !permissionGranted { return .denied }
        return available ? .ready : .temporarilyUnavailable
    }
    var message: String? {
        switch self {
        case .ready: return nil
        case .unsupported: return "Camera recognition is unavailable here. Enter a title or ISBN below to search."
        case .denied: return "Camera access is off. Search by typing, or enable Camera in Settings."
        case .temporarilyUnavailable: return "Camera recognition is temporarily unavailable. You can still type the book details."
        }
    }
}
