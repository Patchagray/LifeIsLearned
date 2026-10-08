import Foundation
import Combine
import AVFoundation

@MainActor protocol Narrating: AnyObject {
    var isPlaying: Bool { get }
    var isPaused: Bool { get }
    var ready: Bool { get }
    var supportsBackground: Bool { get }
    func speakSegment(_ id: String, text: String, role: NarrationRole, settings: PlaybackSettings, finished: (() -> Void)?)
    func speak(_ text: String, role: NarrationRole, settings: PlaybackSettings, finished: (() -> Void)?)
    func pause()
    func resume()
    func stop()
}

extension Narrating {
    var ready: Bool { true }
    var supportsBackground: Bool { false }
    func speakSegment(_ id: String, text: String, role: NarrationRole, settings: PlaybackSettings, finished: (() -> Void)?) {
        speak(text, role: role, settings: settings, finished: finished)
    }
}

@MainActor final class SpeechPlayer: NSObject, ObservableObject, AVSpeechSynthesizerDelegate, Narrating {
    @Published private(set) var isPlaying = false
    @Published private(set) var isPaused = false
    @Published private(set) var spokenText = ""
    @Published private(set) var spokenRange: NSRange?
    @Published private(set) var errorMessage: String?
    private let synthesizer = AVSpeechSynthesizer()
    private var activeUtterance: AVSpeechUtterance?
    private var completion: (() -> Void)?
    private var interruptionObserver: NSObjectProtocol?

    override init() {
        super.init()
        synthesizer.delegate = self
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.stop() }
        }
    }
    deinit { if let interruptionObserver { NotificationCenter.default.removeObserver(interruptionObserver) } }

    func speak(_ text: String, role: NarrationRole, settings: PlaybackSettings, finished: (() -> Void)? = nil) {
        stop()
        errorMessage = nil
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            errorMessage = "Audio couldn't start: \(error.localizedDescription)"
            return
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = settings.voice(for: role)
        utterance.rate = Float(max(0.30, min(0.60, Double(AVSpeechUtteranceDefaultSpeechRate) * settings.speed)))
        // Age/timbre are not represented by the system API. Audition installed voices instead.
        activeUtterance = utterance
        completion = finished
        spokenText = text
        spokenRange = nil
        isPlaying = true
        isPaused = false
        synthesizer.speak(utterance)
    }
    func pause() {
        guard activeUtterance != nil else { return }
        if synthesizer.pauseSpeaking(at: .immediate) { isPlaying = false; isPaused = true }
    }
    func resume() {
        if synthesizer.continueSpeaking() { isPlaying = true; isPaused = false }
    }
    func stop() {
        // Invalidate FIRST. Delegate callbacks from an old utterance must not advance a new page.
        activeUtterance = nil
        completion = nil
        synthesizer.stopSpeaking(at: .immediate)
        isPlaying = false
        isPaused = false
        spokenRange = nil
        spokenText = ""
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self, self.activeUtterance === utterance else { return }
            let done = self.completion
            self.activeUtterance = nil
            self.completion = nil
            self.isPlaying = false
            self.isPaused = false
            self.spokenRange = nil
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            done?()
        }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self, self.activeUtterance === utterance else { return }
            self.stop()
        }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                      willSpeakRangeOfSpeechString range: NSRange, utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self, self.activeUtterance === utterance else { return }
            self.spokenRange = range
        }
    }
}
