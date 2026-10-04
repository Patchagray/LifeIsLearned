import SwiftUI

@main @MainActor struct LifeIsLearnedApp: App {
    @StateObject private var library = LibraryStore()
    @StateObject private var settings = PlaybackSettings()
    @StateObject private var speech = SpeechPlayer()
    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environmentObject(library).environmentObject(settings).environmentObject(speech)
                .tint(Palette.teal)
        }
    }
}
