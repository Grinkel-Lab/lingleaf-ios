import SwiftUI
import LingleafCore

/// A tapped word, ready for the word card.
struct WordSelection: Identifiable {
    let id = UUID()
    /// The word as it appears in the text ("animals").
    let word: String
    let sentence: String
}

struct ReaderView: View {
    let bookID: String

    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @State private var paragraphs: [String]?
    @State private var words: [[WordRange]] = []
    @State private var selection: WordSelection?
    @State private var position: Int?
    @State private var restored = false
    @State private var sessionStart: Date?

    private var book: Book? { model.state.books.first { $0.id == bookID } }

    var body: some View {
        Group {
            if let paragraphs {
                if paragraphs.isEmpty {
                    ContentUnavailableView("This book is empty.", systemImage: "doc.text")
                } else {
                    reader(paragraphs)
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle(book?.title ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .sheet(item: $selection) { selection in
            WordCardView(selection: selection, source: book?.title ?? "")
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .environment(\.openURL, OpenURLAction { url in
            handle(url)
            return .handled
        })
        .task {
            let loaded = model.library.openBook(bookID)
            words = loaded.map(TextTools.wordRanges)
            paragraphs = loaded
        }
        .onAppear { startTimer() }
        .onDisappear {
            stopTimer()
            model.speaker.stop()
            model.library.flush()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { startTimer() } else { stopTimer() }
        }
        .onChange(of: position) { _, newValue in
            if restored, let newValue { model.library.updateProgress(bookID, paragraph: newValue) }
        }
    }

    private func reader(_ paragraphs: [String]) -> some View {
        let fontSize = model.state.settings.fontSize
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: fontSize * 0.9) {
                    ForEach(paragraphs.indices, id: \.self) { index in
                        Text(attributed(index, paragraphs[index]))
                            .font(readingFont(size: fontSize))
                            .lineSpacing(fontSize * 0.35)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .tint(.primary)
                            .id(index)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
            .scrollPosition(id: $position, anchor: .top)
            .safeAreaInset(edge: .top, spacing: 0) {
                ProgressView(value: book?.progress ?? 0)
                    .accessibilityLabel(Text("Reading progress"))
            }
            .onAppear {
                proxy.scrollTo(min(book?.progressParagraph ?? 0, paragraphs.count - 1), anchor: .top)
                Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    restored = true
                }
            }
        }
    }

    /// Every word is a link (`lingleaf://word?p=…&o=…&e=…`); words being learned are underlined in yellow.
    private func attributed(_ index: Int, _ text: String) -> AttributedString {
        var attributed = AttributedString(text)
        for range in words[index] {
            guard let stringRange = Range(range.nsRange, in: text),
                  let attributedRange = Range(stringRange, in: attributed) else { continue }
            var components = URLComponents()
            components.scheme = "lingleaf"
            components.host = "word"
            components.queryItems = [
                URLQueryItem(name: "p", value: String(index)),
                URLQueryItem(name: "o", value: String(range.start)),
                URLQueryItem(name: "e", value: String(range.end)),
            ]
            attributed[attributedRange].link = components.url
            if model.isLearning(String(text[stringRange])) {
                attributed[attributedRange].underlineStyle = Text.LineStyle(pattern: .solid, color: Brand.marker)
                attributed[attributedRange].backgroundColor = Brand.marker.opacity(0.18)
            }
        }
        return attributed
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                if model.speaker.isSpeaking {
                    model.speaker.stop()
                } else if let paragraphs, !paragraphs.isEmpty {
                    let index = min(position ?? book?.progressParagraph ?? 0, paragraphs.count - 1)
                    model.speaker.speak(paragraphs[index], rate: model.state.settings.speechRate)
                }
            } label: {
                if model.speaker.isSpeaking {
                    Label("Stop reading", systemImage: "stop.circle")
                } else {
                    Label("Read aloud", systemImage: "speaker.wave.2")
                }
            }
            Menu {
                Button("Larger text", systemImage: "plus.magnifyingglass") {
                    model.library.updateSettings { $0.fontSize = min($0.fontSize + 2, 34) }
                }
                Button("Smaller text", systemImage: "minus.magnifyingglass") {
                    model.library.updateSettings { $0.fontSize = max($0.fontSize - 2, 14) }
                }
            } label: {
                Label("Text size", systemImage: "textformat.size")
            }
        }
    }

    private func handle(_ url: URL) {
        guard url.scheme == "lingleaf",
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let index = items.first(where: { $0.name == "p" })?.value.flatMap(Int.init),
              let start = items.first(where: { $0.name == "o" })?.value.flatMap(Int.init),
              let end = items.first(where: { $0.name == "e" })?.value.flatMap(Int.init),
              let paragraphs, paragraphs.indices.contains(index)
        else { return }
        let paragraph = paragraphs[index]
        selection = WordSelection(
            word: TextTools.substring(paragraph, WordRange(start, end)),
            sentence: TextTools.sentenceAt(paragraph, start)
        )
    }

    private func startTimer() {
        if sessionStart == nil { sessionStart = .now }
    }

    private func stopTimer() {
        guard let start = sessionStart else { return }
        sessionStart = nil
        model.library.addReadingTime(Int(Date.now.timeIntervalSince(start)))
    }
}
