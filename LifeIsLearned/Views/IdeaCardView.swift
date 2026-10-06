import SwiftUI
import UIKit

struct IdeaCardView: View {
    let card: IdeaCardPresentation
    var compact = false
    var spacious = false
    var viewport: CGRect = .zero
    var initiallyBack = false
    var canFavorite = true
    let favorite: () -> Void
    var open: (() -> Void)?
    var review: (() -> Void)?
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var back = false
    @State private var rotation = 0.0
    @State private var flipping = false
    @State private var flipGeneration = UUID()
    @State private var visible = false
    @State private var activatedAt: Date?
    private var showsAllText: Bool { !compact || typeSize.isAccessibilitySize }
    private var cardLabel: String {
        card.accessibilityLabel + (back ? ". Put it to work. " + card.record.snapshot.application : "")
    }
    private var flipActionLabel: String { compact ? "Open" : back ? "Show front" : "Show details" }
    var body: some View {
        presentedCard
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(cardLabel)
        .accessibilityIdentifier("card-" + card.id)
        .accessibilityValue(back ? "Details" : "Front")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { if compact { open?() } else { flip() } }
        .accessibilityAction(named: Text(flipActionLabel)) { if compact { open?() } else { flip() } }
        .accessibilityAction(named: Text(card.record.isFavorite ? "Unfavorite" : "Favorite"), toggleFavorite)
        .accessibilityAction(named: "Review lesson") { review?() }
    }
    private var presentedCard: some View {
        cardSurface
            .overlay { FavoriteCardBorder(favorite: card.record.isFavorite, visible: visible, activatedAt: activatedAt) }
            .modifier(CardVisibility(viewport: viewport, visible: $visible))
            .onAppear { back = initiallyBack; rotation = 0; flipping = false }
            .onDisappear { visible = false; flipGeneration = UUID() }
            .onChange(of: reduceMotion) { _, reduced in
                if reduced { flipGeneration = UUID(); rotation = 0; flipping = false }
            }
    }
    private var cardSurface: some View {
        ZStack(alignment: .topTrailing) {
            face
            favoriteButton
        }
    }
    private var face: some View {
        ZStack {
            if back && !compact { backFace.transition(.opacity) }
            else { frontFace.transition(.opacity) }
        }
        .rotation3DEffect(.degrees(reduceMotion ? 0 : rotation), axis: (x: 0, y: 1, z: 0), perspective: 0.35)
        .contentShape(RoundedRectangle(cornerRadius: 22))
        .onTapGesture { if compact { open?() } else { flip() } }
    }
    private var favoriteButton: some View {
        Button(action: toggleFavorite) {
            Image(systemName: card.record.isFavorite ? "star.fill" : "star")
                .font(.system(size: 19, weight: .medium)).foregroundStyle(Palette.amber)
                .frame(width: 44, height: 44)
                .background(Palette.surface.opacity(0.94), in: Circle())
        }.buttonStyle(.plain).padding(8).disabled(!canFavorite)
            .accessibilityLabel(card.record.isFavorite ? "Unfavorite idea" : "Favorite idea")
            .accessibilityIdentifier("favorite-" + card.id)
    }
    private func flip() {
        guard !flipping else { return }
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.15)) { back.toggle() }
            return
        }
        // Swap the actual face at the edge. Keeping two opacity-hidden scroll
        // views alive produces stale accessibility/hit-testing on the rear face.
        flipping = true
        let generation = UUID(); flipGeneration = generation
        withAnimation(.easeIn(duration: 0.2), completionCriteria: .logicallyComplete) {
            rotation = 90
        } completion: {
            guard flipGeneration == generation else { return }
            var transaction = Transaction(animation: nil); transaction.disablesAnimations = true
            withTransaction(transaction) { back.toggle(); rotation = -90 }
            withAnimation(.easeOut(duration: 0.2), completionCriteria: .logicallyComplete) {
                rotation = 0
            } completion: {
                if flipGeneration == generation { flipping = false }
            }
        }
    }
    private func toggleFavorite() {
        guard canFavorite else { return }
        if !card.record.isFavorite {
            activatedAt = Date()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        favorite()
    }
    private var frontFace: some View {
        VStack(alignment: .leading, spacing: compact ? 12 : 22) {
            Text(card.record.snapshot.title).font(compact && !spacious ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                .foregroundStyle(Palette.teal).lineLimit(showsAllText ? nil : 2)
                .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading).padding(.trailing, 35)
            if compact {
                takeaway.lineLimit(showsAllText ? nil : spacious ? 8 : 4)
            } else {
                ScrollView { takeaway.fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading) }
                    .scrollIndicators(.visible)
            }
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 6) {
                Rectangle().fill(Palette.teal.opacity(0.45)).frame(width: compact ? 24 : 40, height: 2)
                Text(card.record.snapshot.bookTitle).font(compact && !spacious ? .caption.weight(.medium) : .subheadline.weight(.medium)).lineLimit(showsAllText ? nil : 2)
                if !compact { Text(card.record.snapshot.author).font(.caption).foregroundStyle(Palette.secondary) }
                if card.updated || card.archived { Text(card.stateLabel).font(.caption).foregroundStyle(Palette.amber).fixedSize(horizontal: false, vertical: true) }
            }
        }.padding(compact ? (spacious ? 22 : 16) : 28).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 22))
    }
    private var takeaway: some View {
        Text(card.record.snapshot.takeaway)
            .font(.system(compact && !spacious ? .headline : .title2, design: .serif)).fontWeight(.medium)
            .foregroundStyle(Palette.ink).lineSpacing(compact ? 2 : 5)
    }
    private var backFace: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Eyebrow(text: "Put it to work").padding(.trailing, 36).frame(minHeight: 36)
                Text(card.record.snapshot.application).font(.system(.title2, design: .serif)).fixedSize(horizontal: false, vertical: true)
                FineRule()
                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow(text: "From")
                    Text(card.record.snapshot.bookTitle).font(.headline)
                    Text(card.record.snapshot.author).foregroundStyle(Palette.secondary)
                }
                Label(card.record.earnedLabel, systemImage: "checkmark.seal").font(.subheadline).foregroundStyle(Palette.secondary)
                if card.archived {
                    Text("Collected from an earlier collection revision. Your card stays with you.").font(.footnote).foregroundStyle(Palette.secondary)
                } else if card.updated { Text("Updated · review again").font(.subheadline).foregroundStyle(Palette.amber) }
                if let review { Button(action: review) { Label("Review lesson", systemImage: "arrow.right").frame(minHeight: 44) }
                    .buttonStyle(EditorialButtonStyle()).accessibilityIdentifier("review-card-lesson") }
            }.padding(28)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("card-details-" + card.id)
            .background(Palette.tint, in: RoundedRectangle(cornerRadius: 22))
    }
}
