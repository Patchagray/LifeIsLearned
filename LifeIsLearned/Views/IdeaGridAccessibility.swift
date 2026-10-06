import SwiftUI
import UIKit

struct IdeaCardBounds: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] { [:] }
    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}

/// UIKit's explicit container order avoids column-by-column VoiceOver traversal.
/// These elements use the real lazy cards' bounds; the overlay never intercepts touches.
struct IdeaGridAccessibility: UIViewRepresentable {
    struct Item { let card: IdeaCardPresentation; let frame: CGRect }
    let items: [Item]
    let canFavorite: Bool
    let open: (String) -> Void
    let showDetails: (String) -> Void
    let favorite: (String) -> Void
    func makeUIView(context: Context) -> Container {
        let view = Container()
        view.isAccessibilityElement = false
        view.isUserInteractionEnabled = false
        view.shouldGroupAccessibilityChildren = true
        view.accessibilityContainerType = .semanticGroup
        return view
    }
    func updateUIView(_ view: Container, context: Context) {
        update(view)
    }
    func update(_ view: Container) {
        var retained: [String: CardElement] = [:]
        view.accessibilityElements = items.map { item in
            let card = item.card
            let element = view.cards[card.id] ?? CardElement(accessibilityContainer: view)
            retained[card.id] = element
            element.accessibilityIdentifier = "card-" + card.id
            element.accessibilityLabel = card.accessibilityLabel
            element.accessibilityTraits = .button
            element.accessibilityFrameInContainerSpace = item.frame
            element.activate = { open(card.id) }
            var actions = [UIAccessibilityCustomAction(name: "Open") { _ in open(card.id); return true },
                           UIAccessibilityCustomAction(name: "Show details") { _ in showDetails(card.id); return true }]
            if canFavorite {
                actions.append(UIAccessibilityCustomAction(name: card.record.isFavorite ? "Unfavorite" : "Favorite") { _ in favorite(card.id); return true })
            }
            element.accessibilityCustomActions = actions
            return element
        }
        view.cards = retained
    }
    final class Container: UIView { var cards: [String: CardElement] = [:] }
    final class CardElement: UIAccessibilityElement {
        var activate: (() -> Void)?
        override func accessibilityActivate() -> Bool { activate?(); return true }
    }
}
