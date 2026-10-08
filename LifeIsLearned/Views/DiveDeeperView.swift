import SwiftUI

struct DiveDeeperView: View {
    let destination: DiveDeeperDestination
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Eyebrow(text: "Beyond the core idea")
                    Text(destination.content.title).font(.system(.largeTitle, design: .serif))
                    Text(destination.lessonTitle).font(.subheadline).foregroundStyle(Palette.secondary)
                    Label("Optional reading · at your own pace", systemImage: "book.pages").font(.footnote).foregroundStyle(Palette.teal)
                    if let summary = destination.content.summary { Text(summary).font(.title3).lineSpacing(5) }
                    ForEach(destination.content.sections) { section in
                        FineRule()
                        VStack(alignment: .leading, spacing: 16) {
                            Text(section.title).font(.system(.title2, design: .serif)).accessibilityAddTraits(.isHeader)
                            Text(section.text).font(.body).lineSpacing(6).textSelection(.enabled)
                            DisclosureGroup("Reviewed sources") {
                                ForEach(destination.sources.filter { section.sourceIDs.contains($0.id) }) { source in
                                    VStack(alignment: .leading, spacing: 5) {
                                        if let url = URL(string: source.url) { Link(source.title, destination: url) }
                                        Text(source.locator).font(.footnote)
                                        Text(source.scope).font(.footnote).foregroundStyle(Palette.secondary)
                                    }.padding(.vertical, 8)
                                }
                            }.font(.subheadline)
                        }
                    }
                }.padding(26).readingWidth()
            }.readingCanvas().navigationTitle("Dive Deeper").navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("Done") { dismiss() } }
        }
    }
}
