import SwiftUI

struct ContinueLearningFeature: View {
    let destination: LearningDestination
    let assets: [String: CollectionArtwork]
    let action: () -> Void
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var typeSize
    private var illustration: LessonPage? {
        let pages = destination.lesson.pages
        let current = pages[min(max(0, destination.progress.pageIndex), pages.count - 1)]
        if current.imageID != nil || current.imageAsset != nil || current.imageBase64 != nil { return current }
        return pages.first { $0.imageID != nil || $0.imageAsset != nil || $0.imageBase64 != nil }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Eyebrow(text: destination.heading)
            if sizeClass == .regular && !typeSize.isAccessibilitySize {
                HStack(alignment: .center, spacing: 32) { featureText; featureArt.frame(maxWidth: 440) }
            } else {
                featureArt
                featureText
            }
        }
    }
    private var featureArt: some View {
        Group {
            if let illustration {
                LessonIllustration(page: illustration, assets: assets)
            } else {
                HStack { Spacer(); BookCover(book: destination.book, assets: assets).frame(width: 130); Spacer() }.padding(24).background(Palette.tint, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }
    private var featureText: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(destination.book.title).font(.subheadline.weight(.medium)).foregroundStyle(Palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(destination.lesson.title).font(.system(.largeTitle, design: .serif)).tracking(-0.7)
                .fixedSize(horizontal: false, vertical: true)
            Text(destination.position).font(.subheadline).foregroundStyle(Palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
            PrimaryButton(title: destination.buttonTitle, symbol: "arrow.right", action: action).accessibilityIdentifier("continue-learning").padding(.top, 4)
            if destination.book.isDemo == true {
                Text("DEMO · Introductory collection").font(.caption.weight(.medium)).foregroundStyle(Palette.secondary)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct LibraryBookCard: View {
    let book: LearningBook
    let assets: [String: CollectionArtwork]
    let practiced: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            BookCover(book: book, assets: assets)
            Text(book.title).font(.system(.headline, design: .serif)).foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(book.author).font(.subheadline).foregroundStyle(Palette.secondary).fixedSize(horizontal: false, vertical: true)
            ProgressView(value: Double(practiced), total: Double(book.lessons.count)).tint(Palette.teal)
            Text("\(practiced) of \(book.lessons.count) ideas practiced").font(.caption).foregroundStyle(Palette.secondary)
            if book.isDemo == true { Text("Demo / introductory").font(.caption).foregroundStyle(Palette.amber) }
        }.accessibilityElement(children: .combine)
    }
}
