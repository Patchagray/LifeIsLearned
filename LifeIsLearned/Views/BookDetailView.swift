import SwiftUI

@MainActor struct BookDetailView: View {
    let book: LearningBook
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var settings: PlaybackSettings
    @EnvironmentObject private var speech: SpeechPlayer
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingOffload = false
    @State private var payloadBytes = 0
    @State private var launch: LessonLaunch?
    @State private var showingSources = false
    private var practiced: Int { book.lessons.filter { library.status(book: book, lesson: $0).practiceComplete }.count }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if typeSize.isAccessibilitySize {
                    BookCover(book: book, assets: library.package(for: book)?.artwork ?? [:]).frame(width: 130)
                    bookHeading
                } else {
                    HStack(alignment: .center, spacing: 24) {
                        BookCover(book: book, assets: library.package(for: book)?.artwork ?? [:]).frame(width: 120)
                        bookHeading
                    }
                }
                Text(book.synopsis).lineSpacing(5).fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow(text: book.isDemo == true ? "Demo · introductory collection" : "About this collection")
                    Text(book.selectionPreface).font(.subheadline).lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("collection-preface")
                    Text(book.coverageNote).font(.footnote).foregroundStyle(Palette.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button { speech.stop(); showingSources = true } label: {
                        Label("Sources & coverage", systemImage: "text.book.closed").font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                    }.buttonStyle(EditorialButtonStyle())
                }.padding(20).background(Palette.surface, in: RoundedRectangle(cornerRadius: 16))
                DisclosureGroup("About idea durations") {
                    Text(LessonTiming.help).font(.footnote).foregroundStyle(Palette.secondary)
                        .fixedSize(horizontal: false, vertical: true).padding(.top, 8)
                }.font(.subheadline).accessibilityIdentifier("duration-help")
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Your progress").font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(practiced) / \(book.lessons.count)").font(.subheadline.monospacedDigit()).foregroundStyle(Palette.secondary)
                    }
                    ProgressView(value: Double(practiced), total: Double(book.lessons.count))
                    Text("\(practiced) of \(book.lessons.count) available ideas practiced").font(.caption).foregroundStyle(Palette.secondary)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text("The ideas").font(.system(.title2, design: .serif)).padding(.bottom, 20)
                    ForEach(Array(book.lessons.enumerated()), id: \.element.id) { index, lesson in
                        let status = library.status(book: book, lesson: lesson)
                        FineRule()
                        Button { launch = LessonLaunch(book: book, lesson: lesson) } label: {
                            IdeaRow(number: index + 1, lesson: lesson, status: status)
                        }.buttonStyle(EditorialButtonStyle()).accessibilityIdentifier("idea-" + lesson.id)
                        if status.readComplete || status.practiceComplete {
                            Button { launch = LessonLaunch(book: book, lesson: lesson, practiceOnly: true) } label: {
                                Label("Practice this idea", systemImage: "arrow.clockwise").font(.subheadline).frame(minHeight: 44)
                            }.padding(.leading, 48).padding(.bottom, 12)
                        }
                    }
                    FineRule()
                }
            }.padding(24).readingWidth(760)
        }.readingCanvas().navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Offload Book", systemImage: "arrow.down.doc") {
                            speech.stop()
                            Task {
                                do { payloadBytes = try await library.storage.packageBytes(bookID: book.id); confirmingOffload = true }
                                catch { library.errorMessage = "Storage size could not be read. \(error.localizedDescription)" }
                            }
                        }.disabled(library.readOnly || library.isCommitting)
                    } label: { Image(systemName: "ellipsis.circle").frame(width: 44, height: 44) }
                        .accessibilityLabel("Book options")
                }
            }
            .confirmationDialog("Offload \(book.title)?", isPresented: $confirmingOffload, titleVisibility: .visible) {
                Button("Offload Book", role: .destructive) {
                    Task { if await library.offload(book) { dismiss() } }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Reclaim approximately \(ByteCountFormatter.string(fromByteCount: Int64(payloadBytes), countStyle: .file)). Idea Cards, favorites, progress and History stay. " +
                     (library.source(for: book.id).kind == .remoteCatalog ? "You can download this book again." : "You will need to re-import this book from its file."))
            }
            .overlay { if library.isCommitting { ProgressView("Saving library…").padding(24).background(Palette.surface, in: RoundedRectangle(cornerRadius: 16)) } }
            .fullScreenCover(item: $launch) { selected in
                LessonJourneyView(launch: selected, store: library, speech: speech, settings: settings)
            }.sheet(isPresented: $showingSources) { SourcesView(book: book) }
    }
    private var bookHeading: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(book.title).font(.system(.title, design: .serif)).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("book-detail-title")
            Text(book.author).font(.subheadline).foregroundStyle(Palette.secondary)
            Text("\(book.lessons.count) \(book.lessons.count == 1 ? "idea" : "ideas") available")
                .font(.caption.weight(.medium)).foregroundStyle(Palette.teal)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct IdeaRow: View {
    let number: Int
    let lesson: Lesson
    let status: LessonProgress
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text(String(format: "%02d", number)).font(.system(.title3, design: .serif)).foregroundStyle(Palette.teal).frame(minWidth: 30)
            VStack(alignment: .leading, spacing: 8) {
                Text(lesson.title).font(.headline).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
                Text(lesson.subtitle).font(.subheadline).foregroundStyle(Palette.secondary).fixedSize(horizontal: false, vertical: true)
                Text("\(LessonTiming(lesson: lesson).label) · \(status.label)").font(.caption.weight(.medium)).foregroundStyle(status.updated ? Palette.amber : Palette.teal)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: status.practiceComplete ? "checkmark.circle" : "arrow.up.right").foregroundStyle(Palette.teal).accessibilityHidden(true)
        }.padding(.vertical, 22).contentShape(Rectangle()).accessibilityElement(children: .combine)
    }
}
