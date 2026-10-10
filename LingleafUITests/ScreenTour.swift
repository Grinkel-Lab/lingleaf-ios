import XCTest

/// Walks every main screen and attaches a screenshot of each one, in light
/// and dark mode and in English and Spanish. CI exports the attachments and
/// publishes them to the `screenshots` branch, so the app can be looked at
/// without running it. The tour asserts little on purpose: its job is to
/// capture what is on screen, the other UI tests check behaviour.
final class ScreenTour: XCTestCase {
    private struct Labels {
        let language: String
        let learn: String
        let reviewNow: String
        let showMeaning: String
    }

    private static let english = Labels(language: "en", learn: "Learn", reviewNow: "Review now", showMeaning: "Show meaning")
    private static let spanish = Labels(language: "es", learn: "Aprender", reviewNow: "Repasar ahora", showMeaning: "Mostrar significado")

    private var app: XCUIApplication!
    private var prefix = ""

    override func setUp() {
        continueAfterFailure = true
    }

    override func tearDown() {
        XCUIDevice.shared.appearance = .light
    }

    func testTourEnglishLight() { tour(Self.english, dark: false) }
    func testTourEnglishDark() { tour(Self.english, dark: true) }
    func testTourSpanishLight() { tour(Self.spanish, dark: false) }

    private func tour(_ labels: Labels, dark: Bool) {
        XCUIDevice.shared.appearance = dark ? .dark : .light
        prefix = "\(labels.language)-\(dark ? "dark" : "light")"
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-AppleLanguages", "(\(labels.language))", "-AppleLocale", labels.language]
            + (dark ? ["-dark-mode"] : [])
        app.launch()

        let book = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "The Red Boat")).firstMatch
        _ = book.waitForExistence(timeout: 10)
        snap("01-library")

        book.tap()
        let word = app.links["beach"].firstMatch
        _ = word.waitForExistence(timeout: 10)
        snap("02-reader")

        word.tap()
        _ = app.buttons[labels.learn].waitForExistence(timeout: 10)
        snap("03-word-card")
        app.buttons[labels.learn].tap()
        _ = word.waitForExistence(timeout: 5)
        snap("04-reader-with-marked-word")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        tab(2)
        snap("05-words")
        let review = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", labels.reviewNow)).firstMatch
        if review.waitForExistence(timeout: 5) {
            review.tap()
            snap("06-review")
            app.buttons[labels.showMeaning].tap()
            snap("07-review-meaning")
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }

        tab(1)
        _ = app.buttons["level-filter-all"].waitForExistence(timeout: 10)
        snap("08-discover")
        app.buttons["level-filter-B1"].tap()
        snap("09-discover-level-filter")
        tab(3)
        snap("10-settings")
        app.terminate()
    }

    private func tab(_ index: Int) {
        app.tabBars.buttons.element(boundBy: index).tap()
    }

    private func snap(_ name: String) {
        // Lets the screen settle (sheets, translations) before capturing.
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "\(prefix)-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
