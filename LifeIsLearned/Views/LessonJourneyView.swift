import SwiftUI

/// One presentation owns the current lesson so advancing replaces the reader,
/// rather than stacking modal readers or passing back through the book list.
@MainActor struct LessonJourneyView: View {
    @State private var current: LessonLaunch
    let store: LibraryStore
    let speech: NarrationController
    let settings: PlaybackSettings
    var onBook: ((LearningBook) -> Void)?
    init(launch: LessonLaunch, store: LibraryStore, speech: NarrationController, settings: PlaybackSettings,
         onBook: ((LearningBook) -> Void)? = nil) {
        _current = State(initialValue: launch); self.store = store; self.speech = speech
        self.settings = settings; self.onBook = onBook
    }
    var body: some View {
        ReaderView(book: current.book, lesson: current.lesson, store: store, speech: speech,
            settings: settings, practiceOnly: current.practiceOnly, review: current.review,
            archivedPackage: current.archivedPackage, onCompletion: { onBook?(current.book) },
            onNext: { current = $0 })
            .id(current.id)
            .environmentObject(store).environmentObject(speech).environmentObject(settings)
    }
}
