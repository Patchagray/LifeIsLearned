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
    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environmentObject(library).environmentObject(settings).environmentObject(speech)
                .tint(Palette.teal)
        }
    }
}
