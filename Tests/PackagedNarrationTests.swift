import XCTest
import AVFoundation
@testable import LifeIsLearned

@MainActor private final class DeviceNarrationSpy: Narrating {
    var isPlaying = false, isPaused = false
    var calls: [String] = []
    func speak(_ text: String, role: NarrationRole, settings: PlaybackSettings, finished: (() -> Void)?) { calls.append(text); isPlaying = true }
    func pause() { isPaused = true; isPlaying = false }
    func resume() { isPaused = false; isPlaying = true }
    func stop() { isPlaying = false; isPaused = false }
}
@MainActor private final class PackagedPlayerSpy: PackagedPlaying {
    var changed: ((Bool, Bool, NSRange?, String?) -> Void)?
    var calls: [String] = [], speeds: [Double] = []
    var done: (() -> Void)?
    func play(_ clip: PreparedNarration.Clip, speed: Double, finished: @escaping () -> Void) { calls.append(clip.script.id); speeds.append(speed); done = finished; changed?(true, false, nil, nil) }
    func pause() { changed?(false, true, nil, nil) }
    func resume() { changed?(true, false, nil, nil) }
    func stop() { done = nil; changed?(false, false, nil, nil) }
    func setSpeed(_ speed: Double) { speeds.append(speed) }
    func finish() { let callback = done; done = nil; changed?(false, false, nil, nil); callback?() }
}

@MainActor final class PackagedNarrationTests: XCTestCase {
    private func fixture() async throws -> CollectionFixture {
        let f = try await CollectionFixture.make(); addTeardownBlock { await f.cleanup() }; return f
    }
    private func encode<T: Encodable>(_ value: T) throws -> Data { let e = JSONEncoder(); e.outputFormatting = [.sortedKeys]; return try e.encode(value) }

