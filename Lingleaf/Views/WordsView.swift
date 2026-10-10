import SwiftUI
import LingleafCore

struct WordsView: View {
    @Environment(AppModel.self) private var model
    @State private var showLearned = false

    var body: some View {
        let due = model.library.dueWords().count
        let words = model.state.words.filter { $0.learned == showLearned }
        NavigationStack {
            List {
                Section {
                    // A disabled link would be dimmed below readable contrast, so with
                    // nothing due the row is plain text instead.
                    if due > 0 {
                        NavigationLink {
                            ReviewView()
                        } label: {
                            reviewSummary(due: due)
                        }
                    } else {
                        reviewSummary(due: due)
                    }
                }

                Picker("Filter", selection: $showLearned) {
                    Text("Learning").tag(false)
                    Text("Learned").tag(true)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)

                if words.isEmpty {
                    Text(showLearned ? "No learned words yet." : "No words yet. While reading, tap a word and choose Learn.")
                        .foregroundStyle(Brand.secondaryText)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
                ForEach(words) { word in
                    WordRow(word: word)
                }
            }
            .navigationTitle("Words")
        }
    }

    private func reviewSummary(due: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "rectangle.stack").foregroundStyle(Brand.ink).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Review now").font(.body)
                Group {
                    if due > 0 {
                        Text("\(due) words to review")
                    } else if model.state.words.isEmpty {
                        Text("Save words while you read.")
                    } else {
                        Text("Nothing to review. Come back tomorrow!")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(Brand.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct WordRow: View {
    let word: VocabWord
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(word.word).font(.headline)
                    if !word.phonetic.isEmpty {
                        Text(word.phonetic).font(.caption).foregroundStyle(Brand.secondaryText)
                    }
                }
                if !word.translation.isEmpty { Text(word.translation) }
                if !word.context.isEmpty {
                    Text(word.context).font(.caption).italic().foregroundStyle(Brand.secondaryText).lineLimit(2)
                }
            }
            Spacer()
            Button {
                model.speaker.speak(word.word, rate: model.state.settings.speechRate)
            } label: {
                Label("Listen", systemImage: "speaker.wave.2").labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
        }
        .swipeActions(edge: .leading) {
            Button(word.learned ? "Review again" : "Mark as learned") {
                model.library.setLearned(word.word, !word.learned)
            }
            .tint(word.learned ? .orange : Brand.learned)
        }
        .swipeActions(edge: .trailing) {
            Button("Delete word", role: .destructive) { model.library.deleteWord(word.word) }
        }
        .accessibilityAction(named: Text(word.learned ? "Review again" : "Mark as learned")) {
            model.library.setLearned(word.word, !word.learned)
        }
        .accessibilityAction(named: Text("Delete word")) { model.library.deleteWord(word.word) }
    }
}
