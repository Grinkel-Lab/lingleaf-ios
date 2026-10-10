import SwiftUI
import LingleafCore

@main
struct LingleafApp: App {
    @State private var model = AppModel.make()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
                .tint(Brand.ink)
                // Lets UI tests and the screenshot tour render dark mode on any simulator.
                .preferredColorScheme(ProcessInfo.processInfo.arguments.contains("-dark-mode") ? .dark : nil)
        }
    }
}

/// App-wide state and services. Views read `state`; mutations go through `library`.
@Observable
@MainActor
final class AppModel {
    private(set) var state: LibraryState
    let library: Library
    let dictionary: DictionaryClient
    let gutenberg: GutenbergClient
    let speaker: Speaker
    /// UI tests replace on-device translation with this function.
    let fakeTranslator: (@Sendable (String) -> String)?

    init(library: Library, http: HttpFetcher, speaker: Speaker, fakeTranslator: (@Sendable (String) -> String)? = nil) {
        self.library = library
        self.dictionary = DictionaryClient(http: http)
        self.gutenberg = GutenbergClient(http: http)
        self.speaker = speaker
        self.fakeTranslator = fakeTranslator
        library.load()
        library.seedIfNeeded(Self.bundledStories)
        self.state = library.state
        library.onChange = { [weak self] newState in
            MainActor.assumeIsolated { self?.state = newState }
        }
    }

    static func make() -> AppModel {
        ProcessInfo.processInfo.arguments.contains("-ui-testing") ? uiTesting() : live()
    }

    private static func live() -> AppModel {
        let support = URL.applicationSupportDirectory.appending(path: "Lingleaf", directoryHint: .isDirectory)
        return AppModel(library: Library(storage: FileStorage(directory: support)), http: URLSessionFetcher(), speaker: Speaker())
    }

    /// Fresh, offline and deterministic: canned dictionary answers and translations.
    private static func uiTesting() -> AppModel {
        let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let http = ClosureFetcher { url in
            if url.contains("gutendex") { return HttpResponse(status: 200, text: fakeCatalog) }
            guard url.contains("dictionaryapi.dev") else { return HttpResponse(status: 404, text: "") }
            let word = url.split(separator: "/").last.map(String.init) ?? ""
            let json = #"[{"word": "\#(word)", "phonetic": "/test/", "meanings": [{"partOfSpeech": "noun", "definitions": [{"definition": "Definition of \#(word)."}]}]}]"#
            return HttpResponse(status: 200, text: json)
        }
        return AppModel(library: Library(storage: FileStorage(directory: dir)), http: http, speaker: Speaker(), fakeTranslator: { "ES: \($0)" })
    }

    /// A small Gutendex answer so Discover has books to show in UI tests.
    private static let fakeCatalog = #"""
    {"results": [
      {"id": 21, "title": "Aesop's Fables", "authors": [{"name": "Aesop"}],
       "formats": {"text/plain; charset=us-ascii": "https://www.gutenberg.org/ebooks/21.txt.utf-8"}},
      {"id": 55, "title": "The Wonderful Wizard of Oz", "authors": [{"name": "Baum, L. Frank"}],
       "formats": {"text/plain; charset=us-ascii": "https://www.gutenberg.org/ebooks/55.txt.utf-8"}},
      {"id": 16, "title": "Peter Pan", "authors": [{"name": "Barrie, J. M."}],
       "formats": {"text/plain; charset=us-ascii": "https://www.gutenberg.org/ebooks/16.txt.utf-8"}}
    ]}
    """#

    private static func bundledStories() -> [BundledStory] {
        [
            ("the-red-boat", "The Red Boat", "A1"),
            ("a-day-at-the-market", "A Day at the Market", "A2"),
            ("the-lighthouse-keeper", "The Lighthouse Keeper", "B1"),
        ].compactMap { resource, title, level in
            guard let url = Bundle.main.url(forResource: resource, withExtension: "txt"),
                  let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
            return BundledStory(title: title, level: level, text: text)
        }
    }

    func isLearning(_ token: String) -> Bool {
        let learning = state.learningWords
        return !learning.isEmpty && !TextTools.matchKeys(token).isDisjoint(with: learning)
    }

    var targetLanguage: String { state.settings.targetLanguage ?? Self.defaultTargetLanguage }

    /// Languages Apple Translation can translate English into.
    static let translationLanguages = [
        "es", "pt", "fr", "it", "de", "nl", "pl", "uk", "ru", "tr", "ar", "hi", "id", "vi", "th", "zh-Hans", "ja", "ko",
    ]

    /// The device language when supported and not English; Spanish otherwise.
    static var defaultTargetLanguage: String {
        let code = Locale.current.language.languageCode?.identifier ?? "es"
        if code == "zh" { return "zh-Hans" }
        return translationLanguages.contains(code) ? code : "es"
    }

    static func languageName(_ code: String) -> String {
        let locale = Locale(identifier: code)
        return locale.localizedString(forIdentifier: code)?.capitalized(with: locale) ?? code
    }
}
