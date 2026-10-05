import XCTest
import AVFoundation
import UIKit
@testable import LifeIsLearned

/// Opt-in device timing via -only-testing:LifeIsLearnedTests/PremiumNarrationTimingTests.
/// Uses the production speech service with isolated settings; no library import or progress writes.
final class PremiumNarrationTimingTests: XCTestCase {
    @MainActor func testShortDemoWithInstalledPremiumVoices() async throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Premium reference timing requires installed premium voices on a physical device.")
        #else
        let premium = PlaybackSettings.voices.filter { $0.quality == .premium }
        func selected(_ key: String, gender: AVSpeechSynthesisVoiceGender) -> AVSpeechSynthesisVoice? {
            let saved = UserDefaults.standard.string(forKey: key)
            return premium.first { $0.identifier == saved } ?? premium.first { $0.gender == gender } ?? premium.first
        }
        guard let guide = selected("guideVoice", gender: .male), let storyteller = selected("storyVoice", gender: .female) else {
            throw XCTSkip("No installed premium English voices. Install reference voices before timing; no lower-quality fallback is allowed.")
        }
        let suite = "PremiumTiming." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = PlaybackSettings(defaults: defaults)
        settings.guideVoiceID = guide.identifier; settings.storyVoiceID = storyteller.identifier
        settings.speed = 1; settings.pagePause = 2
        XCTAssertEqual(settings.voice(for: .guide)?.quality, .premium)
        XCTAssertEqual(settings.voice(for: .storyteller)?.quality, .premium)
        let package = try ContentPolicyTests.shortDemo(), lesson = package.book.lessons[0]
        let timing = LessonTiming(lesson: lesson)
        let player = SpeechPlayer(); defer { player.stop() }
        var measured: [[String: Any]] = []
        let started = ProcessInfo.processInfo.systemUptime
        for (index, segment) in timing.segments.enumerated() {
            let done = expectation(description: segment.id)
            let began = ProcessInfo.processInfo.systemUptime
            player.speak(segment.text, role: segment.role, settings: settings) { done.fulfill() }
            XCTAssertNil(player.errorMessage)
            await fulfillment(of: [done], timeout: 90)
            let seconds = ProcessInfo.processInfo.systemUptime - began
            measured.append(["id": segment.id, "role": segment.role.rawValue, "text": segment.text, "seconds": seconds])
            if index < lesson.pages.count - 1 {
                try await Task.sleep(nanoseconds: 2_000_000_000)
            } else if segment.id.hasPrefix("question:") {
                // Explicit reference allowance, not an automated answer in the app.
                try await Task.sleep(nanoseconds: 20_000_000_000)
            }
        }
        let speech = measured.reduce(0.0) { $0 + ($1["seconds"] as! Double) }
        let total = speech + timing.pauseSeconds + timing.answerSeconds
        func voice(_ value: AVSpeechSynthesisVoice) -> [String: String] {
            ["identifier": value.identifier, "name": value.name, "quality": "premium"]
        }
        let report: [String: Any] = [
            "method": "speech-completion-callbacks", "bookID": package.book.id,
            "collectionRevision": package.collectionNumber,
            "reference": ["guide": voice(guide), "storyteller": voice(storyteller), "speed": 1,
                          "pagePauseSeconds": 2, "deviceModel": UIDevice.current.model,
                          "os": UIDevice.current.systemName + " " + UIDevice.current.systemVersion],
            "ideas": [["id": lesson.id, "revision": lesson.revision, "segments": measured]],
            "measuredSpeechSeconds": speech, "pauseSeconds": timing.pauseSeconds,
            "answerAllowanceSeconds": timing.answerSeconds, "measuredTotalSeconds": total,
            "observedScriptWallSeconds": ProcessInfo.processInfo.systemUptime - started,
            "scope": "Production SpeechPlayer scripted reference with longest feedback per question. Not a word-count estimate, user comprehension test, or automatic import."
        ]
        let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "premium-reference-timing"; attachment.lifetime = .keepAlways; add(attachment)
        print("PREMIUM_REFERENCE_TIMING " + String(decoding: data, as: UTF8.self))
        XCTAssertLessThanOrEqual(total, 300, "Shorten the demo if measured premium narration exceeds the reference budget.")
        #endif
    }
}
