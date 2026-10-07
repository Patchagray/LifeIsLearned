import Foundation

/// Presentation recognition only. This never changes runtime package acceptance.
enum SixStageLesson {
    static let kinds: [PageKind] = [.intro, .explanation, .story, .story, .application, .takeaway]
    static let roles: [NarrationRole] = [.guide, .guide, .storyteller, .storyteller, .guide, .guide]
    static let readerLabels = ["Hook", "Explanation", "Story · 1 of 2", "Story · 2 of 2", "Practical application", "An idea to keep"]
    static let accessibilityLabels = ["Hook", "Explanation", "Story 1 of 2", "Story 2 of 2", "Practical Application", "Takeaway"]
    static let labels = ["Hook", "Explanation", "Story", "Prac. App.", "Takeaway"]
    static let pageRanges = [0..<1, 1..<2, 2..<4, 4..<5, 5..<6]

    static func fill(stage: Int, page: Int) -> Double {
        let range = pageRanges[stage]
        return Double(min(range.count, max(0, page - range.lowerBound + 1))) / Double(range.count)
    }
}

extension Lesson {
    var usesSixStageProgress: Bool { pages.map(\.kind) == SixStageLesson.kinds && pages.map(\.role) == SixStageLesson.roles }
    func progressDescription(at index: Int) -> String {
        let physical = "Screen \(index + 1) of \(pages.count)"
        return usesSixStageProgress ? physical + " · " + SixStageLesson.accessibilityLabels[index] : physical
    }
}
