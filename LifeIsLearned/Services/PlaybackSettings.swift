import Foundation
import Combine
import AVFoundation

@MainActor final class PlaybackSettings: ObservableObject {
    private let defaults: UserDefaults
    @Published var guideVoiceID: String { didSet { save() } }
    @Published var storyVoiceID: String { didSet { save() } }
    @Published var speed: Double { didSet { save() } }
    @Published var pagePause: Double { didSet { save() } }
    @Published var autoAdvance: Bool { didSet { save() } }
    @Published var textSize: Double { didSet { save() } }
    @Published var completionHaptics: Bool { didSet { save() } }
    @Published var completionSound: Bool { didSet { save() } }
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let d = defaults
        guideVoiceID = d.string(forKey: "guideVoice") ?? ""
        storyVoiceID = d.string(forKey: "storyVoice") ?? ""
        speed = d.object(forKey: "speed") as? Double ?? 1
        pagePause = d.object(forKey: "pagePause") as? Double ?? 2.0
        autoAdvance = d.object(forKey: "autoAdvance") as? Bool ?? true
        completionHaptics = d.object(forKey: "completionHaptics") as? Bool ?? true
        completionSound = d.object(forKey: "completionSound") as? Bool ?? true
        textSize = d.object(forKey: "textSize") as? Double ?? 20
    }
    private func save() {
        let d = defaults
        d.set(guideVoiceID, forKey: "guideVoice"); d.set(storyVoiceID, forKey: "storyVoice")
        d.set(speed, forKey: "speed"); d.set(pagePause, forKey: "pagePause")
        d.set(completionHaptics, forKey: "completionHaptics"); d.set(completionSound, forKey: "completionSound")
        d.set(autoAdvance, forKey: "autoAdvance"); d.set(textSize, forKey: "textSize")
    }
    func voice(for role: NarrationRole) -> AVSpeechSynthesisVoice? {
        let id = role == .guide ? guideVoiceID : storyVoiceID
        if !id.isEmpty, let voice = AVSpeechSynthesisVoice(identifier: id) { return voice }
        let desired: AVSpeechSynthesisVoiceGender = role == .guide ? .male : .female
        return Self.voices.first { $0.gender == desired } ?? Self.voices.first ?? AVSpeechSynthesisVoice(language: "en-US")
    }
    static var voices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("en") }
            .sorted {
                if $0.quality.rawValue != $1.quality.rawValue { return $0.quality.rawValue > $1.quality.rawValue }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
    }
}
