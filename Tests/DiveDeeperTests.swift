import XCTest
@testable import LifeIsLearned

@MainActor final class DiveDeeperTests: XCTestCase {
    private func content(_ package: LessonPackage) -> DiveDeeperContent {
        DiveDeeperContent(title: "A closer look", summary: "Synthetic verification content.", sections: [
            DiveDeeperSection(id: "example", title: "A worked example", text: "Synthetic fixture text for an optional section.", sourceIDs: [package.book.sources[0].id])])
    }
    func testLegacyDecodeFingerprintAndCoreTimingRemainUnchanged() async throws {
        let f = try await CollectionFixture.make(); addTeardownBlock { await f.cleanup() }
        XCTAssertNil(f.package.book.lessons[0].diveDeeper)
        XCTAssertEqual(try f.package.fingerprint(f.package.book.lessons[0]), "8e7945c26ea520cc2b2da9e87b5995e01fde0a6ecdb6dd8ecc5138f21917a445")
        let before = LessonTiming(lesson: f.package.book.lessons[0])
        var package = f.package; package.book.lessons[0].diveDeeper = content(package)
        package.book.lessons[0].diveDeeper!.sections[0].text = String(repeating: "Deeper reading. ", count: 2000)
        let after = LessonTiming(lesson: package.book.lessons[0])
        XCTAssertEqual(before.totalSeconds, after.totalSeconds); XCTAssertEqual(before.spokenWords, after.spokenWords)
        XCTAssertEqual(before.segments.map(\.text), after.segments.map(\.text))
        _ = try package.validated()
    }
    func testSourceValidationAndDeeperChangesRequireRevisionBump() async throws {
        let f = try await CollectionFixture.make(); addTeardownBlock { await f.cleanup() }
        var package = f.package; package.collectionRevision = 2; package.book.lessons[0].diveDeeper = content(package)
        do { _ = try await f.store.storage.review(package: package, catalog: f.store.catalog); XCTFail("Missing idea revision accepted") } catch { }
        package.book.lessons[0].revision += 1; package.manifest = package.book.lessons.map { IdeaManifestEntry(id: $0.id, revision: $0.revision) }
        try await f.commit(package); XCTAssertNil(f.store.errorMessage)
        let initial = try package.fingerprint(package.book.lessons[0])
        package.book.lessons[0].diveDeeper!.sections[0].text += " Revised section."
        XCTAssertNotEqual(initial, try package.fingerprint(package.book.lessons[0]))
        package.book.lessons[0].diveDeeper!.sections[0].sourceIDs = []
        XCTAssertThrowsError(try package.validated())
        package.book.lessons[0].diveDeeper!.sections[0].sourceIDs = ["unknown"]
        XCTAssertThrowsError(try package.validated())
        package.book.lessons[0].diveDeeper = content(package)
        var source = package.book.sources[0]; source.id = "deeper-only"; package.book.sources.append(source)
        package.book.lessons[0].diveDeeper!.sections[0].sourceIDs = [source.id]
        let deeperOnly = try package.fingerprint(package.book.lessons[0])
        package.book.sources[package.book.sources.count - 1].scope += " Changed source scope."
        XCTAssertNotEqual(deeperOnly, try package.fingerprint(package.book.lessons[0]))
    }
    func testEarnedAccessOffloadReinstallAndUpdatedRevisionLock() async throws {
        let f = try await CollectionFixture.make(empty: true); addTeardownBlock { await f.cleanup() }
        var package = f.package; package.book.lessons[0].diveDeeper = content(package)
        try await f.commit(package)
        let lesson = package.book.lessons[0], book = package.book
        let session = LessonSession(book: book, lesson: lesson, store: f.store, speech: FakeNarrator(), settings: PlaybackSettings(defaults: f.defaults), practiceOnly: true)
        XCTAssertFalse(session.canDiveDeeper)
        for _ in lesson.questions { session.answer(session.question.correctChoiceID); session.nextQuestion() }
        XCTAssertTrue(session.canDiveDeeper)
        let card = try XCTUnwrap(f.store.cards.values.first)
        XCTAssertEqual(card.snapshot.hasDiveDeeper, true); XCTAssertEqual(f.store.deeperAccess(card), .available)
        XCTAssertNotNil(f.store.deeperDestination(card))
        let success = await f.store.offload(book); XCTAssertTrue(success)
        XCTAssertEqual(f.store.deeperAccess(card), .restoreManual); XCTAssertNil(f.store.deeperDestination(card))
        XCTAssertEqual(f.store.cards[card.id], card)
        var review = try await f.store.storage.review(package: package, catalog: f.store.catalog)
        review.source = BookSourceRecord(kind: .remoteCatalog, catalogID: "catalog-001", catalogURL: URL(string: "https://fixture.invalid/catalog.json"))
        await f.store.commitImport(review)
        XCTAssertEqual(f.store.deeperAccess(card), .available); XCTAssertEqual(f.store.cards.count, 1)
        let offloaded = await f.store.offload(book); XCTAssertTrue(offloaded)
        XCTAssertEqual(f.store.deeperAccess(card), .restoreRemote)
        package.collectionRevision = 2; package.book.lessons[0].revision += 1
        package.book.lessons[0].diveDeeper!.sections[0].text += " New revision."
        package.manifest = package.book.lessons.map { IdeaManifestEntry(id: $0.id, revision: $0.revision) }
        try await f.commit(package)
        XCTAssertEqual(f.store.deeperAccess(card), .locked); XCTAssertNil(f.store.deeperDestination(card))
        XCTAssertEqual(f.store.cards[card.id], card, "Uncompleted update does not rewrite earned snapshot")
    }
}
