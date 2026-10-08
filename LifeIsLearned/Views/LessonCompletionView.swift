import SwiftUI

struct LessonCompletionView: View {
    @ObservedObject var session: LessonSession
    let continueBook: () -> Void
    var continueNext: ((LessonLaunch) -> Void)?
    var viewCard: (() -> Void)?
    var reviewIdea: (() -> Void)?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // Native view tests can render both paths without changing the device preference.
    var reduceMotionOverride: Bool? = nil
    @State private var bloomID: UUID?
    @State private var deeper = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                Eyebrow(text: "An idea, made yours")
                Image(systemName: "checkmark.circle").font(.system(size: 56, weight: .light)).foregroundStyle(Palette.teal)
                    .overlay { if let event = bloomID { InsightBloom(reduceMotion: reduceMotionOverride ?? reduceMotion).id(event) } }
                    .padding(.top, 12)
                Text("A little wiser.").font(.system(.largeTitle, design: .serif))
                Text("You've practiced a new idea.").font(.title3).foregroundStyle(Palette.secondary)
                FineRule()
                Text(session.lesson.title).font(.system(.title2, design: .serif))
                Text("\(session.firstTryCorrect) of \(session.lesson.questions.count) correct on the first try.").font(.headline)
                Text(session.firstTryCorrect == session.lesson.questions.count ? "Try noticing this idea in a real conversation today." : "You worked through the corrections. Revisit this idea later to strengthen it.")
                    .foregroundStyle(Palette.secondary).lineSpacing(5)
                Label(session.hasCollectedCard ? "Idea collected" : "Card could not be saved", systemImage: "rectangle.stack.badge.plus")
                    .font(.subheadline.weight(.medium)).foregroundStyle(Palette.teal)
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.tint, in: RoundedRectangle(cornerRadius: 12))
                VStack(spacing: 12) {
                    if let next = session.nextIdea {
                        PrimaryButton(title: next.review ? "Review next idea" : "Continue to next idea", symbol: "arrow.right") { continueNext?(next) }
                            .accessibilityIdentifier("continue-next-idea")
                        Text(next.lesson.title).font(.subheadline).foregroundStyle(Palette.secondary)
                            .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                    } else {
                        PrimaryButton(title: "Finish book", symbol: "checkmark", action: continueBook)
                    }
                    Button("Back to book", action: continueBook).frame(minHeight: 44)
                    if let viewCard, session.hasCollectedCard { Button("View collected card", action: viewCard).frame(minHeight: 44) }
                    if session.canDiveDeeper {
                        Button("Dive deeper") { session.speech.stop(); deeper = true }.frame(minHeight: 44).accessibilityIdentifier("completion-dive-deeper")
                    }
                    if let reviewIdea { Button("Review this idea", action: reviewIdea).frame(minHeight: 44) }
                }.buttonStyle(EditorialButtonStyle())
            }.padding(28).readingWidth()
        }.onAppear { bloomID = session.takeCompletionBloom() }
            .onDisappear { bloomID = nil }
            .sheet(isPresented: $deeper) {
                if let content = session.lesson.diveDeeper, session.canDiveDeeper {
                    DiveDeeperView(destination: DiveDeeperDestination(content: content, sources: session.book.sources, lessonTitle: session.lesson.title))
                }
            }
    }
}
