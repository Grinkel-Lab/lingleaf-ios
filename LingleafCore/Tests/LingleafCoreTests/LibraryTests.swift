import XCTest
@testable import LingleafCore

final class MemoryStorage: Storage {
    var files: [String: String] = [:]

    func read(_ name: String) -> String? { files[name] }
    func write(_ name: String, _ content: String) { files[name] = content }
    func delete(_ name: String) { files[name] = nil }
}

final class LibraryTests: XCTestCase {
    private let storage = MemoryStorage()
    private var now = ISO8601DateFormatter().date(from: "2026-10-09T09:00:00Z")!
    private let stories = [
        BundledStory(title: "The Red Boat", level: "A1", text: "All animals are equal.\n\nThe end."),
        BundledStory(title: "A Day at the Market", level: "A2", text: "A short story."),
    ]
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func library() -> Library {
        let library = Library(storage: storage, now: { [unowned self] in self.now }, calendar: calendar)
        library.load()
        return library
    }

    func testKeepsACopyOfAFileThatCannotBeRead() {
        storage.files["words.json"] = "not json"
        let library = library()
        XCTAssertTrue(library.state.words.isEmpty)
        XCTAssertEqual(storage.files["words.json.corrupt"], "not json")
    }

    func testSeedsBundledStoriesOnce() {
        let library = library()
        library.seedIfNeeded { stories }
        library.seedIfNeeded { stories }
        XCTAssertEqual(library.state.books.map(\.title), ["The Red Boat", "A Day at the Market"])
        XCTAssertEqual(library.state.books.first?.level, "A1")
        XCTAssertEqual(library.state.books.first?.paragraphCount, 2)

        let reloaded = self.library()
        reloaded.seedIfNeeded { stories }
        XCTAssertEqual(reloaded.state.books.count, 2, "books persist and are not seeded twice")
    }

    func testOpenProgressAndDeleteABook() {
        let library = library()
        let book = library.addBook(title: "Alice", author: "Lewis Carroll", text: "One.\n\nTwo.\n\nThree.", level: "B2", gutenbergID: 11)
        XCTAssertEqual(library.openBook(book.id), ["One.", "Two.", "Three."])
        XCTAssertEqual(library.state.lastOpened?.id, book.id)

        library.updateProgress(book.id, paragraph: 2)
        library.flush()
        XCTAssertEqual(self.library().state.books.first?.progress, 1)

        library.deleteBook(book.id)
        XCTAssertTrue(library.state.books.isEmpty)
        XCTAssertNil(storage.read(book.fileName))
        XCTAssertEqual(library.openBook("missing"), [])
        library.deleteBook("missing")
    }

    func testLearningWordsHighlightInflectedFormsAndSurviveRestart() {
        let library = library()
        var changes = 0
        library.onChange = { _ in changes += 1 }
        library.saveWord("Animal", learned: false, translation: "animal", context: "All animals are equal.", source: "The Red Boat")
        XCTAssertGreaterThan(changes, 0)
        XCTAssertTrue(library.isLearning("animals"))
        XCTAssertFalse(library.isLearning("equal"))
        XCTAssertEqual(library.dueWords().map(\.word), ["animal"])

        library.saveWord("animal", learned: true, translation: "")
        XCTAssertFalse(library.isLearning("animals"))
        let saved = self.library().state.word("animal")
        XCTAssertEqual(saved?.learned, true)
        XCTAssertEqual(saved?.translation, "animal", "blank values don't overwrite saved ones")
        XCTAssertEqual(saved?.context, "All animals are equal.")
    }

    func testReviewAnswersScheduleTheNextReview() {
        let library = library()
        library.saveWord("equal", learned: false)
        library.answerReview("equal", correct: true)
        XCTAssertTrue(library.dueWords().isEmpty)
        now = now.addingTimeInterval(86_400)
        XCTAssertEqual(library.dueWords().first?.box, 1)

        library.answerReview("equal", correct: false)
        XCTAssertEqual(library.dueWords().first?.box, 0)
        library.answerReview("missing", correct: true)
    }

    func testMarkingLearnedAndBackAndDeletingWords() {
        let library = library()
        library.saveWord("bay", learned: false)
        library.setLearned("bay", true)
        XCTAssertTrue(library.dueWords().isEmpty)
        library.setLearned("bay", false)
        XCTAssertEqual(library.dueWords().map(\.word), ["bay"])
        library.setLearned("missing", true)
        library.deleteWord("bay")
        XCTAssertTrue(library.state.words.isEmpty)
    }

    func testReadingTimeFeedsTodayAndTheStreak() {
        let library = library()
        library.addReadingTime(240)
        XCTAssertEqual(library.secondsToday(), 240)
        XCTAssertEqual(library.streak(), 0)
        library.addReadingTime(360)
        XCTAssertEqual(library.streak(), 1)
        library.addReadingTime(0)
        library.addReadingTime(99_999)
        XCTAssertEqual(self.library().secondsToday(), 600 + 3600, "a session counts at most one hour")
    }

    func testSettingsPersistAndCorruptFilesFallBackToDefaults() {
        let library = library()
        library.updateSettings {
            $0.dailyGoalMinutes = 20
            $0.targetLanguage = "pt"
        }
        XCTAssertEqual(self.library().state.settings.dailyGoalMinutes, 20)

        storage.files["settings.json"] = "{broken"
        XCTAssertEqual(self.library().state.settings, Settings())
        storage.files["settings.json"] = "{}"
        XCTAssertEqual(self.library().state.settings, Settings())
    }

    func testFileStorageRoundTrip() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let files = FileStorage(directory: dir)
        XCTAssertNil(files.read("a.txt"))
        files.write("a.txt", "hello")
        XCTAssertEqual(files.read("a.txt"), "hello")
        files.delete("a.txt")
        XCTAssertNil(files.read("a.txt"))
    }
}
