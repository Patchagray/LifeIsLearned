import Foundation

/// A single atomic payload retains the existing failure-safe offload transaction.
/// Binary property lists store MP3 Data directly, without JSON/base64 expansion.
/// Playback leases are disposable temporary files, never a second durable library.
enum InstalledPayload {
    static func encode(_ package: LessonPackage) throws -> (bytes: Data, encoding: String?) {
        guard !(package.audioAssets ?? [:]).isEmpty else { return (try package.canonicalData(), nil) }
        let encoder = PropertyListEncoder(); encoder.outputFormat = .binary
        return (try encoder.encode(package), "binary-plist-1")
    }
    static func decode(_ bytes: Data, encoding: String?) throws -> LessonPackage {
        switch encoding {
        case nil: return try JSONDecoder().decode(LessonPackage.self, from: bytes)
        case "binary-plist-1": return try PropertyListDecoder().decode(LessonPackage.self, from: bytes)
        default: throw PackageError.invalid("Unsupported installed package encoding.")
        }
    }
}
