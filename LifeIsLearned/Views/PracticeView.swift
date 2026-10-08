import SwiftUI

struct PracticeView: View {
    @ObservedObject var session: LessonSession
    @ObservedObject var speech: NarrationController
    @ObservedObject var settings: PlaybackSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Color.clear.frame(height: 1).id("questionTop")
                        Eyebrow(text: "Put it into practice · \(session.questionIndex + 1) of \(session.lesson.questions.count)")
                        Text("Try it somewhere new.").font(.system(.title, design: .serif))
                        Text(session.question.prompt).font(.system(.title3, design: .serif)).lineSpacing(5)
                        VStack(spacing: 12) {
                            ForEach(Array(session.question.choices.enumerated()), id: \.element.id) { index, choice in
                                answer(choice, index: index)
                            }
                        }
                        if let choice = session.choice {
                            VStack(alignment: .leading, spacing: 12) {
                                Label(session.answerCorrect ? "That's right." : "Let's reconsider.", systemImage: session.answerCorrect ? "checkmark.circle.fill" : "arrow.counterclockwise.circle")
                                    .font(.headline).foregroundStyle(session.answerCorrect ? Palette.teal : Palette.amber)
                                Text(choice.feedback).lineSpacing(4)
                                if !session.answerCorrect { Text("A fresh attempt can help the idea settle.").font(.footnote).foregroundStyle(Palette.secondary) }
                            }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                                .background(session.answerCorrect ? Palette.tint : Palette.reflection, in: RoundedRectangle(cornerRadius: 16))
                                .id("feedback").transition(.opacity).accessibilityElement(children: .combine)
                        }
                    }.animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: session.selectedID)
                        .padding(.horizontal, 24).padding(.bottom, 24).readingWidth()
                }.onChange(of: session.questionIndex) { _, _ in proxy.scrollTo("questionTop", anchor: .top) }
                    .onChange(of: session.selectedID, initial: true) { _, selected in
                        if selected != nil {
                            DispatchQueue.main.async {
                                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { proxy.scrollTo("feedback", anchor: .bottom) }
                            }
                        } else { proxy.scrollTo("questionTop", anchor: .top) }
                    }
            }
            VStack(spacing: 10) {
                FineRule()
                if session.selectedID != nil {
                    PrimaryButton(title: session.answerCorrect ? (session.questionIndex == session.lesson.questions.count - 1 ? "Finish lesson" : "Continue") : "Try again", symbol: session.answerCorrect ? "arrow.right" : "arrow.counterclockwise") {
                        if session.answerCorrect { session.nextQuestion() } else { session.retry() }
                    }
                }
                Button { session.togglePlayback() } label: {
                    Label(speech.isPlaying ? "Pause" : "Read question or feedback", systemImage: speech.isPlaying ? "pause.fill" : "play.fill")
                        .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                }.buttonStyle(EditorialButtonStyle())
            }.padding(.horizontal, 24).padding(.bottom, 12).readingWidth().background(Palette.paper)
        }
    }
    private func answer(_ choice: AnswerChoice, index: Int) -> some View {
        let selected = session.selectedID == choice.id
        let accent = selected && !session.answerCorrect ? Palette.amber : Palette.teal
        return Button { session.answer(choice.id) } label: {
            HStack(alignment: .top, spacing: 14) {
                Text(String(UnicodeScalar(65 + index)!)).font(.caption.weight(.semibold))
                    .frame(width: 26, height: 26).background(selected ? accent : Palette.tint, in: Circle())
                    .foregroundStyle(selected ? Palette.onTeal : Palette.teal)
                Text(choice.text).font(.body).frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)
                if selected { Image(systemName: session.answerCorrect ? "checkmark" : "arrow.counterclockwise").foregroundStyle(accent).accessibilityHidden(true) }
            }.padding(18).foregroundStyle(Palette.ink)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(selected ? accent : Palette.rule, lineWidth: selected ? 2 : 1))
        }.buttonStyle(EditorialButtonStyle()).disabled(session.selectedID != nil)
            .accessibilityLabel("Option \(index + 1). \(choice.text)")
            .accessibilityValue(selected ? (session.answerCorrect ? "Selected, correct" : "Selected, try again") : "")
    }
}
