import SwiftUI

struct IdeaCardCarousel: View {
    let cards: [IdeaCardPresentation]
    @Binding var selectedID: String?
    @State private var scrollID: String?
    let viewport: CGRect
    let availableWidth: CGFloat
    var detailsID: String?
    var canFavorite = true
    let favorite: (String) -> Void
    let review: (IdeaCardRecord) -> Void
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        let width = min(availableWidth * 0.82, 430)
        let height = max(width / 0.74, typeSize.isAccessibilitySize ? 620 : 0)
        VStack(spacing: 22) {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 18) {
                    ForEach(cards) { card in
                        IdeaCardView(card: card, viewport: viewport, initiallyBack: card.id == detailsID, canFavorite: canFavorite,
                            favorite: { favorite(card.id) }, review: { review(card.record) })
                            .frame(width: width, height: height).id(card.id)
                    }
                }.scrollTargetLayout().padding(.vertical, 10)
            }.contentMargins(.horizontal, max(0, (availableWidth - width) / 2), for: .scrollContent)
                .scrollTargetBehavior(.viewAligned).scrollPosition(id: $scrollID, anchor: .center)
                .scrollIndicators(.hidden).frame(height: height + 20)
                .accessibilityIdentifier("idea-carousel")
                .task {
                    // Establish the native scroll position after the container has
                    // entered its sheet/window coordinate space.
                    await Task.yield()
                    scrollID = selectedID ?? cards.first?.id
                }
                .onChange(of: scrollID) { _, value in if let value { selectedID = value } }
                .onChange(of: selectedID) { _, value in if scrollID != value { scrollID = value } }
            if let card = cards.first(where: { $0.id == selectedID }) ?? cards.first {
                VStack(spacing: 8) {
                    Text("\((cards.firstIndex { $0.id == card.id } ?? 0) + 1) of \(cards.count)")
                        .font(.caption.monospacedDigit()).foregroundStyle(Palette.secondary)
                    Text(card.record.snapshot.bookTitle).font(.subheadline).foregroundStyle(Palette.secondary)
                    Text("Tap the card to turn it over").font(.caption).foregroundStyle(Palette.secondary)
                }.padding(.horizontal, 24).multilineTextAlignment(.center)
            }
        }
    }
}
