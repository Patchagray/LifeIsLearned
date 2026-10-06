import SwiftUI

struct IdeaCardGrid: View {
    let cards: [IdeaCardPresentation]
    let viewport: CGRect
    var canFavorite = true
    let favorite: (String) -> Void
    let open: (String) -> Void
    var showDetails: ((String) -> Void)?
    @Environment(\.dynamicTypeSize) private var typeSize
    var availableWidth: CGFloat = 350
    var body: some View {
        let width = min(max(0, availableWidth), 820)
        let cardWidth = typeSize.isAccessibilitySize ? width : max(0, (width - 18) / 2)
        let height = cardWidth / 0.74
        Group {
            if typeSize.isAccessibilitySize {
                LazyVStack(spacing: 22) {
                    ForEach(cards) { card in tile(card, width: cardWidth).frame(minHeight: height) }
                }
            } else {
                HStack(alignment: .top, spacing: 18) {
                    column(parity: 0, width: cardWidth, height: height)
                    column(parity: 1, width: cardWidth, height: height).padding(.top, height * 0.4)
                }
            }
        }.frame(width: width).frame(maxWidth: .infinity)
        .accessibilityHidden(true)
        .overlayPreferenceValue(IdeaCardBounds.self) { anchors in
            GeometryReader { proxy in
                IdeaGridAccessibility(items: cards.compactMap { card in
                    anchors[card.id].map { .init(card: card, frame: proxy[$0]) }
                }, canFavorite: canFavorite, open: open, showDetails: showDetails ?? open, favorite: favorite)
            }
        }
    }

    private func column(parity: Int, width: CGFloat, height: CGFloat) -> some View {
        LazyVStack(spacing: 22) {
            ForEach(Array(cards.enumerated()).filter { $0.offset % 2 == parity }, id: \.element.id) { pair in
                tile(pair.element, width: width).frame(width: width, height: height)
            }
        }.frame(width: width)
    }
    private func tile(_ card: IdeaCardPresentation, width: CGFloat) -> some View {
        IdeaCardView(card: card, compact: true, spacious: width > 260, viewport: viewport, canFavorite: canFavorite,
                     favorite: { favorite(card.id) }, open: { open(card.id) })
            .anchorPreference(key: IdeaCardBounds.self, value: .bounds) { [card.id: $0] }
    }
}
