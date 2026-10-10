import SwiftUI
import Translation
import LingleafCore

/// The card shown when a word is tapped: pronunciation, translation,
/// definition, the sentence in context, and Learned / Learn.
struct WordCardView: View {
    let selection: WordSelection
    let source: String

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var entry: DictionaryEntry?
    @State private var entryLoaded = false
    @State private var translation: String?
    @State private var sentenceTranslation: String?
    @State private var translationFailed = false
    @State private var configuration: TranslationSession.Configuration?

    /// The dictionary's base form ("animal") when it differs from the tapped word ("animals").
    private var headword: String {
        guard let base = entry?.word, base != TextTools.normalize(selection.word) else { return selection.word }
        return base
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 10) {
                    header
                    translationView
                    if let definition = entry?.definition {
                        Text("\(Text(entry?.partOfSpeech ?? "").italic()) · \(definition)")
                            .font(.footnote)
                            .foregroundStyle(Brand.secondaryText)
                            .multilineTextAlignment(.center)
                    } else if entryLoaded {
                        Text("No definition available.").font(.footnote).foregroundStyle(Brand.secondaryText)
                    }
                    Divider().padding(.vertical, 4)
                    contextView
                    if let saved = model.state.word(headword) {
                        Label(saved.learned ? "You marked it as learned" : "Already in your words", systemImage: "checkmark.circle")
                            .font(.caption)
                            .foregroundStyle(Brand.secondaryText)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 12)
            }
            HStack(spacing: 0) {
                actionButton("Learned", background: Brand.learned, foreground: .white) { save(learned: true) }
                actionButton("Learn", background: Brand.marker, foreground: .black) { save(learned: false) }
            }
        }
        .translationTask(configuration) { session in
            await translate(using: session)
        }
        .task { await load() }
    }

    private var header: some View {
        VStack(spacing: 4) {
            HStack(spacing: 10) {
                Button {
                    model.speaker.speak(headword, rate: model.state.settings.speechRate)
                } label: {
                    Label("Listen", systemImage: "speaker.wave.2.circle.fill")
                        .labelStyle(.iconOnly)
                        .font(.largeTitle)
                }
                Text(headword).font(.largeTitle.weight(.semibold))
            }
            if let phonetic = entry?.phonetic {
                Text(phonetic).font(.title3).foregroundStyle(Brand.secondaryText)
            }
            if headword != selection.word {
                Text("In the text: \(selection.word)").font(.caption).foregroundStyle(Brand.secondaryText)
            }
        }
    }

    @ViewBuilder
    private var translationView: some View {
        if let translation {
            Text(translation).font(.title2).multilineTextAlignment(.center)
        } else if translationFailed {
            Text("Translation unavailable. Connect to the internet once to download the language.")
                .font(.footnote)
                .foregroundStyle(Brand.secondaryText)
                .multilineTextAlignment(.center)
        } else {
            ProgressView()
        }
    }

    private var contextView: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(selection.sentence).font(readingFont(size: 17)).italic()
                    .fixedSize(horizontal: false, vertical: true)
                if let sentenceTranslation {
                    Text(sentenceTranslation).font(.callout).foregroundStyle(Brand.secondaryText)
                }
            }
            Spacer(minLength: 8)
            Button {
                model.speaker.speak(selection.sentence, rate: model.state.settings.speechRate)
            } label: {
                Label("Listen to the sentence", systemImage: "speaker.wave.1")
                    .labelStyle(.iconOnly)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func actionButton(
        _ title: LocalizedStringKey, background: Color, foreground: Color, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity, minHeight: 58)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // The button reaches into the bottom safe area; colour all of it so the
        // label is always measured against its own background.
        .background(background.ignoresSafeArea(edges: .bottom))
    }

    private func load() async {
        entry = await model.dictionary.lookup(selection.word)
        entryLoaded = true
        if let fake = model.fakeTranslator {
            do {
                translation = try fake(headword)
                sentenceTranslation = try fake(selection.sentence)
            } catch {
                translationFailed = true
            }
        } else {
            configuration = TranslationSession.Configuration(
                source: Locale.Language(identifier: "en"),
                target: model.targetLanguage.map { Locale.Language(identifier: $0) }
            )
        }
    }

    private func translate(using session: TranslationSession) async {
        do {
            let responses = try await session.translations(from: [
                TranslationSession.Request(sourceText: headword, clientIdentifier: "word"),
                TranslationSession.Request(sourceText: selection.sentence, clientIdentifier: "sentence"),
            ])
            for response in responses {
                if response.clientIdentifier == "word" {
                    translation = response.targetText
                } else {
                    sentenceTranslation = response.targetText
                }
            }
        } catch {
            translationFailed = true
        }
    }

    private func save(learned: Bool) {
        model.library.saveWord(
            headword,
            learned: learned,
            translation: translation,
            phonetic: entry?.phonetic,
            context: selection.sentence,
            source: source
        )
        dismiss()
    }
}
