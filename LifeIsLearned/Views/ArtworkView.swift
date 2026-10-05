import SwiftUI
import ImageIO
import CryptoKit

/// Image decoding happens off the main actor and is cached by image content.
actor ArtworkCache {
    static let shared = ArtworkCache()
    private var cache: [String: UIImage] = [:]
    func image(data: Data) -> UIImage? {
        let key = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        if let cached = cache[key] { return cached }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 1440,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { return nil }
        let result = UIImage(cgImage: image)
        if cache.count >= 12 { cache.removeAll() }
        cache[key] = result
        return result
    }
}

struct ArtworkView: View {
    let data: Data
    let description: String
    @State private var image: UIImage?
    var body: some View {
        Group {
            if let image { Image(uiImage: image).resizable().scaledToFit() }
            else { Rectangle().fill(Palette.tint).aspectRatio(1.5, contentMode: .fit).overlay(ProgressView()) }
        }.accessibilityLabel(description)
            .task(id: data) { image = await ArtworkCache.shared.image(data: data) }
    }
}

struct LessonIllustration: View {
    let page: LessonPage
    var assets: [String: CollectionArtwork] = [:]
    var body: some View {
        Group {
            if let id = page.imageID, let data = assets[id]?.data {
                ArtworkView(data: data, description: page.imageDescription ?? "Lesson illustration")
            } else if let encoded = page.imageBase64, let data = Data(base64Encoded: encoded) {
                ArtworkView(data: data, description: page.imageDescription ?? "Lesson illustration")
            } else if let asset = page.imageAsset {
                Image(asset).resizable().scaledToFit().accessibilityLabel(page.imageDescription ?? "Lesson illustration")
            }
        }.clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct BookCover: View {
    let book: LearningBook
    var assets: [String: CollectionArtwork] = [:]
    var body: some View {
        Color.clear.aspectRatio(0.75, contentMode: .fit)
            .overlay {
                GeometryReader { geometry in
                    ZStack {
                        Palette.teal
                        if let id = book.coverAssetID, let art = assets[id] {
                            ArtworkView(data: art.data, description: book.coverDescription ?? "Book collection artwork")
                                .frame(width: geometry.size.width, height: geometry.size.height)
                        } else {
                            VStack(alignment: .leading, spacing: 0) {
                                Text("LIFE IS\nLEARNED").font(.system(size: geometry.size.width * 0.075, weight: .semibold)).tracking(1.2)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                                Text(String(book.title.first ?? "L")).font(.system(size: geometry.size.height * 0.38, weight: .regular, design: .serif))
                                Spacer(minLength: 0)
                                Rectangle().frame(height: 1).opacity(0.5).padding(.bottom, 8)
                                Text("AN IDEA\nCOLLECTION").font(.system(size: geometry.size.width * 0.067, weight: .medium)).tracking(0.8)
                                    .fixedSize(horizontal: false, vertical: true)
                            }.padding(geometry.size.width * 0.13)
                                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .leading)
                                .foregroundStyle(Palette.onTeal).accessibilityHidden(true)
                            HStack { Rectangle().fill(.black.opacity(0.15)).frame(width: 5); Spacer() }.accessibilityHidden(true)
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Palette.rule.opacity(0.5), lineWidth: 1))
            .accessibilityLabel(book.coverAssetID == nil ? "Designed cover placeholder for \(book.title)" : book.coverDescription ?? book.title)
    }
}
