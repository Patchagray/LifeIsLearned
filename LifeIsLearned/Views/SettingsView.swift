import SwiftUI
import AVFoundation
import Combine

@MainActor struct SettingsView: View {
    @EnvironmentObject private var settings: PlaybackSettings
    @Environment(\.dismiss) private var dismiss
    @StateObject private var preview = SpeechPlayer()
    @State private var voices = PlaybackSettings.voices
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Eyebrow(text: "Make yourself comfortable")
                        Text("A voice. A pace.\nA little space to think.").font(.system(.title, design: .serif))
                    }.padding(.vertical, 10)
                }.listRowBackground(Palette.paper)
                Section("Your two voices") {
                    voicePicker("Guide voice", selection: $settings.guideVoiceID)
                    Button("Preview guide") {
                        preview.speak("Welcome. Let's explore one idea, and see what it changes.", role: .guide, settings: settings)
                    }
                    voicePicker("Storyteller voice", selection: $settings.storyVoiceID)
                    Button("Preview storyteller") {
                        preview.speak("Malik and Elena opened the same report. Somehow, they saw different stories.", role: .storyteller, settings: settings)
                    }
                    if preview.isPlaying { Button("Stop preview") { preview.stop() } }
                    Text("Automatic chooses installed English voices by gender and quality. Age and vocal texture need an audition. Enhanced voices may improve the sound; download them in iOS Settings under Accessibility → Read & Speak (or Spoken Content) → Voices → English, then return here.")
                        .font(.footnote).foregroundStyle(Palette.secondary)
                }
                Section("Pacing") {
                    Toggle("Advance screens while listening", isOn: $settings.autoAdvance)
                    Text("Playback stops at the takeaway and questions so you can reflect and answer.").font(.footnote).foregroundStyle(Palette.secondary)
                    Text("Narration speed · \(settings.speed, specifier: "%.2f")×")
                    Slider(value: $settings.speed, in: 0.65...1.2, step: 0.05)
                    Text("Time to reflect · \(settings.pagePause, specifier: "%.1f") sec")
                    Slider(value: $settings.pagePause, in: 0...5, step: 0.5)
                }
                Section("Completion feedback") {
                    Toggle("Completion haptics", isOn: $settings.completionHaptics)
                    Toggle("Completion sound", isOn: $settings.completionSound)
                    Text("A brief accent when you collect a new idea. Sound follows your device’s silent setting.").font(.footnote).foregroundStyle(Palette.secondary)
                }
                Section("Reading") {
                    Text("Base text size · \(Int(settings.textSize)) pt")
                    Slider(value: $settings.textSize, in: 17...28, step: 1)
                    Text("Your device's Dynamic Type settings also apply. Narration follows long pages as you listen.").font(.footnote).foregroundStyle(Palette.secondary)
                }
                if let error = preview.errorMessage { Section("Audio") { Text(error) } }
            }.environment(\.defaultMinListRowHeight, 48).scrollContentBackground(.hidden).background(Palette.paper)
                .foregroundStyle(Palette.ink).tint(Palette.teal)
                .navigationTitle("Read & listen").navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(Palette.paper, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbar { Button("Done") { preview.stop(); dismiss() } }
        }.onDisappear { preview.stop() }
            .onReceive(NotificationCenter.default.publisher(for: AVSpeechSynthesizer.availableVoicesDidChangeNotification)) { _ in
                voices = PlaybackSettings.voices
            }
    }
    private func voicePicker(_ title: String, selection: Binding<String>) -> some View {
        Picker(title, selection: selection) {
            Text("Automatic").tag("")
            if !selection.wrappedValue.isEmpty && !voices.contains(where: { $0.identifier == selection.wrappedValue }) {
                Text("Unavailable · automatic fallback").tag(selection.wrappedValue)
            }
            ForEach(voices, id: \.identifier) { voice in
                Text("\(voice.name) · \(voice.language)\(voice.quality == .premium ? " · premium" : voice.quality == .enhanced ? " · enhanced" : "")")
                    .tag(voice.identifier)
            }
        }
    }
}
