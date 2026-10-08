import Foundation
import Combine
import AVFoundation
import MediaPlayer
import UIKit

@MainActor final class NarrationController: ObservableObject, Narrating {
    enum Mode: String { case preparing, local, packaged }
    @Published private(set) var mode: Mode = .preparing
    @Published private(set) var isPlaying = false
    @Published private(set) var isPaused = false
    @Published private(set) var spokenText = ""
    @Published private(set) var spokenRange: NSRange?
    @Published private(set) var errorMessage: String?
    @Published private(set) var currentSegment: String?
    var ready: Bool { mode != .preparing }
    var supportsBackground: Bool { mode == .packaged }
    var remotePlay: (() -> Void)?
    var remotePause: (() -> Void)?
    var remoteToggle: (() -> Void)?
    private let local: any Narrating
    private let packaged: any PackagedPlaying
    private var prepared: PreparedNarration?
    private var preparation = UUID()
    private var subscriptions = Set<AnyCancellable>()
    private var speedSubscription: AnyCancellable?
    private var commands: [(MPRemoteCommand, Any)] = []
    private var interruption: NSObjectProtocol?
    private var routeChange: NSObjectProtocol?

    init(local: (any Narrating)? = nil, packaged: (any PackagedPlaying)? = nil) {
        self.local = local ?? SpeechPlayer(); self.packaged = packaged ?? PackagedNarrationPlayer()
        self.packaged.changed = { [weak self] playing, paused, range, error in
            guard let self, self.mode == .packaged else { return }
            self.isPlaying = playing; self.isPaused = paused; self.spokenRange = range
            if let error { self.errorMessage = error }
        }
        if let speech = self.local as? SpeechPlayer {
            speech.$isPlaying.combineLatest(speech.$isPaused, speech.$spokenRange, speech.$errorMessage)
                .sink { [weak self] playing, paused, range, error in
                    guard let self, self.mode == .local else { return }
                    self.isPlaying = playing; self.isPaused = paused; self.spokenRange = range; self.errorMessage = error
                }.store(in: &subscriptions)
        }
        interruption = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            guard (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt) == AVAudioSession.InterruptionType.began.rawValue else { return }
            Task { @MainActor in self?.handleInterruption() }
        }
        routeChange = NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] note in
            guard (note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt) == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue else { return }
            Task { @MainActor in self?.handleInterruption() }
        }
    }
    deinit {
        if let interruption { NotificationCenter.default.removeObserver(interruption) }
        if let routeChange { NotificationCenter.default.removeObserver(routeChange) }
        for (command, target) in commands { command.removeTarget(target) }
    }
    func prepare(lesson: Lesson, package: LessonPackage?) async {
        endSession()
        let token = UUID(); preparation = token
        let assets = package?.audioAssets ?? [:]
        let result = await Task.detached(priority: .userInitiated) { try? AudioPreflight.prepare(lesson: lesson, assets: assets) }.value
        guard preparation == token, !Task.isCancelled else { return }
        prepared = result; mode = result == nil ? .local : .packaged
        if let player = packaged as? PackagedNarrationPlayer {
            player.bookTitle = package?.book.title ?? "Life Is Learned"
            player.ideaTitle = lesson.title
            player.cover = package?.book.coverAssetID.flatMap { package?.artwork[$0]?.data }.flatMap(UIImage.init(data:))
        }
        if mode == .packaged { installRemoteCommands() }
    }
    func bind(settings: PlaybackSettings) {
        speedSubscription = settings.$speed.sink { [weak self] speed in
            guard let self, self.mode == .packaged else { return }; self.packaged.setSpeed(speed)
        }
    }
    func speakSegment(_ id: String, text: String, role: NarrationRole, settings: PlaybackSettings, finished: (() -> Void)?) {
        guard ready else { return }
        errorMessage = nil; currentSegment = id; spokenText = text; spokenRange = nil
        switch mode {
        case .packaged:
            guard let clip = prepared?.clips[id], clip.script.text == text, clip.script.role == role else {
                packaged.stop(); errorMessage = "This studio segment is unavailable. You can keep reading or reopen the idea to check narration again."; return
            }
            packaged.play(clip, speed: settings.speed) { finished?() }
        case .local: local.speak(text, role: role, settings: settings, finished: finished)
        case .preparing: break
        }
    }
    func speak(_ text: String, role: NarrationRole, settings: PlaybackSettings, finished: (() -> Void)?) {
        // Non-segment clients cannot silently introduce local speech into studio playback.
        guard mode == .local else { return }
        spokenText = text; local.speak(text, role: role, settings: settings, finished: finished)
    }
    func pause() { if mode == .packaged { packaged.pause() } else { local.pause() } }
    func resume() { if mode == .packaged { packaged.resume() } else { local.resume() } }
    func stop() {
        if mode == .packaged { packaged.stop() } else { local.stop() }
        isPlaying = false; isPaused = false; spokenRange = nil; spokenText = ""; currentSegment = nil
    }
    func endSession() {
        preparation = UUID(); stop(); prepared = nil; mode = .preparing; errorMessage = nil
        speedSubscription = nil
        for (command, target) in commands { command.removeTarget(target) }; commands = []
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    func handleInterruption() { remotePause?(); pause() }
    private func installRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        for command in [center.playCommand, center.pauseCommand, center.togglePlayPauseCommand] { command.isEnabled = true }
        commands = [
            (center.playCommand, center.playCommand.addTarget { [weak self] _ in Task { @MainActor in self?.remotePlay?() }; return .success }),
            (center.pauseCommand, center.pauseCommand.addTarget { [weak self] _ in Task { @MainActor in self?.remotePause?() }; return .success }),
            (center.togglePlayPauseCommand, center.togglePlayPauseCommand.addTarget { [weak self] _ in Task { @MainActor in
                self?.remoteToggle?()
            }; return .success })
        ]
    }
}
