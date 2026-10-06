import Foundation

struct LearningDestination: Identifiable {
    enum Action { case start, resume, next, revisit }
    let book: LearningBook
    let lesson: Lesson
    let progress: LessonProgress
    let action: Action
    var id: String { book.id + ":" + lesson.id }
    var buttonTitle: String {
        switch action {
        case .start: return "Start learning"
        case .resume: return "Resume"
        case .next: return "Start next idea"
        case .revisit: return "Revisit this book"
        }
    }
    var heading: String {
        switch action {
        case .start: return "A little at a time"
        case .resume: return "Continue learning"
        case .next: return "Your next idea"
        case .revisit: return "Collection complete"
        }
    }
    var position: String {
        if action == .revisit { return "All \(book.lessons.count) available ideas practiced" }
        if action == .start || action == .next { return LessonTiming(lesson: lesson).label }
        if progress.updated { return "Updated · review this idea again" }
        if progress.phase == .practice { return "Practice · Question \(min(max(0, progress.practice.questionIndex), lesson.questions.count - 1) + 1) of \(lesson.questions.count)" }
        return "Reading · Screen \(min(max(0, progress.pageIndex), lesson.pages.count - 1) + 1) of \(lesson.pages.count)"
    }
}

struct LessonLaunch: Identifiable {
    let id = UUID()
    let book: LearningBook
    let lesson: Lesson
    var practiceOnly = false
    var review = false
    var archivedPackage: LessonPackage?
}

extension LibraryStore {
    var continueLearning: LearningDestination? {
        let all = books.flatMap { book in book.lessons.map { (book, $0, status(book: book, lesson: $0)) } }
        let recent = all.filter { $0.2.lastEngagedAt != nil }.max { $0.2.lastEngagedAt! < $1.2.lastEngagedAt! }
        // Legacy installs have no reliable timestamps. Their saved screen can still
        // be offered, without inventing recency or an activity date.
        let selected = recent ?? all.first { $0.2.pageIndex > 0 || $0.2.readComplete || $0.2.practiceComplete } ?? all.first
        guard let (book, lesson, state) = selected else { return nil }
        if state.phase == .complete {
            let index = book.lessons.firstIndex { $0.id == lesson.id } ?? 0
            let following = Array(book.lessons.dropFirst(index + 1)) + Array(book.lessons.prefix(index))
            if let next = following.first(where: { !status(book: book, lesson: $0).practiceComplete }) {
                let nextState = status(book: book, lesson: next)
                return LearningDestination(book: book, lesson: next, progress: nextState,
                    action: nextState.lastEngagedAt == nil && nextState.pageIndex == 0 ? .next : .resume)
            }
            return LearningDestination(book: book, lesson: lesson, progress: state, action: .revisit)
        }
        return LearningDestination(book: book, lesson: lesson, progress: state,
            action: state.lastEngagedAt != nil || state.pageIndex > 0 || state.phase == .practice || state.updated ? .resume : .start)
    }
}

extension LibraryStore {
    func nextIdea(after lesson: Lesson, in book: LearningBook) -> LessonLaunch? {
        guard let active = books.first(where: { $0.id == book.id }),
              let index = active.lessons.firstIndex(where: { $0.id == lesson.id }), index + 1 < active.lessons.count else { return nil }
        let next = active.lessons[index + 1]
        return LessonLaunch(book: active, lesson: next, review: status(book: active, lesson: next).practiceComplete)
    }
}
