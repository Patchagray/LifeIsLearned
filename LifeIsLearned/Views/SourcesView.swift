import SwiftUI

struct SourcesView: View {
    let book: LearningBook
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Eyebrow(text: "Read with context")
                    Text("Where the ideas come from.").font(.system(.largeTitle, design: .serif))
                    Text(book.coverageNote).lineSpacing(5)
                    ForEach(book.sources) { source in
                        FineRule()
                        VStack(alignment: .leading, spacing: 12) {
                            Text(source.title).font(.headline)
                            Text(source.locator).font(.subheadline).foregroundStyle(Palette.secondary)
                            Text(source.scope).lineSpacing(4)
                            if let url = URL(string: source.url) {
                                Link(destination: url) { Label("Read the source", systemImage: "arrow.up.right").font(.headline).frame(minHeight: 44) }
                            }
                        }
                    }
                }.padding(24).readingWidth()
            }.readingCanvas().navigationTitle("Sources & coverage").navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("Done") { dismiss() }.frame(minHeight: 44) }
        }
    }
}
