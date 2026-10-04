import Foundation
import Combine

@MainActor final class LessonSession: ObservableObject {
    enum Phase { case reading, practice, complete }
    @Published private(set) var index: Int
    @Published private(set) var phase: Phase
    @Published private(set) var questionIndex = 0
    @Published private(set) var selectedID: String?
    @Published private(set) var firstTryCorrect = 0
    @Published private(set) var attempted = false
    @Published private(set) var autoRunning = false
    @Published var takeawayRevealed = false
    let book: LearningBook
    let lesson: Lesson
    private var transition: Task<Void, Never>?
    private var generation = UUID()
    private let store: LibraryStore
    let speech: any Narrating
    private let settings: PlaybackSettings

    init(book: LearningBook, lesson: Lesson, store: LibraryStore, speech: any Narrating,
         settings: PlaybackSettings, practiceOnly: Bool) {
        self.book = book; self.lesson = lesson; self.store = store
        self.speech = speech; self.settings = settings
        index = min(max(0, store.status(book: book, lesson: lesson).pageIndex), lesson.pages.count - 1)
        phase = practiceOnly ? .practice : .reading
    }
    var page: LessonPage { lesson.pages[index] }
    var question: PracticeQuestion { lesson.questions[questionIndex] }
    var choice: AnswerChoice? { question.choices.first { $0.id == selectedID } }
    var answerCorrect: Bool { selectedID == question.correctChoiceID }

    func togglePlayback() {
        if autoRunning || speech.isPlaying { suspend(); return }
        if speech.isPaused { autoRunning = settings.autoAdvance && phase == .reading; speech.resume(); return }
        narrateCurrent()
    }
    private func narrateCurrent() {
        cancelTransition()
        guard phase != .complete else { return }
        let token = generation
        autoRunning = settings.autoAdvance && phase == .reading
        if phase == .practice {
            let text = choice.map { (answerCorrect ? "That's right. " : "Let's reconsider. ") + $0.feedback }
                ?? (question.prompt + "\n" + question.choices.enumerated().map { "Option \($0.offset + 1). \($0.element.text)" }.joined(separator: "\n"))
            speech.speak(text, role: .guide, settings: settings, finished: nil)
            return
        }
        if page.kind == .takeaway { takeawayRevealed = true }
        speech.speak(page.title + ". " + page.text, role: page.role, settings: settings) { [weak self] in
            guard let self, self.generation == token else { return }
            guard self.autoRunning, self.page.kind != .takeaway, self.index < self.lesson.pages.count - 1 else {
                self.autoRunning = false; return
            }
            self.transition = Task { @MainActor [weak self] in
                guard let self else { return }
                try? await Task.sleep(nanoseconds: UInt64(self.settings.pagePause * 1_000_000_000))
                guard !Task.isCancelled, self.generation == token, self.autoRunning else { return }
                self.changePage(self.index + 1, keepPlaying: true)
            }
        }
    }
    private func cancelTransition() {
        generation = UUID(); transition?.cancel(); transition = nil
    }
    func suspend() {
        // Keep the active utterance's token valid so a real pause can resume mid-sentence.
        transition?.cancel(); transition = nil; autoRunning = false
        speech.pause()
    }
    func stop() {
        cancelTransition(); autoRunning = false; speech.stop()
    }
    func changePage(_ newIndex: Int, keepPlaying: Bool? = nil) {
        guard lesson.pages.indices.contains(newIndex) else { return }
        let continuePlaying = keepPlaying ?? (autoRunning || speech.isPlaying)
        stop()
        index = newIndex; takeawayRevealed = false
        store.update(book: book, lesson: lesson) { $0.pageIndex = newIndex }
        if continuePlaying { narrateCurrent() }
    }
    func replay() { stop(); narrateCurrent() }
    func beginPractice() {
        stop()
        store.update(book: book, lesson: lesson) { $0.readComplete = true }
        phase = .practice
    }
    func answer(_ id: String) {
        guard selectedID == nil, question.choices.contains(where: { $0.id == id }) else { return }
        stop()
        if !attempted && id == question.correctChoiceID { firstTryCorrect += 1 }
        attempted = true; selectedID = id
        if let choice {
            speech.speak((answerCorrect ? "That's right. " : "Let's reconsider. ") + choice.feedback,
                         role: .guide, settings: settings, finished: nil)
        }
    }
    func retry() { stop(); selectedID = nil }
    func nextQuestion() {
        guard answerCorrect else { return }
        stop()
        if questionIndex < lesson.questions.count - 1 {
            questionIndex += 1; selectedID = nil; attempted = false
        } else {
            store.update(book: book, lesson: lesson) {
                $0.practiceComplete = true; $0.questionCount = lesson.questions.count
                $0.firstTryCorrect = firstTryCorrect; $0.practicedAt = Date()
            }
            phase = .complete
            speech.speak("Lesson complete. You've practiced a new idea. \(firstTryCorrect) of \(lesson.questions.count) correct on the first try.", role: .guide, settings: settings, finished: nil)
        }
    }
}