    func testCompleteBundleAndLegacyDecodeAndEveryBranchMatchesExactScript() async throws {
        let f = try await fixture(), p = PackagedNarrationFixture.package(f.package), lesson = p.book.lessons[0]
        XCTAssertNil(f.package.audioAssets); XCTAssertNil(f.package.book.lessons[0].narration)
        let decoded = try LessonPackage.decodeImport(p.canonicalData())
        let prepared = try AudioPreflight.prepare(lesson: decoded.book.lessons[0], assets: decoded.audioAssets!)
        XCTAssertEqual(prepared.clips.count, 15) // six pages, two prompts, four feedback branches, three scores
        for script in LessonNarration.allSegments(lesson) {
            XCTAssertEqual(prepared.clips[script.id]?.script.text, script.text)
            XCTAssertEqual(prepared.clips[script.id]?.script.role, script.role)
            XCTAssertTrue(FileManager.default.fileExists(atPath: prepared.clips[script.id]!.url.path))
        }
        XCTAssertEqual(prepared.clips["feedback:question-0:no"]?.script.text, "Let's reconsider. You can retry this verification question.")
        for score in 0...2 { XCTAssertEqual(prepared.clips["completion:\(score)"]?.script.text, LessonNarration.completion(correct: score, total: 2)) }
        let a = XCTAttachment(data: try p.canonicalData(), uniformTypeIdentifier: "public.json")
        a.name = "audio-tone-package-fixture"; a.lifetime = .keepAlways; add(a)
        let scripts = XCTAttachment(data: try encode(LessonNarration.allSegments(lesson)), uniformTypeIdentifier: "public.json")
        scripts.name = "native-exact-audio-scripts"; scripts.lifetime = .keepAlways; add(scripts)
    }
    func testMissingStaleDuplicateCorruptAndMalformedAudioFallBackForWholeIdea() async throws {
        let f = try await fixture(), good = PackagedNarrationFixture.package(f.package)
        for fault in 0..<7 {
            var p = good
            switch fault {
            case 0: p.book.lessons[0].narration = nil
            case 1: p.book.lessons[0].narration?.segments.removeLast()
            case 2: p.book.lessons[0].narration?.segments[0].scriptSHA256 = String(repeating: "0", count: 64)
            case 3: p.audioAssets?["tone"]?.data = Data("not mp3".utf8)
            case 4: let first = p.book.lessons[0].narration!.segments[0]; p.book.lessons[0].narration?.segments[1] = first
            case 5: p.book.lessons[0].narration?.segments[0].role = .storyteller
            default: p.audioAssets?["tone"]?.durationMilliseconds = -1
            }
            let controller = NarrationController(local: DeviceNarrationSpy(), packaged: PackagedPlayerSpy())
            _ = try p.validated()
            await controller.prepare(lesson: p.book.lessons[0], package: p)
            XCTAssertEqual(controller.mode, .local)
            controller.endSession()
        }
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: good.canonicalData()) as? [String: Any])
        json["audioAssets"] = ["tone": ["mediaType": "audio/mpeg", "data": "broken-base64", "durationMilliseconds": 1200]]
        let damaged = try LessonPackage.decodeImport(JSONSerialization.data(withJSONObject: json))
        XCTAssertThrowsError(try AudioPreflight.prepare(lesson: damaged.book.lessons[0], assets: damaged.audioAssets ?? [:]))
        var book = json["book"] as! [String: Any]; var lessons = book["lessons"] as! [[String: Any]]
        lessons[0]["narration"] = "malformed optional bundle"; book["lessons"] = lessons; json["book"] = book
        XCTAssertNil(try LessonPackage.decodeImport(JSONSerialization.data(withJSONObject: json)).book.lessons[0].narration)
    }
    func testOneEngineReplaySpeedAndInteractiveSessionBranches() async throws {
        let f = try await fixture(), p = PackagedNarrationFixture.package(f.package)
        try await f.commit(p)
        let local = DeviceNarrationSpy(), player = PackagedPlayerSpy(), controller = NarrationController(local: local, packaged: player)
        let settings = PlaybackSettings(defaults: f.defaults); settings.autoAdvance = false; settings.completionSound = false; settings.completionHaptics = false
        let lesson = p.book.lessons[0]
        let session = LessonSession(book: p.book, lesson: lesson, store: f.store, speech: controller, settings: settings, practiceOnly: false)
        await session.prepareNarration(); XCTAssertEqual(controller.mode, .packaged)
        session.togglePlayback(); XCTAssertEqual(player.calls.last, "page:screen-0")
        session.suspend(); XCTAssertTrue(controller.isPaused)
        session.togglePlayback(); XCTAssertTrue(controller.isPlaying)
        session.replay(); XCTAssertEqual(player.calls, ["page:screen-0", "page:screen-0"])
        settings.speed = 0.8; XCTAssertEqual(player.speeds.last, 0.8)
        let stale = player.done; session.changePage(1); stale?(); XCTAssertEqual(session.index, 1)
        session.beginPractice(); session.togglePlayback(); XCTAssertEqual(player.calls.last, "question:question-0")
        session.answer("no"); XCTAssertEqual(player.calls.last, "feedback:question-0:no")
        session.retry(); session.answer("yes"); XCTAssertEqual(player.calls.last, "feedback:question-0:yes")
        session.nextQuestion(); session.togglePlayback(); XCTAssertEqual(player.calls.last, "question:question-1")
        session.answer("yes"); session.nextQuestion(); XCTAssertEqual(player.calls.last, "completion:1")
        XCTAssertTrue(f.store.status(book: p.book, lesson: lesson).practiceComplete)
        XCTAssertTrue(local.calls.isEmpty)
        player.changed?(false, false, nil, "injected playback failure")
        XCTAssertEqual(controller.mode, .packaged); XCTAssertTrue(local.calls.isEmpty)
        session.close()
        var incomplete = p; incomplete.book.lessons[0].narration?.segments.removeLast()
        await controller.prepare(lesson: incomplete.book.lessons[0], package: incomplete)
        let calls = player.calls.count
        for script in LessonNarration.allSegments(lesson) { controller.speakSegment(script.id, text: script.text, role: script.role, settings: settings, finished: nil) }
        XCTAssertEqual(controller.mode, .local); XCTAssertEqual(player.calls.count, calls); XCTAssertEqual(local.calls.count, 15)
        controller.endSession()
    }
    func testBackgroundInterruptionAndReflectionNeverSkipPractice() async throws {
        let f = try await fixture(), p = PackagedNarrationFixture.package(f.package)
        try await f.commit(p)
        let player = PackagedPlayerSpy(), controller = NarrationController(local: DeviceNarrationSpy(), packaged: player)
        let settings = PlaybackSettings(defaults: f.defaults); settings.pagePause = 0.03
        let session = LessonSession(book: p.book, lesson: p.book.lessons[0], store: f.store, speech: controller, settings: settings, practiceOnly: false)
        await session.prepareNarration(); session.togglePlayback(); session.sceneBecameInactive()
        XCTAssertTrue(session.autoRunning); XCTAssertTrue(controller.isPlaying)
        controller.handleInterruption(); XCTAssertFalse(session.autoRunning); XCTAssertTrue(controller.isPaused)
        try await Task.sleep(for: .milliseconds(60)); XCTAssertEqual(session.index, 0)
        controller.remotePlay?(); player.finish()
        controller.remotePause?() // cancel a pending reflection transition, including while locked
        try await Task.sleep(for: .milliseconds(60)); XCTAssertEqual(session.index, 0)
        controller.remotePlay?(); try await Task.sleep(for: .milliseconds(80)); XCTAssertEqual(session.index, 1)
        session.changePage(5, keepPlaying: true); player.finish()
        try await Task.sleep(for: .milliseconds(80)); XCTAssertEqual(session.phase, .reading); XCTAssertFalse(session.autoRunning)
        session.beginPractice(); XCTAssertEqual(session.questionIndex, 0); XCTAssertNil(session.selectedID)
        session.togglePlayback(); player.finish(); XCTAssertEqual(session.questionIndex, 0); XCTAssertNil(session.selectedID)
        session.close()
    }
    func testCuesUTF16MissingAndInvalidCuesNeverChangeEngine() async throws {
        let text = "Hi 😀. A second sentence."
        let cues = [NarrationCue(characterStart: 0, characterLength: 6, startMilliseconds: 0, endMilliseconds: 500),
                    NarrationCue(characterStart: 7, characterLength: 18, startMilliseconds: 500, endMilliseconds: 1200)]
        XCTAssertEqual(AudioContract.range(at: 700, cues: cues), NSRange(location: 7, length: 18))
        XCTAssertEqual(NarrationText.bodyRange(text: "A second sentence.", title: "Hi 😀", spokenText: text,
            spokenRange: AudioContract.range(at: 700, cues: cues)), NSRange(location: 0, length: 18))
        XCTAssertTrue(AudioContract.usableCues([NarrationCue(characterStart: Int.max, characterLength: 10, startMilliseconds: 0, endMilliseconds: 1)], text: text, duration: 1200).isEmpty)
        let f = try await fixture(); var p = PackagedNarrationFixture.package(f.package)
        for i in p.book.lessons[0].narration!.segments.indices { p.book.lessons[0].narration!.segments[i].cues = nil }
        let prepared = try AudioPreflight.prepare(lesson: p.book.lessons[0], assets: p.audioAssets!)
        XCTAssertTrue(prepared.clips.values.allSatisfy { $0.cues.isEmpty })
        var encoded = try XCTUnwrap(JSONSerialization.jsonObject(with: encode(p.book.lessons[0].narration!.segments[0])) as? [String: Any])
        encoded["cues"] = "malformed optional alignment"
        let segment = try JSONDecoder().decode(NarrationSegment.self, from: JSONSerialization.data(withJSONObject: encoded))
        XCTAssertNil(segment.cues)
        p.book.lessons[0].narration!.segments[0] = segment
        XCTAssertNoThrow(try AudioPreflight.prepare(lesson: p.book.lessons[0], assets: p.audioAssets!))
    }
    func testVoiceOnlyRevisionAndProseRevisionRules() async throws {
        let f = try await fixture(); var p = PackagedNarrationFixture.package(f.package)
        try await f.commit(p)
        let lesson = p.book.lessons[0]
        f.store.update(book: p.book, lesson: lesson) { $0.practiceComplete = true; $0.firstTryCorrect = 1 }
        await f.store.flush()
        let progress = try encode(f.store.progress), cards = try encode(f.store.cards)
        let fingerprint = try p.fingerprint(lesson)
        p.collectionRevision = 2
        p.audioAssets?["tone"]?.data.append(Data(repeating: 0, count: 128))
        p.book.lessons[0].narration?.provenance = NarrationProvenance(provider: "elevenlabs", modelID: "test-new-model", guideVoiceID: "test-not-production")
        p.book.lessons[0].narration?.segments[0].cues = nil
        XCTAssertEqual(try p.fingerprint(p.book.lessons[0]), fingerprint)
        try await f.commit(p)
        XCTAssertEqual(try encode(f.store.progress), progress); XCTAssertEqual(try encode(f.store.cards), cards)
        p.collectionRevision = 3; p.book.lessons[0].pages[0].text += " Changed meaning."
        XCTAssertThrowsError(try CollectionComparison.review(p, catalog: f.store.catalog))
        p.book.lessons[0].revision += 1; p.manifest?[0].revision += 1
        XCTAssertNoThrow(try CollectionComparison.review(p, catalog: f.store.catalog))
        XCTAssertThrowsError(try AudioPreflight.prepare(lesson: p.book.lessons[0], assets: p.audioAssets!))
    }
    func testAudioBudgetsAndTemporaryLeaseCleanup() async throws {
        let f = try await fixture(); var p = PackagedNarrationFixture.package(f.package)
        p.audioAssets?["tone"]?.data = Data(repeating: 1, count: AudioContract.segmentBytes + 1)
        XCTAssertThrowsError(try p.validated())
        p.audioAssets = Dictionary(uniqueKeysWithValues: (0..<21).map { (String($0), CollectionAudio(mediaType: "audio/mpeg", data: Data(repeating: 1, count: AudioContract.segmentBytes), durationMilliseconds: 1200)) })
        XCTAssertThrowsError(try p.validated())
        p = PackagedNarrationFixture.package(f.package)
        var prepared: PreparedNarration? = try AudioPreflight.prepare(lesson: p.book.lessons[0], assets: p.audioAssets!)
        let directory = prepared!.directory; XCTAssertTrue(FileManager.default.fileExists(atPath: directory.path))
        prepared = nil; XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
    }
    func testNativeMP3PlaybackFinishesFromFileAndProvidesCues() async throws {
        let f = try await fixture(), p = PackagedNarrationFixture.package(f.package)
        let prepared = try AudioPreflight.prepare(lesson: p.book.lessons[0], assets: p.audioAssets!)
        let player = PackagedNarrationPlayer(), end = expectation(description: "Native AVPlayer ended local MP3")
        var ranges: [NSRange] = []
        player.changed = { _, _, range, error in XCTAssertNil(error); if let range { ranges.append(range) } }
        player.play(prepared.clips["page:screen-0"]!, speed: 1.2) { end.fulfill() }
        await fulfillment(of: [end], timeout: 10)
        XCTAssertFalse(ranges.isEmpty); player.stop()
    }
    func testNormalizedAudioOffloadReinstallAndFailurePreserveLearnerState() async throws {
        let f = try await fixture(), p = PackagedNarrationFixture.package(f.package)
        try await f.commit(p)
        f.store.update(book: p.book, lesson: p.book.lessons[0]) { $0.practiceComplete = true; $0.practicedAt = Date(timeIntervalSince1970: 1_780_000_000) }
        let id = LessonProgress.identity(bookID: p.book.id, lessonID: p.book.lessons[0].id); f.store.toggleFavorite(id); await f.store.flush()
        let record = try XCTUnwrap(f.store.installed.first { $0.bookID == p.book.id })
        XCTAssertEqual(record.payloadEncoding, "binary-plist-1")
        XCTAssertLessThan(record.packageBytes, try p.canonicalData().count)
        var noAudio = p; noAudio.audioAssets = nil
        XCTAssertGreaterThan(record.packageBytes, try InstalledPayload.encode(noAudio).bytes.count)
        let cards = try encode(f.store.cards), progress = try encode(f.store.progress), history = try encode(f.store.history)
        let before = try await f.store.storage.packageBytes(bookID: p.book.id)
        await f.store.storage.setFault(.deletion)
        let failed = await f.store.offload(p.book); XCTAssertFalse(failed)
        let afterFailure = try await awaitBytes(f, p.book.id); XCTAssertEqual(afterFailure, before)
        await f.store.storage.setFault(nil)
        let offloaded = await f.store.offload(p.book); XCTAssertTrue(offloaded)
        let after = try await f.store.storage.packageBytes(bookID: p.book.id); XCTAssertEqual(after, 0)
        XCTAssertEqual(try encode(f.store.cards), cards); XCTAssertEqual(try encode(f.store.progress), progress); XCTAssertEqual(try encode(f.store.history), history)
        try await f.commit(p)
        let reinstalled = try await f.store.storage.packageBytes(bookID: p.book.id)
        XCTAssertEqual(before, reinstalled); XCTAssertEqual(try encode(f.store.cards), cards); XCTAssertEqual(try encode(f.store.progress), progress)
        let reload = LibraryStore(documentsURL: f.directory, defaults: f.defaults, includeDemo: false); await reload.ready()
        XCTAssertNil(reload.errorMessage)
        let restored = try XCTUnwrap(reload.package(for: p.book))
        XCTAssertNoThrow(try AudioPreflight.prepare(lesson: restored.book.lessons[0], assets: restored.audioAssets!))
        let evidence: [String: Any] = ["installedBytes": before, "offloadedBytes": after, "reinstalledBytes": reinstalled,
            "decodedMP3Bytes": PackagedNarrationFixture.tone.count, "cardsSHA256": LibraryDigest.sha256(cards), "progressSHA256": LibraryDigest.sha256(progress), "historySHA256": LibraryDigest.sha256(history), "encoding": record.payloadEncoding!, "fixture": "Synthetic tone, not production narration"]
        let a = XCTAttachment(data: try JSONSerialization.data(withJSONObject: evidence, options: [.sortedKeys, .prettyPrinted]), uniformTypeIdentifier: "public.json")
        a.name = "audio-storage-proof"; a.lifetime = .keepAlways; add(a)
    }
    private func awaitBytes(_ f: CollectionFixture, _ id: String) async throws -> Int { try await f.store.storage.packageBytes(bookID: id) }
}
