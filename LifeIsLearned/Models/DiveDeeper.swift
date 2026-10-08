import Foundation

struct DiveDeeperSection: Codable, Identifiable, Sendable {
    var id: String
    var title: String
    var text: String
    var sourceIDs: [String]
}
struct DiveDeeperContent: Codable, Sendable {
    var title: String
    var summary: String? = nil
    var sections: [DiveDeeperSection]
    func validate(sourceIDs: Set<String>) throws {
        func nonempty(_ text: String) -> Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        try CollectionLimits.require(nonempty(title) && !sections.isEmpty && Set(sections.map(\.id)).count == sections.count,
                                     "Dive Deeper needs a title and uniquely identified sections.")
        for section in sections {
            try CollectionLimits.require(nonempty(section.id) && nonempty(section.title) && nonempty(section.text), "Dive Deeper sections need IDs, titles and text.")
            try CollectionLimits.require(!section.sourceIDs.isEmpty && Set(section.sourceIDs).isSubset(of: sourceIDs),
                                         "Every Dive Deeper section needs valid reviewed source references.")
        }
    }
}
enum DiveDeeperAccess: Equatable { case unavailable, locked, available, restoreManual, restoreRemote }
struct DiveDeeperDestination: Identifiable {
    let id = UUID()
    var content: DiveDeeperContent
    var sources: [ContentSource]
    var lessonTitle: String
}
