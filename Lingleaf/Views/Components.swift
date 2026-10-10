import SwiftUI
import LingleafCore

/// Brand colours: dark-green ink and a highlighter yellow.
enum Brand {
    /// Adapts to dark mode (see AccentColor in the asset catalog).
    static let ink = Color.accentColor
    static let marker = Color(red: 0.96, green: 0.81, blue: 0.29)
    static let learned = Color(red: 0.16, green: 0.45, blue: 0.31)
}

/// Reading font: Georgia, scaled with Dynamic Type.
func readingFont(size: Double) -> Font {
    .custom("Georgia", size: size, relativeTo: .body)
}

struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let due = model.library.dueWords().count
        TabView {
            LibraryView()
                .tabItem { Label("Library", systemImage: "books.vertical") }
            DiscoverView()
                .tabItem { Label("Discover", systemImage: "magnifyingglass") }
            WordsView()
                .tabItem { Label("Words", systemImage: "rectangle.stack") }
                .badge(due)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

struct BookCover: View {
    let title: String
    private static let palette: [Color] = [Brand.ink, .indigo, .orange, .pink, .green, .brown, .purple]

    var body: some View {
        let seed = title.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        RoundedRectangle(cornerRadius: 6)
            .fill(Self.palette[seed % Self.palette.count].gradient)
            .frame(width: 44, height: 62)
            .overlay(Text(String(title.prefix(1))).font(.title2.bold()).foregroundStyle(.white))
            .accessibilityHidden(true)
    }
}

struct LevelBadge: View {
    let level: String

    var body: some View {
        Text(level)
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Brand.ink.opacity(0.15), in: Capsule())
            .foregroundStyle(Brand.ink)
            .accessibilityLabel(Text("Level \(level)"))
    }
}

struct BookRow: View {
    let book: Book

    var body: some View {
        HStack(spacing: 14) {
            BookCover(title: book.title)
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title).font(.headline).lineLimit(2)
                HStack(spacing: 6) {
                    if let level = book.level { LevelBadge(level: level) }
                    Text(book.author).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                }
                if book.progress > 0 {
                    ProgressView(value: book.progress).padding(.top, 2)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

struct DailyGoalCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let goal = model.state.settings.dailyGoalMinutes
        let seconds = model.state.readingLog.isEmpty ? 0 : model.library.secondsToday()
        let streak = model.state.readingLog.isEmpty ? 0 : model.library.streak()
        let minutes = seconds / 60
        let fraction = min(1, Double(seconds) / Double(max(goal, 1) * 60))
        HStack(spacing: 16) {
            ZStack {
                Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(Brand.ink, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(minutes)").font(.title2.bold().monospacedDigit())
            }
            .frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 4) {
                Text(fraction >= 1 ? "Today's goal done!" : "Read \(goal) minutes a day").font(.headline)
                Text("\(minutes) of \(goal) min today").foregroundStyle(.secondary)
                if streak > 0 {
                    Label("\(streak) days in a row", systemImage: "flame.fill")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}
