import Foundation
import AVFoundation
import MediaPlayer
import UIKit

@MainActor protocol PackagedPlaying: AnyObject {
    var changed: ((Bool, Bool, NSRange?, String?) -> Void)? { get set }
    func play(_ clip: PreparedNarration.Clip, speed: Double, finished: @escaping () -> Void)
    func pause()
    func resume()
    func stop()
    func setSpeed(_ speed: Double)
}

@MainActor final class PackagedNarrationPlayer: PackagedPlaying {
    var changed: ((Bool, Bool, NSRange?, String?) -> Void)?
    private let player = AVPlayer()
    private var endObserver: NSObjectProtocol?
    private var failureObserver: NSObjectProtocol?
    private var timeObserver: Any?
    private var statusObserver: NSKeyValueObservation?
    private var token = UUID()
    private var clip: PreparedNarration.Clip?
    private var finished: (() -> Void)?
    private var rate: Float = 1
    private var paused = false
    private var playing = false
    private var range: NSRange?
    var bookTitle = ""
    var ideaTitle = ""
    var cover: UIImage?

    func play(_ clip: PreparedNarration.Clip, speed: Double, finished: @escaping () -> Void) {
        stop()
        let active = token
        self.clip = clip; self.finished = finished; rate = Float(speed)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { fail(error.localizedDescription); return }
        let item = AVPlayerItem(url: clip.url)
        item.audioTimePitchAlgorithm = .timeDomain
        player.replaceCurrentItem(with: item)
        playing = true; paused = false; publish()
        statusObserver = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            Task { @MainActor in
                guard let self, self.token == active else { return }
                if item.status == .failed { self.fail(item.error?.localizedDescription ?? "The audio file could not play.") }
            }
        }
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.token == active, self.playing, !self.paused else { return }
                self.playing = false; self.range = nil
                let done = self.finished; self.finished = nil
                self.publish(); done?()
            }
        }
        failureObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor in guard let self, self.token == active else { return }; self.fail("The audio file stopped unexpectedly. Replay this screen to try again.") }
        }
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.15, preferredTimescale: 600), queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self, self.token == active, self.playing, time.seconds.isFinite else { return }
                self.range = AudioContract.range(at: Int(time.seconds * 1_000), cues: clip.cues)
                self.publish()
            }
        }
        player.playImmediately(atRate: rate)
    }
    func setSpeed(_ speed: Double) { rate = Float(max(0.65, min(1.2, speed))); if playing { player.rate = rate }; publish() }
    func pause() { guard playing else { return }; player.pause(); playing = false; paused = true; publish() }
    func resume() { guard paused else { return }; paused = false; playing = true; player.playImmediately(atRate: rate); publish() }
    func stop() {
        token = UUID(); finished = nil
        player.pause()
        if let timeObserver { player.removeTimeObserver(timeObserver) }; timeObserver = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }; endObserver = nil
        if let failureObserver { NotificationCenter.default.removeObserver(failureObserver) }; failureObserver = nil
        statusObserver = nil; player.replaceCurrentItem(with: nil)
        clip = nil; playing = false; paused = false; range = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        changed?(false, false, nil, nil)
    }
    private func fail(_ message: String) { stop(); changed?(false, false, nil, message) }
    private func publish() {
        changed?(playing, paused, range, nil)
        guard let clip else { return }
        let seconds = player.currentTime().seconds
        var info: [String: Any] = [MPMediaItemPropertyTitle: ideaTitle,
            MPMediaItemPropertyAlbumTitle: bookTitle, MPMediaItemPropertyArtist: clip.script.stage,
            MPMediaItemPropertyPlaybackDuration: Double(clip.durationMilliseconds) / 1_000,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: seconds.isFinite ? seconds : 0,
            MPNowPlayingInfoPropertyPlaybackRate: playing ? rate : 0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: rate]
        if let cover { info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: cover.size) { _ in cover } }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
