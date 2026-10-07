import Foundation
import UIKit
import CoreHaptics
import AudioToolbox

@MainActor protocol CompletionFeedbackPlaying {
    func playHaptic() throws
    func playSound() throws
}

/// Sound and haptic failures are independent, and never propagate into learner state.
@MainActor enum CompletionFeedback {
    static func deliver(using player: any CompletionFeedbackPlaying, settings: PlaybackSettings) {
        if settings.completionHaptics { try? player.playHaptic() }
        if settings.completionSound { try? player.playSound() }
    }
}

@MainActor final class SystemCompletionFeedback: CompletionFeedbackPlaying {
    private var engine: CHHapticEngine?
    private var sound: SystemSoundID = 0

    func playHaptic() throws {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return
        }
        do {
            if engine == nil { engine = try CHHapticEngine() }
            try engine?.start()
            let events = [0.0, 0.13].enumerated().map { index, time in
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: index == 0 ? 0.45 : 0.7),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.35)
                ], relativeTime: time)
            }
            let pattern = try CHHapticPattern(events: events, parameters: [])
            try engine?.makePlayer(with: pattern).start(atTime: CHHapticTimeImmediate)
        } catch {
            engine = nil
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    func playSound() throws {
        if sound == 0 {
            guard let url = Bundle.main.url(forResource: "insight-bloom", withExtension: "wav"),
                  AudioServicesCreateSystemSoundID(url as CFURL, &sound) == kAudioServicesNoError else { return }
            // UI sound semantics honor the silent switch independently of the narration
            // audio session. Never switch that shared session to ambient during speech.
            var uiSound: UInt32 = 1
            AudioServicesSetProperty(kAudioServicesPropertyIsUISound, UInt32(MemoryLayout<SystemSoundID>.size),
                                     &sound, UInt32(MemoryLayout<UInt32>.size), &uiSound)
        }
        AudioServicesPlaySystemSound(sound)
    }
    deinit { if sound != 0 { AudioServicesDisposeSystemSoundID(sound) } }
}
