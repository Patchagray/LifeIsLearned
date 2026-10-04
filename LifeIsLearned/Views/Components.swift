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

/// A wrapping, non-scrolling text view lets us locate the spoken line precisely
/// inside the reader's existing scroll view, including at accessibility sizes.
struct NarrationText: UIViewRepresentable {
    let text: String
    let title: String
    let spokenText: String
    let spokenRange: NSRange?
    let isPlaying: Bool
    let textSize: Double
    @ScaledMetric(relativeTo: .body) private var fontScale = 1.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static func bodyRange(text: String, title: String, spokenText: String, spokenRange: NSRange?) -> NSRange? {
        let prefix = title + ". "
        guard spokenText == prefix + text, let range = spokenRange,
              range.location >= (prefix as NSString).length else { return nil }
        let adjusted = NSRange(location: range.location - (prefix as NSString).length, length: range.length)
        guard adjusted.length > 0, Range(adjusted, in: text) != nil else { return nil }
        return adjusted
    }

    func makeUIView(context: Context) -> NarrationTextView { NarrationTextView() }

    func updateUIView(_ view: NarrationTextView, context: Context) {
        view.configure(text: text, fontSize: textSize * fontScale,
                       range: Self.bodyRange(text: text, title: title, spokenText: spokenText, spokenRange: spokenRange),
                       following: isPlaying, reduceMotion: reduceMotion)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: NarrationTextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width > 0 else { return nil }
        return CGSize(width: width, height: ceil(uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height))
    }
}

final class NarrationTextView: UITextView {
    private var spokenRange: NSRange?
    private var following = false
    private var reduceMotion = false
    private var updateGeneration = 0
    private var previousSize = CGSize.zero

    init() {
        // Use TextKit's actual line geometry instead of estimating from character counts.
        let storage = NSTextStorage()
        let layout = NSLayoutManager()
        let container = NSTextContainer(size: CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        storage.addLayoutManager(layout)
        layout.addTextContainer(container)
        super.init(frame: .zero, textContainer: container)
        isScrollEnabled = false
        isEditable = false
        isSelectable = false
        isUserInteractionEnabled = false
        backgroundColor = .clear
        textContainerInset = .zero
        textContainer.lineFragmentPadding = 0
        isAccessibilityElement = true
        accessibilityTraits = .staticText
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(text: String, fontSize: CGFloat, range: NSRange?, following: Bool, reduceMotion: Bool) {
        let font = UIFont(name: "Georgia", size: fontSize) ?? UIFont.systemFont(ofSize: fontSize)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 7
        let attributed = NSMutableAttributedString(string: text, attributes: [
            .font: font, .foregroundColor: UIColor(Palette.ink), .paragraphStyle: paragraph
        ])
        let validRange = range.flatMap { Range($0, in: text) != nil && $0.length > 0 ? $0 : nil }
        if let range = validRange {
            attributed.addAttribute(.foregroundColor, value: UIColor(Palette.teal), range: range)
            if let descriptor = font.fontDescriptor.withSymbolicTraits(.traitBold) {
                attributed.addAttribute(.font, value: UIFont(descriptor: descriptor, size: fontSize), range: range)
            }
        }
        if attributedText?.isEqual(to: attributed) != true { attributedText = attributed }
        accessibilityLabel = text
        spokenRange = validRange
        self.following = following
        self.reduceMotion = reduceMotion
        scheduleFollow()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if previousSize != bounds.size {
            previousSize = bounds.size
            scheduleFollow()
        }
    }

    private func scheduleFollow() {
        updateGeneration += 1
        let generation = updateGeneration
        // SwiftUI must finish laying out the text and its parent before we scroll.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.updateGeneration == generation else { return }
            self.followSpokenLine()
        }
    }

    func followSpokenLine() {
        guard following, let range = spokenRange, window != nil,
              !UIAccessibility.isVoiceOverRunning else { return }
        var ancestor = superview
        while let view = ancestor, !(view is UIScrollView) { ancestor = view.superview }
        guard let scroll = ancestor as? UIScrollView,
              !scroll.isTracking, !scroll.isDragging, !scroll.isDecelerating else { return }
        layoutManager.ensureLayout(for: textContainer)
        let glyphs = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        guard glyphs.length > 0 else { return }
        let line = layoutManager.lineFragmentRect(forGlyphAt: glyphs.location, effectiveRange: nil)
            .offsetBy(dx: textContainerInset.left, dy: textContainerInset.top)
        let rect = convert(line, to: scroll)
        let insets = scroll.adjustedContentInset
        let visibleTop = scroll.contentOffset.y + insets.top
        let visibleHeight = scroll.bounds.height - insets.top - insets.bottom
        guard visibleHeight > 0 else { return }
        // Keep the viewport still while the current line fits. Move a portion of
        // the page when it reaches the lower edge, leaving context above it.
        let margin = min(24, visibleHeight * 0.1)
        guard rect.minY < visibleTop || rect.maxY > visibleTop + visibleHeight - margin else { return }
        let minimum = -insets.top
        let maximum = max(minimum, scroll.contentSize.height - scroll.bounds.height + insets.bottom)
        let target = min(maximum, max(minimum, rect.minY - visibleHeight * 0.28 - insets.top))
        guard abs(target - scroll.contentOffset.y) > 1 else { return }
        scroll.setContentOffset(CGPoint(x: scroll.contentOffset.x, y: target), animated: !reduceMotion)
    }
}
