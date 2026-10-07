import Foundation
import ImageIO
import CryptoKit

struct IdeaManifestEntry: Codable, Equatable, Sendable {
    var id: String
    var revision: Int
}

struct CollectionArtwork: Codable, Equatable, Sendable {
    var mediaType: String
    var data: Data
}

/// Limits apply before image decoding and before a file is copied into memory.
enum CollectionLimits {
    static let packageBytes = 64 * 1_024 * 1_024
    static let assetBytes = 2 * 1_024 * 1_024
    static let allAssetBytes = 24 * 1_024 * 1_024
    static let maximumDimension = 2_048

    static func validateImage(_ asset: CollectionArtwork) throws {
        try require(asset.data.count <= assetBytes, "An illustration exceeds 2 MiB. Export a smaller PNG or JPEG.")
        guard let source = CGImageSourceCreateWithData(asset.data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let type = CGImageSourceGetType(source) as String?,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else {
            throw PackageError.invalid("An illustration is unreadable. Export it again as PNG or JPEG.")
        }
        try require((type == "public.png" && asset.mediaType == "image/png") ||
                    (type == "public.jpeg" && asset.mediaType == "image/jpeg"), "Artwork must be PNG or JPEG with its matching mediaType.")
        try require(CGImageSourceGetCount(source) == 1 && width > 0 && height > 0 &&
                    width <= maximumDimension && height <= maximumDimension,
                    "Artwork must be a single image no larger than 2048 × 2048 pixels.")
        let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 32,
            kCGImageSourceShouldCacheImmediately: true
        ] as CFDictionary)
        try require(thumbnail != nil, "An illustration cannot be decoded. Export it again before importing.")
    }

    static func require(_ condition: Bool, _ message: String) throws {
        if !condition { throw PackageError.invalid(message) }
    }
}

extension LessonPackage {
    static func decodeImport(_ data: Data) throws -> LessonPackage {
        try CollectionLimits.require(data.count <= CollectionLimits.packageBytes, "Keep the complete collection under 64 MiB; optimize shared images first.")
        do { return try JSONDecoder().decode(Self.self, from: data).validated() }
        catch let error as PackageError { throw error }
        catch { throw PackageError.invalid("This file isn't a valid collection package. Check its required fields and JSON format with the authoring validator.") }
    }

