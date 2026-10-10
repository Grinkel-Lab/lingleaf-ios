import SwiftUI
import LingleafCore

/// Brand colours: dark-green ink and a highlighter yellow.
enum Brand {
    /// Adapts to dark mode (see AccentColor in the asset catalog).
    static let ink = Color.accentColor
    static let marker = Color(red: 0.96, green: 0.81, blue: 0.29)
    /// Underline of words being learned. The yellow marker is too light on a white page
    /// (≈1.5:1), so light mode uses dark amber #8A6A00; dark mode keeps the marker #F5CF4A.
    static let markerLine = dynamic(light: rgb(0x8A6A00), dark: rgb(0xF5CF4A))
    static let learned = Color(red: 0.16, green: 0.45, blue: 0.31)
    /// Streak text: #A0430A on light backgrounds, #FF8A50 on dark ones (both ≥4.5:1).
    static let streak = dynamic(light: rgb(0xA0430A), dark: rgb(0xFF8A50))
    /// Secondary text darker than the system's, so it passes WCAG AA (≥4.5:1) on list backgrounds.
    static let secondaryText = Color(uiColor: secondaryUIColor)
    static let secondaryUIColor = dynamicUIColor(light: UIColor(white: 0.36, alpha: 1), dark: UIColor(white: 0.74, alpha: 1))

    private static func dynamic(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: dynamicUIColor(light: light, dark: dark))
    }

    private static func dynamicUIColor(light: UIColor, dark: UIColor) -> UIColor {
        UIColor { traits in traits.userInterfaceStyle == .dark ? dark : light }
    }

    private static func rgb(_ hex: UInt32) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

/// List section header with readable contrast.
struct SectionHeader: View {
    let title: LocalizedStringKey

    init(_ title: LocalizedStringKey) { self.title = title }

    var body: some View {
        Text(title).foregroundStyle(Brand.secondaryText)
    }
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
    /// Dark tones only, so the white initial keeps ≥4.5:1 contrast.
    private static let palette: [Color] = [
        Color(red: 0.18, green: 0.42, blue: 0.37), Color(red: 0.24, green: 0.35, blue: 0.50),
        Color(red: 0.55, green: 0.27, blue: 0.07), Color(red: 0.56, green: 0.23, blue: 0.27),
        Color(red: 0.30, green: 0.36, blue: 0.15), Color(red: 0.43, green: 0.30, blue: 0.56),
    ]

    var body: some View {
        let seed = title.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        RoundedRectangle(cornerRadius: 6)
            .fill(Self.palette[seed % Self.palette.count])
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
                    Text(book.author).font(.subheadline).foregroundStyle(Brand.secondaryText).lineLimit(1)
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
    /// The ring grows with Dynamic Type so the minutes inside it keep fitting.
    @ScaledMetric(relativeTo: .title2) private var ringSize: CGFloat = 64

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
                // Hidden from VoiceOver: "N of M min today" below already says it.
                Text("\(minutes)").font(.title2.bold().monospacedDigit())
                    .accessibilityHidden(true)
            }
            .frame(width: ringSize, height: ringSize)
            VStack(alignment: .leading, spacing: 4) {
                Text(fraction >= 1 ? "Today's goal done!" : "Read \(goal) minutes a day").font(.headline)
                Text("\(minutes) of \(goal) min today").foregroundStyle(Brand.secondaryText)
                if streak > 0 {
                    Label("\(streak) days in a row", systemImage: "flame.fill")
                        .font(.subheadline)
                        .foregroundStyle(Brand.streak)
                }
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}
