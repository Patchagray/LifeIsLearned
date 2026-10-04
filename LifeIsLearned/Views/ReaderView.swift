import SwiftUI
import AVFoundation
import Combine
import UIKit

@MainActor struct ReaderView: View {
    @StateObject private var session: LessonSession
    @ObservedObject private var speech: SpeechPlayer
    @ObservedObject private var settings: PlaybackSettings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showingSettings = false
    @State private var showingSources = false

    init(book: LearningBook, lesson: Lesson, store: LibraryStore, speech: SpeechPlayer,
         settings: PlaybackSettings, practiceOnly: Bool = false) {
        _session = StateObject(wrappedValue: LessonSession(book: book, lesson: lesson, store: store,
                                                         speech: speech, settings: settings, practiceOnly: practiceOnly))
        _speech = ObservedObject(wrappedValue: speech)
        _settings = ObservedObject(wrappedValue: settings)
    }
    var body: some View {
        VStack(spacing: 0) {
            header
            switch session.phase {
            case .reading: reading
            case .practice: practice
            case .complete: completion
            }
        }.foregroundStyle(Palette.ink).background(Palette.paper.ignoresSafeArea())
            .sheet(isPresented: $showingSettings) { SettingsView() }
            .sheet(isPresented: $showingSources) { SourcesView(book: session.book) }
            .onDisappear { session.stop(); UIApplication.shared.isIdleTimerDisabled = false }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { session.suspend(); UIApplication.shared.isIdleTimerDisabled = false }
            }
            .onChange(of: speech.isPlaying) { _, playing in
                UIApplication.shared.isIdleTimerDisabled = playing && scenePhase == .active
            }
            .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { _ in session.stop() }
            .onChange(of: speech.errorMessage) { _, message in if message != nil { session.stop() } }
    }
    private var header: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Text(session.lesson.title).font(.headline).lineLimit(2)
                Spacer()
                Button { session.stop(); showingSources = true } label: { Image(systemName: "info.circle").font(.title3) }
                    .accessibilityLabel("Lesson source notes").frame(minWidth: 44, minHeight: 44)
                Button { session.stop(); showingSettings = true } label: { Image(systemName: "slider.horizontal.3").font(.title3) }
                    .accessibilityLabel("Playback settings").frame(minWidth: 44, minHeight: 44)
                Button { session.stop(); dismiss() } label: { Image(systemName: "xmark").font(.title3) }
                    .accessibilityLabel("Close lesson").frame(minWidth: 44, minHeight: 44)
            }
            if session.phase == .reading {
                HStack(spacing: 4) {
                    ForEach(session.lesson.pages.indices, id: \.self) { i in
                        Capsule().fill(i <= session.index ? Palette.teal : Palette.teal.opacity(0.18)).frame(height: 4)
                    }
                }.accessibilityElement(children: .ignore)
                    .accessibilityLabel("Screen \(session.index + 1) of \(session.lesson.pages.count)")
            }
        }.padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 14)
    }
    private var reading: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        Color.clear.frame(height: 1).id("top")
                        HStack {
                            Text(session.page.role == .guide ? "GUIDE" : "ORIGINAL STORY").font(.caption.weight(.semibold)).tracking(2)
                            Spacer()
                            Text("\(session.index + 1) / \(session.lesson.pages.count)").font(.caption).monospacedDigit()
                        }.foregroundStyle(Palette.teal)
                        if session.page.kind == .takeaway {
                            takeaway
                        } else {
                            Text(session.page.title).font(.largeTitle.bold())
                            narratedText.frame(maxWidth: .infinity, alignment: .leading)
                            LessonIllustration(page: session.page)
                        }
                        if session.page.kind == .intro {
                            Text(session.lesson.scopeNote).font(.footnote).foregroundStyle(.secondary)
                            Text("Start Play for continuous narration, or use the arrows to read at your pace.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        if let error = speech.errorMessage { Text(error).font(.footnote).foregroundStyle(Palette.amber) }
                    }.padding(.horizontal, 24).padding(.bottom, 24).frame(maxWidth: 680).frame(maxWidth: .infinity)
                }.onChange(of: session.index) { _, _ in proxy.scrollTo("top", anchor: .top) }
                    .onChange(of: speech.spokenRange) { _, range in
                        // Replay brings the title back into view before body narration starts.
                        if speech.isPlaying, range?.location == 0,
                           speech.spokenText == session.page.title + ". " + session.page.text {
                            proxy.scrollTo("top", anchor: .top)
                        }
                    }
            }
            controls
        }
    }
    private var narratedText: some View {
        NarrationText(text: session.page.text, title: session.page.title,
                      spokenText: speech.spokenText, spokenRange: speech.spokenRange,
                      isPlaying: speech.isPlaying, textSize: settings.textSize)
    }
    private var takeaway: some View {
        VStack(spacing: 22) {
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { session.takeawayRevealed.toggle() }
            } label: {
                VStack(alignment: .leading, spacing: 24) {
                    Image(systemName: session.takeawayRevealed ? "sparkles" : "rectangle.on.rectangle.angled")
                        .font(.system(size: 48)).foregroundStyle(Palette.amber)
                    Text(session.page.title).font(.title.bold())
                    if session.takeawayRevealed {
                        narratedText
                    } else {
                        Text("Tap to reveal your idea card.").foregroundStyle(.secondary)
                    }
                    Text(session.book.title).font(.caption).foregroundStyle(.secondary)
                }.padding(28).frame(maxWidth: .infinity, minHeight: 300, alignment: .leading)
                    .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 24))
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(Palette.amber.opacity(0.6), lineWidth: 2))
            }.buttonStyle(.plain).accessibilityHint("Reveals or hides the key takeaway")
            Text("Keep the idea. Then try it somewhere new.").font(.footnote).foregroundStyle(.secondary)
        }
    }
    private var controls: some View {
        VStack(spacing: 12) {
            if session.page.kind == .takeaway {
                PrimaryButton(title: "Practice this idea") { session.beginPractice() }
                    .disabled(!session.takeawayRevealed).opacity(session.takeawayRevealed ? 1 : 0.4)
            }
            HStack(spacing: 16) {
                RoundButton(symbol: "chevron.left", label: "Previous screen", enabled: session.index > 0) {
                    session.changePage(session.index - 1)
                }
                RoundButton(symbol: "chevron.right", label: "Next screen", enabled: session.index < session.lesson.pages.count - 1) {
                    session.changePage(session.index + 1)
                }
                Spacer()
                RoundButton(symbol: "arrow.counterclockwise", label: "Replay screen") { session.replay() }
                RoundButton(symbol: speech.isPlaying || session.autoRunning ? "pause.fill" : "play.fill", label: speech.isPlaying || session.autoRunning ? "Pause narration" : "Play narration") {
                    session.togglePlayback()
                }
            }
            Text(session.autoRunning ? (speech.isPlaying ? "Listening · screens advance automatically" : "A moment to reflect…") :
                 speech.isPaused ? "Paused · Play resumes narration" : "Your pace · \(session.page.role == .guide ? "guide" : "storyteller") voice")
                .font(.caption).foregroundStyle(.secondary)
        }.padding(.horizontal, 24).padding(.vertical, 14).frame(maxWidth: 680).frame(maxWidth: .infinity)
            .background(Palette.paper.shadow(color: .black.opacity(0.05), radius: 8, y: -4))
    }
    private var practice: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Color.clear.frame(height: 1).id("questionTop")
                        Text("TRY IT · \(session.questionIndex + 1) / \(session.lesson.questions.count)")
                            .font(.caption.weight(.semibold)).tracking(2).foregroundStyle(Palette.teal)
                        Image(systemName: "bubble.left.and.text.bubble.right.fill").font(.system(size: 48)).foregroundStyle(Palette.teal)
                        Text(session.question.prompt).font(.custom("Georgia", size: settings.textSize, relativeTo: .body)).lineSpacing(6)
                        ForEach(session.question.choices) { choice in
                            Button { session.answer(choice.id) } label: {
                                HStack(spacing: 12) {
                                    Text(choice.text).frame(maxWidth: .infinity, alignment: .leading)
                                    if session.selectedID == choice.id {
                                        Image(systemName: session.answerCorrect ? "checkmark.circle.fill" : "arrow.clockwise")
                                    }
                                }.font(.body).padding(18)
                                    .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 18))
                                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(session.selectedID == choice.id ? Palette.teal : .clear, lineWidth: 2))
                            }.buttonStyle(.plain).disabled(session.selectedID != nil)
                        }
                        if let choice = session.choice {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(session.answerCorrect ? "That's right." : "Let's reconsider.").font(.headline)
                                Text(choice.feedback).lineSpacing(4)
                            }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                                .background((session.answerCorrect ? Palette.teal : Palette.amber).opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
                        }
                    }.padding(24).frame(maxWidth: 680).frame(maxWidth: .infinity)
                }.onChange(of: session.questionIndex) { _, _ in proxy.scrollTo("questionTop", anchor: .top) }
            }
            VStack(spacing: 12) {
                if session.selectedID != nil {
                    PrimaryButton(title: session.answerCorrect ? (session.questionIndex == session.lesson.questions.count - 1 ? "Finish lesson" : "Continue") : "Try again") {
                        if session.answerCorrect { session.nextQuestion() } else { session.retry() }
                    }
                }
                Button { session.togglePlayback() } label: {
                    Label(speech.isPlaying ? "Pause" : "Read question or feedback", systemImage: speech.isPlaying ? "pause.fill" : "play.fill")
                        .font(.headline).padding(10)
                }
            }.padding(20).frame(maxWidth: 680).frame(maxWidth: .infinity)
        }
    }
    private var completion: some View {
        ScrollView {
            VStack(spacing: 26) {
                Image(systemName: "checkmark.seal.fill").font(.system(size: 84)).foregroundStyle(Palette.teal).padding(.top, 40)
                Text("Nice work.").font(.largeTitle.bold())
                Text("You've practiced a new idea.").multilineTextAlignment(.center)
                Text("\(session.firstTryCorrect) of \(session.lesson.questions.count) correct on the first try.").font(.headline)
                Text(session.firstTryCorrect == session.lesson.questions.count ? "Try noticing this idea in a real conversation today." : "You worked through the corrections. Revisit this idea later to strengthen it.")
                    .foregroundStyle(.secondary).multilineTextAlignment(.center)
                Text(session.lesson.title).font(.title2.bold()).padding(24).frame(maxWidth: .infinity)
                    .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 24))
                PrimaryButton(title: "Continue book") { session.stop(); dismiss() }
            }.padding(24).frame(maxWidth: 680).frame(maxWidth: .infinity)
        }
    }
}
