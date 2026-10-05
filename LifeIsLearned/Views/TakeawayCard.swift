import SwiftUI

struct TakeawayCard: View {
    @ObservedObject var session: LessonSession
    @ObservedObject var speech: SpeechPlayer
    @ObservedObject var settings: PlaybackSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 24) {
                HStack { Eyebrow(text: "An idea to keep"); Spacer(); Image(systemName: "bookmark").foregroundStyle(Palette.amber) }
                Text(session.page.title).font(.system(.largeTitle, design: .serif))
                FineRule()
                if session.takeawayRevealed {
                    NarrationText(text: session.page.text, title: session.page.title,
                                  spokenText: speech.spokenText, spokenRange: speech.spokenRange,
                                  isPlaying: speech.isPlaying, textSize: settings.textSize)
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
                Text("\(session.book.title)\n\(session.book.author)").font(.caption).foregroundStyle(Palette.secondary)
            }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Palette.amber, lineWidth: 1))
            Text("Keep the idea. Then try it somewhere new.").font(.footnote).foregroundStyle(Palette.secondary)
        }
    }
}
