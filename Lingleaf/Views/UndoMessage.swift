import Accessibility
import SwiftUI

/// A short message at the bottom of the screen with an Undo button, e.g.
/// "“beach” saved to Words". It disappears after `seconds` (twice as long with
/// VoiceOver on) and is announced to VoiceOver.
struct UndoMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let seconds: Double
    let undo: () -> Void

    static func == (lhs: UndoMessage, rhs: UndoMessage) -> Bool { lhs.id == rhs.id }
}

extension View {
    /// Shows `message` at the bottom of this view until it times out or Undo is tapped.
    func undoMessage(_ message: Binding<UndoMessage?>) -> some View {
        modifier(UndoMessageModifier(message: message))
    }
}

private struct UndoMessageModifier: ViewModifier {
    @Binding var message: UndoMessage?
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if let current = message {
                    UndoBanner(message: current) {
                        current.undo()
                        message = nil
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.default, value: message?.id)
            .task(id: message?.id) {
                guard let current = message else { return }
                var announcement = AttributedString(current.text)
                // High priority: not cut off by VoiceOver moving focus as a sheet closes.
                announcement.accessibilitySpeechAnnouncementPriority = .high
                AccessibilityNotification.Announcement(announcement).post()
                let seconds = voiceOver ? current.seconds * 2 : current.seconds
                try? await Task.sleep(for: .seconds(seconds))
                // A newer message (or Undo) cancels this task; only time out this one.
                if !Task.isCancelled, message?.id == current.id { message = nil }
            }
    }
}

/// Inverted colours (label on background), so text and button keep the system's
/// highest contrast in light and dark mode.
private struct UndoBanner: View {
    let message: UndoMessage
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(message.text)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onUndo) {
                Text("Undo")
                    .font(.headline)
                    .underline()
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(Color(uiColor: .systemBackground))
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .padding(.vertical, 4)
        .background(Color(uiColor: .label), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}
