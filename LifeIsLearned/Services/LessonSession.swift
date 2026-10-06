import Foundation
import Combine

@MainActor final class LessonSession: ObservableObject {
    typealias Phase = LearningPhase
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
    @Published private(set) var reflectionRemaining: TimeInterval?
    private var reflectionDeadline: Date?
    private var transition: Task<Void, Never>?
    private var generation = UUID()
    private let store: LibraryStore
    let speech: any Narrating
    private let settings: PlaybackSettings
    private let archivedPackage: LessonPackage?

    init(book: LearningBook, lesson: Lesson, store: LibraryStore, speech: any Narrating,
         settings: PlaybackSettings, practiceOnly: Bool, review: Bool = false, archivedPackage: LessonPackage? = nil) {
        self.book = book; self.lesson = lesson; self.store = store
        self.speech = speech; self.settings = settings; self.archivedPackage = archivedPackage
        let saved = store.status(book: book, lesson: lesson)
        index = review && saved.practiceComplete ? 0 : min(max(0, saved.pageIndex), lesson.pages.count - 1)
        phase = review && saved.practiceComplete ? .reading : (practiceOnly || saved.phase == .practice ? .practice : .reading)
        takeawayRevealed = saved.takeawayRevealed
        if saved.phase == .practice && phase == .practice {
            questionIndex = min(max(0, saved.practice.questionIndex), lesson.questions.count - 1)
            let choices = lesson.questions[questionIndex].choices
            selectedID = choices.contains { $0.id == saved.practice.selectedID } ? saved.practice.selectedID : nil
            attempted = saved.practice.attempted || selectedID != nil
            firstTryCorrect = min(max(0, saved.practice.firstTryCorrect), lesson.questions.count)
        }
    }
    var page: LessonPage { lesson.pages[index] }
    var question: PracticeQuestion { lesson.questions[questionIndex] }
    var choice: AnswerChoice? { question.choices.first { $0.id == selectedID } }
    var answerCorrect: Bool { selectedID == question.correctChoiceID }

    var assets: [String: CollectionArtwork] { archivedPackage?.artwork ?? store.package(for: book)?.artwork ?? [:] }
    var reviewDestination: LessonLaunch { LessonLaunch(book: book, lesson: lesson, review: true, archivedPackage: archivedPackage) }
    var nextIdea: LessonLaunch? { store.nextIdea(after: lesson, in: book) }
    var hasCollectedCard: Bool { store.cards[collectedCardID] != nil }
    var collectedCardID: String { LessonProgress.identity(bookID: book.id, lessonID: lesson.id) }
    func engage() { persist() }
    func persist() {
        store.update(book: book, lesson: lesson) {
            $0.pageIndex = index; $0.phase = phase; $0.takeawayRevealed = takeawayRevealed
            $0.practice = PracticePosition(questionIndex: questionIndex, selectedID: selectedID,
                                          attempted: attempted, firstTryCorrect: firstTryCorrect)
            $0.lastEngagedAt = Date()
        }
    }
    func toggleTakeaway() { takeawayRevealed.toggle(); persist() }

    func togglePlayback() {
        if autoRunning || speech.isPlaying { suspend(); return }
        if reflectionRemaining != nil { autoRunning = true; scheduleReflection(); return }
        if speech.isPaused { autoRunning = settings.autoAdvance && phase == .reading; speech.resume(); return }
        persist(); narrateCurrent()
    }
    private func narrateCurrent() {
        cancelTransition()
        guard phase != .complete else { return }
        let token = generation
        autoRunning = settings.autoAdvance && phase == .reading
        if phase == .practice {
            let text = choice.map { LessonNarration.feedback($0, correct: answerCorrect) }
                ?? LessonNarration.question(question)
            speech.speak(text, role: .guide, settings: settings, finished: nil)
            return
        }
        if page.kind == .takeaway { takeawayRevealed = true; persist() }
        speech.speak(LessonNarration.page(page), role: page.role, settings: settings) { [weak self] in
            guard let self, self.generation == token else { return }
            guard self.autoRunning, self.page.kind != .takeaway, self.index < self.lesson.pages.count - 1 else {
                self.autoRunning = false; return
            }
            self.reflectionRemaining = self.settings.pagePause
            self.scheduleReflection()
        }
    }
    private func scheduleReflection() {
        let token = generation
        let remaining = reflectionRemaining ?? settings.pagePause
        reflectionDeadline = Date().addingTimeInterval(remaining)
        transition?.cancel()
        transition = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(max(0, remaining) * 1_000_000_000))
            guard let self, !Task.isCancelled, self.generation == token, self.autoRunning else { return }
            self.changePage(self.index + 1, keepPlaying: true)
        }
    }
    private func cancelTransition() {
        generation = UUID(); transition?.cancel(); transition = nil
        reflectionRemaining = nil; reflectionDeadline = nil
    }
    func suspend() {
        // Keep the active utterance's token valid so a real pause can resume mid-sentence.
        if let deadline = reflectionDeadline { reflectionRemaining = max(0, deadline.timeIntervalSinceNow); reflectionDeadline = nil }
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
        persist()
        if continuePlaying { narrateCurrent() }
    }
    func replay() { stop(); narrateCurrent() }
    func beginPractice() {
        stop()
        store.update(book: book, lesson: lesson) { $0.readComplete = true }
        phase = .practice
        questionIndex = 0; selectedID = nil; attempted = false; firstTryCorrect = 0
        persist()
    }
    func answer(_ id: String) {
        guard selectedID == nil, question.choices.contains(where: { $0.id == id }) else { return }
        stop()
        if !attempted && id == question.correctChoiceID { firstTryCorrect += 1 }
        attempted = true; selectedID = id
        persist()
        if let choice {
            speech.speak(LessonNarration.feedback(choice, correct: answerCorrect),
                         role: .guide, settings: settings, finished: nil)
        }
    }
    func retry() { stop(); selectedID = nil; persist() }
    func nextQuestion() {
        guard answerCorrect else { return }
        stop()
        if questionIndex < lesson.questions.count - 1 {
            questionIndex += 1; selectedID = nil; attempted = false
            persist()
        } else {
            store.update(book: book, lesson: lesson) {
                if !$0.practiceComplete {
                    $0.practiceComplete = true; $0.questionCount = lesson.questions.count
                    $0.firstTryCorrect = firstTryCorrect; $0.practicedAt = Date()
                }
            }
            phase = .complete
            persist()
            speech.speak(LessonNarration.completion(correct: firstTryCorrect, total: lesson.questions.count), role: .guide, settings: settings, finished: nil)
        }
    }
}