    func canonicalData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }

    var collectionNumber: Int { collectionRevision ?? 0 }
    var artwork: [String: CollectionArtwork] { assets ?? [:] }

    /// The resolved image bytes and source definitions are part of lesson content.
    /// Asset IDs are references, not content. JSON whitespace/key order is irrelevant.
    func fingerprint(_ lesson: Lesson) throws -> String {
        struct LessonContent: Encodable {
            var lesson: Lesson
            var images: [Data?]
            var sources: [ContentSource]
        }
        var normalized = lesson
        var images: [Data?] = []
        for index in normalized.pages.indices {
            let page = normalized.pages[index]
            if let id = page.imageID { images.append(artwork[id]?.data) }
            else if let encoded = page.imageBase64 { images.append(Data(base64Encoded: encoded)) }
            else if let name = page.imageAsset {
                // A legacy bundled asset has a stable name. The migration tool uses
                // the corresponding optimized bytes in v2; installations keep v1 readable.
                images.append(Data(("bundled:" + name).utf8))
            } else { images.append(nil) }
            // Omit absent secondary images to preserve pre-005 fingerprints.
            if let id = page.secondaryImageID { images.append(artwork[id]?.data) }
            normalized.pages[index].secondaryImageID = nil
            normalized.pages[index].imageID = nil
            normalized.pages[index].imageAsset = nil
            normalized.pages[index].imageBase64 = nil
        }
        let usedSources = Set(lesson.pages.flatMap(\.sourceIDs))
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(LessonContent(lesson: normalized, images: images,
                    sources: book.sources.filter { usedSources.contains($0.id) }.sorted { $0.id < $1.id }))
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

struct LessonVersionRecord: Codable, Sendable {
    var revision: Int
    var fingerprint: String
}

struct CollectionCatalog: Codable, Sendable {
    var packages: [LessonPackage]
    var knownLessons: [String: LessonVersionRecord] = [:]
    var knownBooks: [String: BookVersionRecord]? = nil
    var version = UUID()

    mutating func record(_ package: LessonPackage) throws {
        if knownBooks == nil { knownBooks = [:] }
        knownBooks?[package.book.id] = BookVersionRecord(revision: package.collectionNumber,
            packageSHA256: LibraryDigest.sha256(try package.canonicalData()), ideas: package.book.lessons.map(BookIdeaIdentity.init))
        for lesson in package.book.lessons {
            knownLessons[LessonProgress.identity(bookID: package.book.id, lessonID: lesson.id)] =
                LessonVersionRecord(revision: lesson.revision, fingerprint: try package.fingerprint(lesson))
        }
    }
}

struct ImportReview: Identifiable, Sendable {
    let id = UUID()
    var package: LessonPackage
    var catalogVersion: UUID
    var isUpdate: Bool
    var alreadyImported = false
    var unchanged: [Lesson] = []
    var added: [Lesson] = []
    var revised: [Lesson] = []
    var removed: [BookIdeaIdentity] = []
    var source: BookSourceRecord? = nil
}

enum CollectionComparison {
    static func review(_ incoming: LessonPackage, catalog: CollectionCatalog) throws -> ImportReview {
        let previous = catalog.packages.first { $0.book.id == incoming.book.id }
        let retained = catalog.knownBooks?[incoming.book.id]
        var result = ImportReview(package: incoming, catalogVersion: catalog.version, isUpdate: previous != nil || retained != nil)
        if let previous {
            try CollectionLimits.require(incoming.collectionNumber >= previous.collectionNumber,
                "This is an older collection revision. Choose the latest complete release.")
            if incoming.collectionNumber == previous.collectionNumber {
                try CollectionLimits.require(try incoming.canonicalData() == previous.canonicalData(),
                    "This collection revision already exists with different content. Increase collectionRevision and every changed idea's revision before exporting.")
                result.alreadyImported = true
                result.unchanged = incoming.book.lessons
                return result
            }
            result.removed = previous.book.lessons.filter { old in !incoming.book.lessons.contains { $0.id == old.id } }.map(BookIdeaIdentity.init)
            let declared = Set(incoming.removedLessonIDs ?? [])
            try CollectionLimits.require(Set(result.removed.map(\.id)).isSubset(of: declared),
                "This update omits existing ideas. Restore them, or explicitly list their IDs in removedLessonIDs for review.")
            try CollectionLimits.require(declared.isDisjoint(with: Set(incoming.book.lessons.map(\.id))),
                "An idea cannot appear in both the manifest and removedLessonIDs.")
        }
        if previous == nil, let retained {
            try CollectionLimits.require(incoming.collectionNumber >= retained.revision,
                "This is an older collection revision. Choose the latest complete release.")
            if incoming.collectionNumber == retained.revision {
                try CollectionLimits.require(LibraryDigest.sha256(try incoming.canonicalData()) == retained.packageSHA256,
                    "This retained collection revision has different content. Increase collectionRevision before exporting.")
            }
            result.removed = retained.ideas.filter { old in !incoming.book.lessons.contains { $0.id == old.id } }
            try CollectionLimits.require(Set(result.removed.map(\.id)).isSubset(of: Set(incoming.removedLessonIDs ?? [])),
                "This release omits retained ideas. Explicitly list their IDs in removedLessonIDs for review.")
        }
        for lesson in incoming.book.lessons {
            let identity = LessonProgress.identity(bookID: incoming.book.id, lessonID: lesson.id)
            let existing = previous?.book.lessons.first { $0.id == lesson.id }
            let record = try catalog.knownLessons[identity] ?? existing.map {
                LessonVersionRecord(revision: $0.revision, fingerprint: try previous!.fingerprint($0))
            }
            if let record {
                try CollectionLimits.require(lesson.revision >= record.revision,
                    "“\(lesson.title)” has an older idea revision. Restore revision \(record.revision) or export a newer one.")
                if lesson.revision == record.revision {
                    try CollectionLimits.require(try incoming.fingerprint(lesson) == record.fingerprint,
                        "“\(lesson.title)” changed without an idea revision increase. Increase its revision, including when its illustration or referenced source changes.")
                    if existing != nil { result.unchanged.append(lesson) } else { result.added.append(lesson) }
                } else { result.revised.append(lesson) }
            } else { result.added.append(lesson) }
        }
        return result
    }
}
