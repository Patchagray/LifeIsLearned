import SwiftUI

struct PrimaryButton: View {
    let title: String
    var symbol: String? = nil
    let action: () -> Void
    @Environment(\.isEnabled) private var enabled
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title).fixedSize(horizontal: false, vertical: true)
                if let symbol { Image(systemName: symbol).accessibilityHidden(true) }
            }.font(.headline).frame(maxWidth: .infinity, minHeight: 24).padding(16)
                .foregroundStyle(enabled ? Palette.onTeal : Palette.secondary)
                .background(enabled ? Palette.teal : Palette.tint, in: RoundedRectangle(cornerRadius: 14))
        }.buttonStyle(EditorialButtonStyle())
    }
}

struct RoundButton: View {
    let symbol: String
    let label: String
    var enabled = true
    var prominent = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.body.weight(.semibold))
                .frame(width: 48, height: 48)
                .foregroundStyle(enabled ? (prominent ? Palette.onTeal : Palette.ink) : Palette.secondary)
                .background(prominent && enabled ? Palette.teal : Palette.surface, in: Circle())
                .overlay(Circle().strokeBorder(Palette.rule, lineWidth: prominent ? 0 : 1))
        }.buttonStyle(EditorialButtonStyle()).disabled(!enabled)
            .accessibilityLabel(label)
    }
}

struct EmptyLearningView: View {
    let title: String
    let message: String
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.system(.title, design: .serif)).fixedSize(horizontal: false, vertical: true)
            Text(message).foregroundStyle(Palette.secondary).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 32)
    }
}
