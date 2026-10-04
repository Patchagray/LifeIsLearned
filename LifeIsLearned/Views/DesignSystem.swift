import SwiftUI
import UIKit

enum Palette {
    static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 255) / 255,
                           green: CGFloat((hex >> 8) & 255) / 255,
                           blue: CGFloat(hex & 255) / 255, alpha: 1)
        })
    }
    static let paper = adaptive(0xF7F3E9, 0x151F20)
    static let surface = adaptive(0xFFFCF5, 0x202D2E)
    static let ink = adaptive(0x203333, 0xF3EEE2)
    static let secondary = adaptive(0x596966, 0xB8C6BF)
    static let teal = adaptive(0x205C56, 0xA2D7C5)
    static let onTeal = adaptive(0xFFFFFF, 0x132D28)
    static let amber = adaptive(0x855118, 0xEAC087)
    static let rule = adaptive(0xCFD6CD, 0x4A5E59)
    static let tint = adaptive(0xE6EEE7, 0x2C413B)
    static let reflection = adaptive(0xF1E5D0, 0x3D3426)
}

enum Layout {
    static let readingWidth: CGFloat = 640
    static let homeWidth: CGFloat = 1040
    static let radius: CGFloat = 20
}

struct EditorialButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.76 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct Eyebrow: View {
    let text: String
    var body: some View {
        Text(text.uppercased()).font(.caption.weight(.semibold)).tracking(1.8)
            .foregroundStyle(Palette.teal).fixedSize(horizontal: false, vertical: true)
    }
}

struct FineRule: View {
    var body: some View { Rectangle().fill(Palette.rule).frame(height: 1).accessibilityHidden(true) }
}

struct ReadingCanvas: ViewModifier {
    func body(content: Content) -> some View {
        content.foregroundStyle(Palette.ink).background(Palette.paper.ignoresSafeArea()).tint(Palette.teal)
    }
}
extension View {
    func readingCanvas() -> some View { modifier(ReadingCanvas()) }
    func readingWidth(_ maximum: CGFloat = Layout.readingWidth) -> some View {
        frame(maxWidth: maximum).frame(maxWidth: .infinity)
    }
}
