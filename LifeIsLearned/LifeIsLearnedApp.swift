import SwiftUI

@main @MainActor struct LifeIsLearnedApp: App {
    @StateObject private var library: LibraryStore
    @StateObject private var settings: PlaybackSettings
    @StateObject private var speech = SpeechPlayer()
    init() {
        #if DEBUG
        if let id = ProcessInfo.processInfo.environment["LIL_UI_TEST_RUN_ID"], UUID(uuidString: id) != nil,
           let defaults = UserDefaults(suiteName: "LifeIsLearned.UITests." + id) {
            _library = StateObject(wrappedValue: LibraryStore(documentsURL: FileManager.default.temporaryDirectory.appendingPathComponent("UI-" + id), defaults: defaults))
            _settings = StateObject(wrappedValue: PlaybackSettings(defaults: defaults))
            return
        }
        #endif
        _library = StateObject(wrappedValue: LibraryStore())
        _settings = StateObject(wrappedValue: PlaybackSettings())
    }
    @MainActor private func prepareTestCards() async {
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        if let id = environment["LIL_UI_TEST_RUN_ID"], UUID(uuidString: id) != nil,
           environment["LIL_IDEA_CARD_FIXTURE"] == "1" {
            do { try await IdeaCardFixture.install(in: library) }
            catch { library.errorMessage = "UI fixture failed: \(error.localizedDescription)" }
        }
        #endif
    }
    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environmentObject(library).environmentObject(settings).environmentObject(speech)
                .tint(Palette.teal)
                .task { await prepareTestCards() }
        }
    }
}
