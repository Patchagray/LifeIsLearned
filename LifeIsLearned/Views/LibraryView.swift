import SwiftUI
import UniformTypeIdentifiers

@MainActor struct LibraryView: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var settings: PlaybackSettings
    @EnvironmentObject private var speech: SpeechPlayer
    @State private var importing = false
    @State private var showingSettings = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("A little at a time.").font(.largeTitle.bold()).foregroundStyle(Palette.ink)
                    Text("Read, listen, and practice one idea.").foregroundStyle(.secondary)
                    ForEach(library.books) { book in
                        NavigationLink {
                            BookDetailView(book: book)
                        } label: {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    Image(systemName: "book.closed.fill").font(.system(size: 44)).foregroundStyle(Palette.teal)
                                    Spacer()
                                    Text("\(book.lessons.count) \(book.lessons.count == 1 ? "idea" : "ideas") available")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Text(book.title).font(.title2.bold())
                                Text(book.author).foregroundStyle(.secondary)
                                let done = book.lessons.filter { library.status(book: book, lesson: $0).practiceComplete }.count
                                ProgressView(value: Double(done), total: Double(book.lessons.count))
                                    .accessibilityLabel("\(done) of \(book.lessons.count) available ideas practiced")
                            }.padding(24).background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 24))
                        }.buttonStyle(.plain)
                    }
                    PrimaryButton(title: "Import a lesson package") { importing = true }
                    Text("Choose a prepared JSON lesson package from Files. Source documents are reviewed before they become lessons.")
                        .font(.footnote).foregroundStyle(.secondary)
                }.padding(24).frame(maxWidth: 680).frame(maxWidth: .infinity)
            }.background(Palette.paper.ignoresSafeArea())
                .navigationTitle("Life Is Learned").navigationBarTitleDisplayMode(.inline)
                .toolbar { Button { speech.stop(); showingSettings = true } label: { Image(systemName: "slider.horizontal.3") }.accessibilityLabel("Playback settings") }
        }
        .sheet(isPresented: $showingSettings) { SettingsView() }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url): library.importPackage(from: url)
            case .failure(let error): library.errorMessage = error.localizedDescription
            }
        }
        .alert("Please check", isPresented: Binding(get: { library.errorMessage != nil }, set: { if !$0 { library.errorMessage = nil } })) {
            Button("OK") { library.errorMessage = nil }
        } message: { Text(library.errorMessage ?? "") }
    }
}

private struct LessonLaunch: Identifiable {
    let id = UUID()
    let lesson: Lesson
    let practiceOnly: Bool
}

@MainActor struct BookDetailView: View {
    let book: LearningBook
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var settings: PlaybackSettings
    @EnvironmentObject private var speech: SpeechPlayer
    @State private var launch: LessonLaunch?
    @State private var showingSources = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: "book.pages.fill").font(.system(size: 72)).foregroundStyle(Palette.teal).frame(maxWidth: .infinity).padding(.top)
                Text(book.title).font(.largeTitle.bold())
                Text("by \(book.author)").foregroundStyle(.secondary)
                Text(book.synopsis).font(.body)
                Text(book.coverageNote).font(.footnote).foregroundStyle(.secondary)
                Button("Source notes") { showingSources = true }.font(.headline)
                Text("Main ideas").font(.title2.bold())
                ForEach(book.lessons) { lesson in
                    let status = library.status(book: book, lesson: lesson)
                    VStack(spacing: 10) {
                        Button { launch = LessonLaunch(lesson: lesson, practiceOnly: false) } label: {
                            IdeaRow(lesson: lesson, status: status)
                        }.buttonStyle(.plain)
                        if status.readComplete || status.practiceComplete {
                            Button("Practice this idea") { launch = LessonLaunch(lesson: lesson, practiceOnly: true) }
                                .font(.subheadline).frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                }
            }.padding(24).frame(maxWidth: 680).frame(maxWidth: .infinity)
        }.background(Palette.paper.ignoresSafeArea()).navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(item: $launch) { selected in
                ReaderView(book: book, lesson: selected.lesson, store: library, speech: speech,
                           settings: settings, practiceOnly: selected.practiceOnly)
            }
            .sheet(isPresented: $showingSources) { SourcesView(book: book) }
    }
}

@MainActor struct SourcesView: View {
    let book: LearningBook
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section("Coverage") { Text(book.coverageNote) }
                ForEach(book.sources) { source in
                    Section(source.title) {
                        Text(source.locator)
                        Text(source.scope).font(.footnote).foregroundStyle(.secondary)
                        if let url = URL(string: source.url) { Link("Open source", destination: url) }
                    }
                }
            }.navigationTitle("Source notes").toolbar { Button("Done") { dismiss() } }
        }
    }
}
