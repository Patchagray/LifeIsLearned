import SwiftUI
import UIKit

enum Palette {
    static let paper = Color(red: 0.98, green: 0.95, blue: 0.86)
    static let ink = Color(red: 0.14, green: 0.20, blue: 0.21)
    static let teal = Color(red: 0.12, green: 0.39, blue: 0.38)
    static let amber = Color(red: 0.68, green: 0.35, blue: 0.10)
}

struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.headline).frame(maxWidth: .infinity).padding(16)
                .foregroundStyle(.white).background(Palette.teal, in: Capsule())
        }.buttonStyle(.plain)
    }
}

struct RoundButton: View {
    let symbol: String
    let label: String
    var enabled = true
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.title3.weight(.semibold))
                .frame(width: 48, height: 48).background(.white.opacity(0.9), in: Circle())
        }.buttonStyle(.plain).disabled(!enabled).opacity(enabled ? 1 : 0.35).accessibilityLabel(label)
    }
}

struct LessonIllustration: View {
    let page: LessonPage
    var body: some View {
        Group {
            if let encoded = page.imageBase64, let data = Data(base64Encoded: encoded), let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage).resizable().scaledToFit()
            } else if let asset = page.imageAsset {
                Image(asset).resizable().scaledToFit()
            }
        }.clipShape(RoundedRectangle(cornerRadius: 20))
            .accessibilityLabel(page.imageDescription ?? "Story illustration")
    }
}

struct IdeaRow: View {
    let lesson: Lesson
    let status: LessonProgress
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "lightbulb.fill").font(.title2).foregroundStyle(Palette.amber)
                .frame(width: 44, height: 44).background(Palette.paper, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(lesson.title).font(.headline)
                Text(status.practiceComplete ? (status.needsReview ? "Practiced · revisit this idea" : "Practiced") :
                     (status.readComplete ? "Ready to practice" : "\(lesson.estimatedMinutes) min · read & listen"))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: status.practiceComplete ? "checkmark.circle.fill" : "chevron.right")
                .foregroundStyle(Palette.teal)
        }.padding(14).background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 18))
    }
}
