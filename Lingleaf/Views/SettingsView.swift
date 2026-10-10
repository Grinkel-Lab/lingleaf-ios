import SwiftUI
import LingleafCore

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    private static let repositoryURL = URL(string: "https://github.com/erobinsonc/lingleaf-ios")!

    var body: some View {
        let settings = model.state.settings
        NavigationStack {
            Form {
                Section(header: SectionHeader("Daily goal")) {
                    Stepper(
                        "\(settings.dailyGoalMinutes) minutes a day",
                        value: binding(\.dailyGoalMinutes),
                        in: 5...60,
                        step: 5
                    )
                }

                Section(header: SectionHeader("Reading")) {
                    Slider(value: binding(\.fontSize), in: 14...34, step: 2) {
                        Text("Text size")
                    } minimumValueLabel: {
                        Image(systemName: "textformat.size.smaller").accessibilityHidden(true)
                    } maximumValueLabel: {
                        Image(systemName: "textformat.size.larger").accessibilityHidden(true)
                    }
                    Text(verbatim: "All animals are equal.").font(readingFont(size: settings.fontSize))
                }

                Section {
                    Slider(value: binding(\.speechRate), in: 0.3...0.6) {
                        Text("Speech speed")
                    } minimumValueLabel: {
                        Image(systemName: "tortoise").accessibilityHidden(true)
                    } maximumValueLabel: {
                        Image(systemName: "hare").accessibilityHidden(true)
                    }
                    Button("Test the voice", systemImage: "speaker.wave.2") {
                        model.speaker.speak("Reading ten minutes a day makes a big difference.", rate: settings.speechRate)
                    }
                } header: {
                    Text("Voice").foregroundStyle(Brand.secondaryText)
                }

                Section {
                    Picker("Translate to", selection: Binding(
                        get: { model.targetLanguage },
                        set: { code in model.library.updateSettings { $0.targetLanguage = code } }
                    )) {
                        ForEach(AppModel.translationLanguages, id: \.self) { code in
                            Text(AppModel.languageName(code)).tag(code)
                        }
                    }
                } header: {
                    Text("Translation").foregroundStyle(Brand.secondaryText)
                } footer: {
                    Text("Translation happens on your iPhone. The first time, iOS asks to download the language; after that it works offline.")
                        .foregroundStyle(Brand.secondaryText)
                }

                Section(header: SectionHeader("About")) {
                    Link(destination: Self.repositoryURL) {
                        Label("Source code (open source, MIT)", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                    Text("Books: Project Gutenberg (public domain). Definitions: dictionaryapi.dev. No accounts, no ads, no tracking.")
                        .font(.footnote)
                        .foregroundStyle(Brand.secondaryText)
                }
            }
            .navigationTitle("Settings")
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<LingleafCore.Settings, Value>) -> Binding<Value> {
        Binding(
            get: { model.state.settings[keyPath: keyPath] },
            set: { value in model.library.updateSettings { $0[keyPath: keyPath] = value } }
        )
    }
}
