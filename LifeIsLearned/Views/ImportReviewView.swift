import SwiftUI

struct ImportReviewView: View {
    let review: ImportReview
    @EnvironmentObject private var library: LibraryStore
    @State private var acknowledgeRemovals = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Eyebrow(text: review.alreadyImported ? "Already in your library" : review.isUpdate ? "A new edition of your collection" : "Make room for a new book")
                    HStack(alignment: .top, spacing: 20) {
                        BookCover(book: review.package.book, assets: review.package.artwork).frame(width: 96)
                        VStack(alignment: .leading, spacing: 10) {
                            Text(review.package.book.title).font(.system(.title2, design: .serif))
                            Text(review.package.book.author).foregroundStyle(Palette.secondary)
                            Text("\(review.package.book.lessons.count) ideas · Collection \(review.package.collectionNumber)")
                                .font(.caption.weight(.medium)).foregroundStyle(Palette.teal)
                        }
                    }
                    FineRule()
                    VStack(alignment: .leading, spacing: 10) {
                        Text("What this collection covers").font(.headline)
                        Text(review.package.book.coverageNote).font(.subheadline).lineSpacing(4)
                        Text("The entire prepared release will be imported together. Coverage describes the source material reviewed.")
                            .font(.footnote).foregroundStyle(Palette.secondary)
                    }
                    if review.alreadyImported {
                        Label("This exact release is already imported. Your progress is unchanged.", systemImage: "checkmark.circle").foregroundStyle(Palette.teal)
                    } else if review.isUpdate {
                        FineRule()
                        Text("What will change").font(.system(.title2, design: .serif))
                        changeGroup("Unchanged", lessons: review.unchanged, explanation: "Reading and practice progress stays exactly where it is.")
                        changeGroup("Added", lessons: review.added, explanation: "New ideas begin fresh. Reinstated ideas keep their matching revision history.")
                        changeGroup("Revised", lessons: review.revised, explanation: "These ideas are marked Updated · review again. Earlier progress is archived; old answers won't apply to new questions.")
                        changeGroup("Removed", lessons: review.removed, explanation: "These ideas leave the active list. Their progress and previous collection snapshots are retained for recovery.")
                        if !review.removed.isEmpty {
                            Toggle("I understand these \(review.removed.count) ideas will be removed from the active collection", isOn: $acknowledgeRemovals)
                                .font(.subheadline).padding(16).background(Palette.reflection, in: RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    if let error = library.errorMessage {
                        Label(error, systemImage: "exclamationmark.circle").font(.subheadline).foregroundStyle(Palette.amber)
                    }
                }.padding(24).readingWidth()
            }.safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    if library.isCommitting { ProgressView("Saving your collection…") }
                    PrimaryButton(title: review.alreadyImported ? "Open book" : review.isUpdate ? "Import complete update" : "Import collection", symbol: "arrow.down.to.line") {
                        Task { await library.commitImport(review, acknowledgeRemovals: acknowledgeRemovals) }
                    }.disabled(library.isCommitting || (!review.removed.isEmpty && !acknowledgeRemovals))
                }.padding(20).readingWidth().background(Palette.paper)
            }.readingCanvas().navigationTitle("Review import").navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("Cancel") { library.cancelImport() }.disabled(library.isCommitting).frame(minHeight: 44) }
        }.interactiveDismissDisabled(library.isCommitting)
    }
    private func changeGroup(_ title: String, lessons: [Lesson], explanation: String) -> some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 12) {
                Text(explanation).font(.footnote).foregroundStyle(Palette.secondary)
                ForEach(lessons) { Text($0.title).font(.subheadline) }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 10)
        } label: {
            HStack { Text(title).font(.headline); Spacer(); Text("\(lessons.count)").monospacedDigit().foregroundStyle(Palette.secondary) }.frame(minHeight: 44)
        }
    }
}

struct ImportSuccessView: View {
    let book: LearningBook
    var alreadyImported = false
    let open: () -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Image(systemName: "checkmark.circle").font(.system(size: 44)).foregroundStyle(Palette.teal)
                    Text(alreadyImported ? "Ready when you are." : "A new place to begin.").font(.system(.largeTitle, design: .serif))
                    Text(book.title).font(.title2)
                    Text(alreadyImported ? "This release is already in your library. Your progress is unchanged." : "The complete collection is saved in your library. All \(book.lessons.count) ideas are ready to explore.")
                        .foregroundStyle(Palette.secondary)
                    PrimaryButton(title: "Open book", symbol: "arrow.right", action: open)
                }.padding(28).readingWidth()
            }.readingCanvas().toolbar { Button("Done") { dismiss() } }
        }
    }
}
