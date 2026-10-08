import Foundation
import AVFoundation
import AudioToolbox

/// A disposable, file-backed lease. The installed payload is the only durable copy.
/// Every file name is generated, never taken from a book's asset ID.
final class PreparedNarration: @unchecked Sendable {
    struct Clip: Sendable {
        var script: NarrationScript
        var url: URL
        var durationMilliseconds: Int
        var cues: [NarrationCue]
    }
    let directory: URL
    let clips: [String: Clip]
    init(directory: URL, clips: [String: Clip]) { self.directory = directory; self.clips = clips }
    deinit { try? FileManager.default.removeItem(at: directory) }
}
enum AudioPreflight {
    /// Run once at app startup before opening any session; removes only our prior
    /// process's disposable leases left by a crash or forced termination.
    static func removeStaleLeases() {
        let root = FileManager.default.temporaryDirectory
        for url in (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? [] {
            if url.lastPathComponent.hasPrefix("LIL-Narration-"), UUID(uuidString: String(url.lastPathComponent.dropFirst("LIL-Narration-".count))) != nil {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
    static func prepare(lesson: Lesson, assets: [String: CollectionAudio], temporaryRoot: URL = FileManager.default.temporaryDirectory) throws -> PreparedNarration {
        try AudioContract.validateResourceLimits(assets)
        guard let bundle = lesson.narration else { throw PackageError.invalid("No studio narration for this idea.") }
        let scripts = LessonNarration.allSegments(lesson)
        try CollectionLimits.require(bundle.schemaVersion == 1 && bundle.segments.count == scripts.count &&
            Set(scripts.map(\.id)).count == scripts.count && Set(bundle.segments.map(\.id)).count == bundle.segments.count &&
            Set(bundle.segments.map(\.id)) == Set(scripts.map(\.id)), "Studio narration is incomplete or has duplicate segments.")
        let directory = temporaryRoot.appendingPathComponent("LIL-Narration-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
        var successful = false
        defer { if !successful { try? FileManager.default.removeItem(at: directory) } }
        var files: [String: (URL, Int)] = [:], clips: [String: PreparedNarration.Clip] = [:]
        for script in scripts {
            try Task.checkCancellation()
            guard let segment = bundle.segments.first(where: { $0.id == script.id }), let asset = assets[segment.assetID] else {
                throw PackageError.invalid("Missing studio narration: \(script.id).")
            }
            try CollectionLimits.require(segment.role == script.role && segment.scriptSHA256 == script.sha256,
                                        "Stale studio narration: \(script.id).")
            try CollectionLimits.require(segment.durationMilliseconds == asset.durationMilliseconds,
                                        "Studio narration duration mismatch.")
            if files[segment.assetID] == nil {
                let file = directory.appendingPathComponent(UUID().uuidString + ".mp3")
                try asset.data.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
                let measured = try validate(asset: asset, file: file)
                files[segment.assetID] = (file, measured)
            }
            let (file, duration) = files[segment.assetID]!
            clips[script.id] = PreparedNarration.Clip(script: script, url: file, durationMilliseconds: duration,
                cues: AudioContract.usableCues(segment.cues, text: script.text, duration: segment.durationMilliseconds))
        }
        successful = true
        return PreparedNarration(directory: directory, clips: clips)
    }
    static func validate(asset: CollectionAudio, file: URL) throws -> Int {
        try CollectionLimits.require(asset.mediaType == "audio/mpeg" && !asset.data.isEmpty && asset.data.count <= AudioContract.segmentBytes &&
            (1...AudioContract.maximumDuration).contains(asset.durationMilliseconds), "Invalid MP3 media type, bytes or duration.")
        let audio = try AVAudioFile(forReading: file)
        let format = audio.fileFormat.streamDescription.pointee
        try CollectionLimits.require(format.mFormatID == kAudioFormatMPEGLayer3 && audio.processingFormat.channelCount == 1,
                                    "Studio narration must decode as mono MP3.")
        let rate = audio.processingFormat.sampleRate
        try CollectionLimits.require(rate.isFinite && rate > 0 && audio.length > 0 && Double(audio.length) / rate <= 600,
                                    "Invalid MP3 duration.")
        guard let buffer = AVAudioPCMBuffer(pcmFormat: audio.processingFormat, frameCapacity: 8_192) else {
            throw PackageError.invalid("MP3 decoder could not allocate a buffer.")
        }
        var frames: Int64 = 0
        while frames < audio.length {
            try Task.checkCancellation()
            let requested = AVAudioFrameCount(min(Int64(buffer.frameCapacity), audio.length - frames))
            try audio.read(into: buffer, frameCount: requested)
            try CollectionLimits.require(buffer.frameLength > 0, "MP3 ended before its declared PCM length.")
            frames += Int64(buffer.frameLength)
        }
        let duration = Int((Double(frames) / rate * 1_000).rounded())
        try CollectionLimits.require(duration > 0 && duration <= AudioContract.maximumDuration &&
            abs(duration - asset.durationMilliseconds) <= max(250, asset.durationMilliseconds / 20), "MP3 measured duration does not match its metadata.")
        return duration
    }
    /// Decode before import without rejecting readable lessons for a broken optional bundle.
    static func importWarnings(_ package: LessonPackage) -> [String] {
        package.book.lessons.compactMap { lesson in
            guard lesson.narration != nil else { return nil }
            do { _ = try prepare(lesson: lesson, assets: package.audioAssets ?? [:]); return nil }
            catch { return "\(lesson.title): device fallback voices will be used. \(error.localizedDescription)" }
        }
    }
}
