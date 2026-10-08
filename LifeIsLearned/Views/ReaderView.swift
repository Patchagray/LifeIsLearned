import SwiftUI
import AVFoundation
import Combine
import UIKit

@MainActor struct ReaderView: View {
    @StateObject private var session: LessonSession
    @ObservedObject private var speech: NarrationController
    @ObservedObject private var settings: PlaybackSettings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var showingSettings = false
    @State private var showingSources = false
    private var onCompletion: (() -> Void)?
    private var onNext: ((LessonLaunch) -> Void)?
    @State private var showingCard = false

    init(book: LearningBook, lesson: Lesson, store: LibraryStore, speech: NarrationController,
         settings: PlaybackSettings, practiceOnly: Bool = false, review: Bool = false, archivedPackage: LessonPackage? = nil, onCompletion: (() -> Void)? = nil, onNext: ((LessonLaunch) -> Void)? = nil) {
        _session = StateObject(wrappedValue: LessonSession(book: book, lesson: lesson, store: store,
                                                         speech: speech, settings: settings, practiceOnly: practiceOnly, review: review, archivedPackage: archivedPackage))
        _speech = ObservedObject(wrappedValue: speech); _settings = ObservedObject(wrappedValue: settings)
        self.onCompletion = onCompletion; self.onNext = onNext
    }
    // Tests can host a real view with a deterministic session; production uses the
    // same session type and initializer above, without injected UI-only behavior.
    init(session: LessonSession, speech: NarrationController, settings: PlaybackSettings) {
        _session = StateObject(wrappedValue: session)
        _speech = ObservedObject(wrappedValue: speech); _settings = ObservedObject(wrappedValue: settings)
    }
    var body: some View {
        VStack(spacing: 0) {
            header
            switch session.phase {
            case .reading: reading
            case .practice: PracticeView(session: session, speech: speech, settings: settings)
            case .complete: LessonCompletionView(session: session,
                continueBook: { session.stop(); onCompletion?(); dismiss() },
                continueNext: { next in session.stop(); onNext?(next) },
                viewCard: { session.stop(); showingCard = true },
                reviewIdea: { session.stop(); onNext?(session.reviewDestination) })
            }
        }.readingCanvas()
            .sheet(isPresented: $showingSettings) { SettingsView().environmentObject(settings) }
            .sheet(isPresented: $showingSources) { SourcesView(book: session.book) }
            .sheet(isPresented: $showingCard) {
                NavigationStack { IdeaCollectionView(initialCardID: session.collectedCardID)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { showingCard = false } } } }
            }
            .onAppear { session.engage() }
            .task { await session.prepareNarration() }
            .onDisappear { session.close(); UIApplication.shared.isIdleTimerDisabled = false }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { session.sceneBecameInactive(); UIApplication.shared.isIdleTimerDisabled = false }
            }
            .onChange(of: speech.isPlaying) { _, playing in UIApplication.shared.isIdleTimerDisabled = playing && scenePhase == .active }
            .onChange(of: speech.errorMessage) { _, message in if message != nil { session.stop() } }
    }
    private var header: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Text(session.lesson.title).font(.subheadline.weight(.semibold)).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                Button { session.stop(); showingSources = true } label: { Image(systemName: "text.book.closed").frame(width: 44, height: 44) }.accessibilityLabel("Lesson source notes")
                Button { session.stop(); showingSettings = true } label: { Image(systemName: "slider.horizontal.3").frame(width: 44, height: 44) }.accessibilityLabel("Playback settings")
                Button { session.stop(); dismiss() } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }.accessibilityLabel("Close lesson")
            }.buttonStyle(EditorialButtonStyle())
            if session.phase == .reading {
                LessonProgressIndicator(lesson: session.lesson, index: session.index)
            }
        }.padding(.horizontal, 20).padding(.top, 6).padding(.bottom, 14).readingWidth(820)
    }
    private var reading: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: session.lesson.usesSixStageProgress ? 12 : 22) {
                        Color.clear.frame(height: 1).id("top")
                        if !(session.lesson.usesSixStageProgress && session.page.kind == .takeaway) {
                            HStack(alignment: .firstTextBaseline) {
                                Eyebrow(text: session.lesson.usesSixStageProgress ? SixStageLesson.readerLabels[session.index] :
                                    (session.page.role == .guide ? "A moment with your guide" : "An original story"))
                                Spacer()
                                Text("\(session.index + 1) / \(session.lesson.pages.count)").font(.caption.monospacedDigit()).foregroundStyle(Palette.secondary)
                            }
                        }
                        if session.page.kind == .takeaway {
                            TakeawayCard(session: session, speech: speech, settings: settings)
                        } else {
                            Text(session.page.title).font(.system(session.lesson.usesSixStageProgress ? .title2 : .largeTitle, design: .serif)).tracking(-0.5)
                                .fixedSize(horizontal: false, vertical: true)
                            LessonIllustration(page: session.page, assets: session.assets,
                                               editorial: session.lesson.usesSixStageProgress && session.page.kind != .story)
                            NarrationText(text: session.page.text, title: session.page.title,
                                          spokenText: speech.spokenText, spokenRange: speech.spokenRange,
                                          isPlaying: speech.isPlaying, textSize: settings.textSize,
                                          followNarration: session.page.kind == .story)
                            if session.page.kind == .story, session.page.secondaryImageID != nil {
                                LessonIllustration(page: session.page, assets: session.assets, secondary: true)
                            }
                        }
                        if session.page.kind == .intro {
                            if session.lesson.usesSixStageProgress {
                                DisclosureGroup("Lesson scope and source limits") {
                                    Text(session.lesson.scopeNote).font(.footnote).foregroundStyle(Palette.secondary)
                                }.font(.footnote)
                            } else {
                                FineRule()
                                Text(session.lesson.scopeNote).font(.footnote).foregroundStyle(Palette.secondary)
                                Label("Play to listen, or turn the pages at your pace.", systemImage: "headphones")
                                    .font(.footnote).foregroundStyle(Palette.secondary)
                            }
                        }
                        if let error = speech.errorMessage { Text(error).font(.footnote).foregroundStyle(Palette.amber) }
                    }.padding(.horizontal, 24).padding(.bottom, 28).readingWidth()
                }.onChange(of: session.index) { _, _ in proxy.scrollTo("top", anchor: .top) }
            }
            controls
        }
    }
    private var controls: some View {
        VStack(spacing: 12) {
            Text(speech.mode == .preparing ? "Checking narration…" : speech.mode == .packaged ? "Studio narration · available offline" : "Device fallback voices").font(.caption).foregroundStyle(Palette.secondary).accessibilityIdentifier("narration-mode")
            FineRule()
            if session.page.kind == .takeaway {
                PrimaryButton(title: "Practice this idea", symbol: "arrow.right") { session.beginPractice() }.disabled(!session.takeawayRevealed)
            }
            HStack(spacing: 14) {
                RoundButton(symbol: "chevron.left", label: "Previous screen", enabled: session.index > 0) { session.changePage(session.index - 1) }
                RoundButton(symbol: "chevron.right", label: "Next screen", enabled: session.index < session.lesson.pages.count - 1) { session.changePage(session.index + 1) }
                Spacer(minLength: 0)
                RoundButton(symbol: "arrow.counterclockwise", label: "Replay screen") { session.replay() }
                RoundButton(symbol: speech.isPlaying || session.autoRunning ? "pause.fill" : "play.fill", label: speech.isPlaying || session.autoRunning ? "Pause narration" : "Play narration", prominent: true) { session.togglePlayback() }
            }
            Text(session.autoRunning ? (speech.isPlaying ? "Listening · pages turn with the narration" : "A moment to reflect…") :
                    (speech.isPaused || session.reflectionRemaining != nil) ? "Paused · Play continues" : "Your pace · \(session.page.role == .guide ? "guide" : "storyteller") voice")
                .font(.caption).foregroundStyle(Palette.secondary).multilineTextAlignment(.center)
        }.padding(.horizontal, 24).padding(.bottom, 12).readingWidth().background(Palette.paper)
    }
}
