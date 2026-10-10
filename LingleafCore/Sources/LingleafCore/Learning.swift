import Foundation

public struct SrsResult: Equatable, Sendable {
    public let box: Int
    public let nextReview: Date
    public let learned: Bool

    public init(box: Int, nextReview: Date, learned: Bool) {
        self.box = box
        self.nextReview = nextReview
        self.learned = learned
    }
}

/// Minimal Leitner spaced repetition.
public enum Srs {
    /// Days until the next review for each box.
    public static let intervals = [1, 3, 7, 14, 30]

    public static func review(box: Int, correct: Bool, now: Date, calendar: Calendar = .current) -> SrsResult {
        guard correct else { return SrsResult(box: 0, nextReview: now, learned: false) }
        guard box < intervals.count,
              let next = calendar.date(byAdding: .day, value: intervals[box], to: now)
        else { return SrsResult(box: box, nextReview: now, learned: true) }
        return SrsResult(box: box + 1, nextReview: next, learned: false)
    }
}

/// "yyyy-MM-dd" in the given calendar's time zone.
public func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
    let c = calendar.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
}

/// Consecutive days meeting the goal. Today only counts once it's met, so an
/// unfinished today doesn't break yesterday's streak.
public func readingStreak(_ secondsByDay: [String: Int], goalSeconds: Int, today: Date, calendar: Calendar = .current) -> Int {
    func met(_ day: Date) -> Bool { (secondsByDay[dayKey(day, calendar: calendar)] ?? 0) >= goalSeconds }
    func previous(_ day: Date) -> Date { calendar.date(byAdding: .day, value: -1, to: day) ?? day }
    var day = met(today) ? today : previous(today)
    var count = 0
    while met(day) {
        count += 1
        day = previous(day)
    }
    return count
}
