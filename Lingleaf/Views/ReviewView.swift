import Accessibility
import SwiftUI
import LingleafCore

/// Flashcard review of due words with spaced repetition.
struct ReviewView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var queue: [VocabWord] = []
    @State private var total = 0
    @State private var reviewed = 0
    @State private var revealed = false
    @State private var loaded = false

    var body: some View {
        VStack(spacing: 24) {
            if let word = queue.first {
                ProgressView(value: Double(reviewed), total: Double(max(total, 1)))
                Spacer()
                card(word)
                Spacer()
                HStack(spacing: 12) {
                    Button { answer(correct: false) } label: {
                        Text("Again").frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    Button { answer(correct: true) } label: {
                        Text("I know it").frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .font(.headline)
            } else if loaded {
                ContentUnavailableView {
                    Label("All done!", systemImage: "checkmark.seal.fill")
                } description: {
                    Text("You reviewed \(reviewed) words.")
                } actions: {
                    Button("Done") { dismiss() }.buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !loaded else { return }
            queue = model.library.dueWords()
            total = queue.count
            loaded = true
        }
    }

    private func card(_ word: VocabWord) -> some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Text(word.word).font(.largeTitle.weight(.semibold))
                Button {
                    model.speaker.speak(word.word, rate: model.state.settings.speechRate)
                } label: {
                    Label("Listen", systemImage: "speaker.wave.2.circle.fill").labelStyle(.iconOnly).font(.title)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
            }
            if !word.context.isEmpty {
                Text(word.context).italic().multilineTextAlignment(.center).foregroundStyle(Brand.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if revealed {
                VStack(spacing: 4) {
                    if !word.phonetic.isEmpty { Text(word.phonetic).foregroundStyle(Brand.secondaryText) }
                    if word.translation.isEmpty {
                        Text("No saved translation").font(.title2)
                    } else {
                        Text(word.translation).font(.title2)
                    }
                }
            } else {
                Button {
                    withAnimation { revealed = true }
                    announceMeaning(of: word)
                } label: {
                    // Headline weight keeps the tinted label readable (large-text contrast)
                    // and it wraps instead of clipping at large text sizes.
                    Text("Show meaning")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 20))
    }

    /// The button VoiceOver was on disappears; say what appeared in its place.
    private func announceMeaning(of word: VocabWord) {
        var announcement = AttributedString(
            word.translation.isEmpty ? String(localized: "No saved translation") : word.translation
        )
        // High priority: not cut off by VoiceOver moving focus away from the vanished button.
        announcement.accessibilitySpeechAnnouncementPriority = .high
        AccessibilityNotification.Announcement(announcement).post()
    }

    private func answer(correct: Bool) {
        guard !queue.isEmpty else { return }
        let word = queue.removeFirst()
        if correct {
            reviewed += 1
        } else {
            queue.append(word)
        }
        revealed = false
        model.library.answerReview(word.word, correct: correct)
    }
}
