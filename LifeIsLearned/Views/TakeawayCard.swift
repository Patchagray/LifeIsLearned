import SwiftUI

struct TakeawayCard: View {
    @ObservedObject var session: LessonSession
    @ObservedObject var speech: NarrationController
    @ObservedObject var settings: PlaybackSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: session.lesson.usesSixStageProgress ? 8 : 24) {
                HStack {
                    Eyebrow(text: "An idea to keep"); Spacer()
                    if session.lesson.usesSixStageProgress {
                        Text("6 / 6").font(.caption.monospacedDigit()).foregroundStyle(Palette.secondary)
                    }
                    Image(systemName: "bookmark").foregroundStyle(Palette.amber)
                }
                Text(session.page.title).font(.system(session.lesson.usesSixStageProgress ? .title2 : .largeTitle, design: .serif))
                if session.page.imageID != nil || session.page.imageAsset != nil || session.page.imageBase64 != nil {
                    LessonIllustration(page: session.page, assets: session.assets)
                        .frame(maxHeight: session.lesson.usesSixStageProgress ? 70 : 140)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(session.page.imageDescription ?? "Takeaway illustration")
                        .accessibilityAddTraits(.isImage)
                        .accessibilityIdentifier("takeaway-artwork")
                }
                FineRule()
                if session.takeawayRevealed {
                    NarrationText(text: session.page.text, title: session.page.title,
                                  spokenText: speech.spokenText, spokenRange: speech.spokenRange,
                                  isPlaying: speech.isPlaying, textSize: settings.textSize, followNarration: false)
                        .transition(.opacity)
                } else {
                    Text("Pause for a moment. What will you take with you?").font(.system(.title3, design: .serif)).foregroundStyle(Palette.secondary)
                }
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { session.toggleTakeaway() }
                } label: {
                    Label(session.takeawayRevealed ? "Hide takeaway" : "Reveal the idea", systemImage: session.takeawayRevealed ? "eye.slash" : "eye")
                        .font(.headline).frame(minHeight: 44)
                }.buttonStyle(EditorialButtonStyle()).accessibilityHint("Shows or hides the key takeaway without starting practice")
                Text(session.lesson.usesSixStageProgress ? session.book.title + " · " + session.book.author : "\(session.book.title)\n\(session.book.author)").font(.caption).foregroundStyle(Palette.secondary)
            }.padding(session.lesson.usesSixStageProgress ? 14 : 24).frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Palette.amber, lineWidth: 1))
            if !session.lesson.usesSixStageProgress {
                Text("Keep the idea. Then try it somewhere new.").font(.footnote).foregroundStyle(Palette.secondary)
            }
        }
    }
}
