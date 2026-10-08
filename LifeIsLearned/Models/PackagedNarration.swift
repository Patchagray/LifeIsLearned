import Foundation

struct CollectionAudio: Codable, Sendable {
    var mediaType: String
    var data: Data
    var durationMilliseconds: Int
}
struct NarrationCue: Codable, Equatable, Sendable {
    // Character coordinates are UTF-16, matching AVSpeechSynthesizer and NSRange.
    var characterStart: Int
    var characterLength: Int
    var startMilliseconds: Int
    var endMilliseconds: Int
}
struct NarrationSegment: Codable, Identifiable, Sendable {
    enum CodingKeys: String, CodingKey { case id, assetID, role, scriptSHA256, durationMilliseconds, cues }
    var id: String
    var assetID: String
    var role: NarrationRole
    var scriptSHA256: String
    var durationMilliseconds: Int
    var cues: [NarrationCue]? = nil
}
struct NarrationProvenance: Codable, Sendable {
    var provider: String
    var modelID: String? = nil
    var guideVoiceID: String? = nil
    var guideVoiceName: String? = nil
    var storytellerVoiceID: String? = nil
    var storytellerVoiceName: String? = nil
    var producedAt: Date? = nil
}
struct LessonNarrationBundle: Codable, Sendable {
    var schemaVersion: Int
    var segments: [NarrationSegment]
    var provenance: NarrationProvenance? = nil
}
struct NarrationScript: Codable, Equatable, Sendable {
    var id: String
    var role: NarrationRole
    var text: String
    var stage: String
    var sha256: String { LibraryDigest.sha256(Data(text.utf8)) }
}
extension LessonNarration {
    static func allSegments(_ lesson: Lesson) -> [NarrationScript] {
        var result = lesson.pages.map { NarrationScript(id: "page:" + $0.id, role: $0.role, text: page($0), stage: $0.title) }
        for q in lesson.questions {
            result.append(NarrationScript(id: "question:" + q.id, role: .guide, text: question(q), stage: "Practice"))
            for c in q.choices {
                result.append(NarrationScript(id: "feedback:\(q.id):\(c.id)", role: .guide,
                    text: feedback(c, correct: c.id == q.correctChoiceID), stage: "Feedback"))
            }
        }
        for score in 0...lesson.questions.count {
            result.append(NarrationScript(id: "completion:\(score)", role: .guide,
                text: completion(correct: score, total: lesson.questions.count), stage: "Complete"))
        }
        return result
    }
}
enum AudioContract {
    static let segmentBytes = 2 * 1_024 * 1_024
    static let totalBytes = 40 * 1_024 * 1_024
    static let maximumDuration = 600_000
    static func validateResourceLimits(_ assets: [String: CollectionAudio]) throws {
        try CollectionLimits.require(assets.count <= 2_000 && assets.keys.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }, "Invalid audio asset table.")
        var count = 0
        for asset in assets.values {
            try CollectionLimits.require(asset.data.count <= segmentBytes, "An audio segment exceeds 2 MiB.")
            count += asset.data.count
        }
        try CollectionLimits.require(count <= totalBytes, "Packaged audio exceeds 40 MiB.")
    }
    static func usableCues(_ cues: [NarrationCue]?, text: String, duration: Int) -> [NarrationCue] {
        guard let cues, cues.count <= 10_000 else { return [] }
        let length = text.utf16.count
        var lastTime = 0, lastCharacter = 0
        for cue in cues {
            guard cue.characterStart >= lastCharacter, cue.characterLength > 0,
                  cue.characterStart <= length, cue.characterLength <= length - cue.characterStart,
                  cue.startMilliseconds >= lastTime, cue.endMilliseconds > cue.startMilliseconds,
                  cue.endMilliseconds <= duration else { return [] }
            lastTime = cue.endMilliseconds; lastCharacter = cue.characterStart + cue.characterLength
        }
        return cues
    }
    static func range(at milliseconds: Int, cues: [NarrationCue]) -> NSRange? {
        cues.first { $0.startMilliseconds <= milliseconds && milliseconds < $0.endMilliseconds }
            .map { NSRange(location: $0.characterStart, length: $0.characterLength) }
    }
}

// Optional damaged audio must not make otherwise valid installed lessons unreadable.
// Semantic lesson fields remain strict. Missing/malformed optional audio selects fallback.
extension Lesson {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id); revision = try c.decode(Int.self, forKey: .revision)
        title = try c.decode(String.self, forKey: .title); subtitle = try c.decode(String.self, forKey: .subtitle)
        estimatedMinutes = try c.decode(Int.self, forKey: .estimatedMinutes); scopeNote = try c.decode(String.self, forKey: .scopeNote)
        pages = try c.decode([LessonPage].self, forKey: .pages); questions = try c.decode([PracticeQuestion].self, forKey: .questions)
        diveDeeper = try c.decodeIfPresent(DiveDeeperContent.self, forKey: .diveDeeper)
        narration = try? c.decodeIfPresent(LessonNarrationBundle.self, forKey: .narration)
    }
}
extension LessonPackage {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        formatVersion = try c.decode(Int.self, forKey: .formatVersion); book = try c.decode(LearningBook.self, forKey: .book)
        collectionRevision = try c.decodeIfPresent(Int.self, forKey: .collectionRevision)
        fullCollection = try c.decodeIfPresent(Bool.self, forKey: .fullCollection)
        manifest = try c.decodeIfPresent([IdeaManifestEntry].self, forKey: .manifest)
        removedLessonIDs = try c.decodeIfPresent([String].self, forKey: .removedLessonIDs)
        assets = try c.decodeIfPresent([String: CollectionArtwork].self, forKey: .assets)
        audioAssets = try? c.decodeIfPresent([String: CollectionAudio].self, forKey: .audioAssets)
    }
}
extension CollectionAudio {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        mediaType = (try? c.decode(String.self, forKey: .mediaType)) ?? "invalid"
        data = (try? c.decode(Data.self, forKey: .data)) ?? Data()
        durationMilliseconds = (try? c.decode(Int.self, forKey: .durationMilliseconds)) ?? 0
    }
}

extension NarrationSegment {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        assetID = try c.decode(String.self, forKey: .assetID)
        role = try c.decode(NarrationRole.self, forKey: .role)
        scriptSHA256 = try c.decode(String.self, forKey: .scriptSHA256)
        durationMilliseconds = try c.decode(Int.self, forKey: .durationMilliseconds)
        // Alignment is optional presentation metadata, never a reason to switch voices.
        cues = try? c.decodeIfPresent([NarrationCue].self, forKey: .cues)
    }
}
