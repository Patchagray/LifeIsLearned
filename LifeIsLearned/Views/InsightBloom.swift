import SwiftUI

/// One short accent around the existing completion mark, with no touch interception.
struct InsightBloom: View {
    var reduceMotion: Bool
    @State private var expanded = false
    @State private var visible = true
    var body: some View {
        ZStack {
            Circle().fill(Palette.teal.opacity(0.16)).blur(radius: 13)
                .frame(width: 88, height: 88)
            Circle().stroke(Palette.amber.opacity(0.65), lineWidth: 1.5)
                .frame(width: 70, height: 70)
                .scaleEffect(reduceMotion ? 1 : expanded ? 1.75 : 0.85)
            if !reduceMotion {
                ForEach(0..<7) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(index.isMultiple(of: 2) ? Palette.teal : Palette.amber)
                        .frame(width: 4, height: 7)
                        .offset(y: expanded ? -68 : -24)
                        .rotationEffect(.degrees(Double(index) * 360 / 7))
                }
            }
        }
        .opacity(visible ? 1 : 0)
        .allowsHitTesting(false).accessibilityHidden(true)
        .accessibilityIdentifier(reduceMotion ? "insight-bloom-restrained" : "insight-bloom")
        .task {
            withAnimation(.easeOut(duration: 0.85)) { expanded = true }
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.4)) { visible = false }
        }
    }
}
