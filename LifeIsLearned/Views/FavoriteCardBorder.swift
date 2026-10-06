import SwiftUI

struct CardMotionPolicy {
    var reduceMotion: Bool
    var visible: Bool
    var sceneActive: Bool
    var animatesFavorite: Bool { !reduceMotion && visible && sceneActive }
    var uses3DFlip: Bool { !reduceMotion }
}

/// A single lightweight drawing schedule, present only for a visible favorite.
struct FavoriteCardBorder: View {
    let favorite: Bool
    let visible: Bool
    var activatedAt: Date?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        let policy = CardMotionPolicy(reduceMotion: reduceMotion, visible: visible, sceneActive: scenePhase == .active)
        ZStack {
            RoundedRectangle(cornerRadius: 22).stroke(favorite ? Palette.amber : Palette.rule, lineWidth: favorite ? 1.8 : 1)
            if favorite && policy.animatesFavorite {
                TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    let activation = activatedAt.map { context.date.timeIntervalSince($0) } ?? 10
                    let sweep = activation >= 0 && activation < 0.45
                    let phase = sweep ? activation / 0.45 : t.truncatingRemainder(dividingBy: 8) / 8
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(AngularGradient(colors: [.clear, Palette.amber.opacity(0.15), Palette.amber, Palette.amber.opacity(0.2), .clear],
                                                center: .center, angle: .degrees(phase * 360)), lineWidth: sweep ? 3 : 2)
                        .shadow(color: Palette.amber.opacity(0.14 + 0.07 * sin(t * 1.5)), radius: 5)
                    if sweep {
                        Image(systemName: "sparkle").font(.system(size: 14)).foregroundStyle(Palette.amber)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                            .padding(.top, 49).padding(.trailing, 18).opacity(1 - activation / 0.45)
                    }
                }
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct CardVisibility: ViewModifier {
    let viewport: CGRect
    @Binding var visible: Bool
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollVisibilityChange(threshold: 0.01) { visible = $0 }
        } else {
            content.onGeometryChange(for: Bool.self) { proxy in
                let overlap = viewport.intersection(proxy.frame(in: .global))
                return overlap.width > 8 && overlap.height > 8
            } action: { visible = $0 }
        }
    }
}
