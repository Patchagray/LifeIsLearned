import SwiftUI

@MainActor struct BookHistoryView: View {
    @EnvironmentObject private var library: LibraryStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Eyebrow(text: "What stays with you")
                Text("Your learning history.").font(.system(.largeTitle, design: .serif))
                Text("Books can leave your device. Your progress and collected ideas stay.")
                    .foregroundStyle(Palette.secondary)
                if library.history.isEmpty {
                    Text("Your books will appear here as your library grows.").padding(.vertical, 24)
                }
                ForEach(library.history) { record in
                    let installed = library.books.first { $0.id == record.bookID }
                    VStack(alignment: .leading, spacing: 12) {
                        FineRule()
                        Text(record.title).font(.system(.title2, design: .serif))
                        Text(record.author).foregroundStyle(Palette.secondary)
                        Text("\(record.lastKnownPracticedCount) / \(record.lastKnownIdeaCount) ideas practiced")
                            .font(.subheadline)
                        if let date = record.firstCompletedAt {
                            Text("First completed \(date.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption).foregroundStyle(Palette.secondary)
                        }
                        if record.firstCompletedAt == nil && record.hasCompletedBefore == true {
                            Text("Completed previously").font(.caption).foregroundStyle(Palette.secondary)
                        }
                        if record.hasUpdates { Label("Current version has updates", systemImage: "arrow.triangle.2.circlepath").font(.caption).foregroundStyle(Palette.amber) }
                        Label(installed == nil ? "Offloaded" : "In library", systemImage: installed == nil ? "icloud.and.arrow.down" : "books.vertical")
                            .font(.caption.weight(.medium)).foregroundStyle(Palette.teal)
                        if let installed {
                            NavigationLink("Open book") { BookDetailView(book: installed) }.frame(minHeight: 44)
                        } else {
                            Button(record.source.restoreTitle) { library.restoreBookID = record.bookID }
                                .frame(minHeight: 44).accessibilityIdentifier("restore-book-" + record.bookID)
                            Text(record.source.restoreMessage).font(.footnote).foregroundStyle(Palette.secondary)
                        }
                    }.accessibilityElement(children: .contain).accessibilityIdentifier("history-book-" + record.bookID)
                }
            }.padding(24).readingWidth(760)
        }.readingCanvas().navigationTitle("History").navigationBarTitleDisplayMode(.inline)
    }
}
