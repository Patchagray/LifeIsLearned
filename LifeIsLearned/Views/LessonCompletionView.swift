import SwiftUI

struct LessonCompletionView: View {
    @ObservedObject var session: LessonSession
    let continueBook: () -> Void
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                Eyebrow(text: "An idea, made yours")
                Image(systemName: "checkmark.circle").font(.system(size: 56, weight: .light)).foregroundStyle(Palette.teal).padding(.top, 12)
                Text("A little wiser.").font(.system(.largeTitle, design: .serif))
                Text("You've practiced a new idea.").font(.title3).foregroundStyle(Palette.secondary)
                FineRule()
                Text(session.lesson.title).font(.system(.title2, design: .serif))
                Text("\(session.firstTryCorrect) of \(session.lesson.questions.count) correct on the first try.").font(.headline)
                Text(session.firstTryCorrect == session.lesson.questions.count ? "Try noticing this idea in a real conversation today." : "You worked through the corrections. Revisit this idea later to strengthen it.")
                    .foregroundStyle(Palette.secondary).lineSpacing(5)
                PrimaryButton(title: "Continue book", symbol: "arrow.right", action: continueBook)
                Text("Return to the book to keep exploring.").font(.footnote).foregroundStyle(Palette.secondary)
            }.padding(28).readingWidth()
        }
    }
}
