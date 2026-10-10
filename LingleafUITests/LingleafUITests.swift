import XCTest

/// Runs the real app in `-ui-testing` mode: fresh storage, canned dictionary
/// answers and fake translations, so results don't depend on the network.
final class LingleafUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
    }

    func testTapAWordSeeItsCardAndLearnIt() {
        button(startingWith: "The Red Boat").tap()

        let word = app.links["beach"].firstMatch
        XCTAssertTrue(word.waitForExistence(timeout: 10), "words in the reader are tappable links")
        word.tap()

        XCTAssertTrue(app.staticTexts["ES: beach"].waitForExistence(timeout: 10), "the card shows the translation")
        XCTAssertTrue(app.staticTexts["/test/"].exists, "the card shows the IPA")
        app.buttons["Learn"].tap()

        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.tabBars.buttons["Words"].tap()
        XCTAssertTrue(app.staticTexts["beach"].waitForExistence(timeout: 5), "the word was saved")
        XCTAssertTrue(app.staticTexts["ES: beach"].exists)
    }

    func testReviewAWord() {
        button(startingWith: "The Red Boat").tap()
        let word = app.links["sea"].firstMatch
        XCTAssertTrue(word.waitForExistence(timeout: 10))
        word.tap()
        XCTAssertTrue(app.buttons["Learn"].waitForExistence(timeout: 10))
        app.buttons["Learn"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.tabBars.buttons["Words"].tap()
        button(startingWith: "Review now").tap()
        app.buttons["Show meaning"].tap()
        XCTAssertTrue(app.staticTexts["ES: sea"].exists)
        app.buttons["I know it"].tap()
        XCTAssertTrue(app.staticTexts["All done!"].waitForExistence(timeout: 5))
    }

    /// Apple's automated accessibility audit (contrast, Dynamic Type, labels,
    /// hit areas…) on every main screen. Collects every issue before failing,
    /// so one CI run shows the whole list.
    func testAccessibilityAudit() throws {
        var issues: [String] = []
        func audit(_ screen: String) throws {
            try app.performAccessibilityAudit { issue in
                let element = issue.element.map { "\($0.elementType) '\($0.label)'" } ?? "screen"
                issues.append("[\(screen)] \(issue.compactDescription) — \(element)")
                return true
            }
        }
        for tab in ["Library", "Discover", "Words", "Settings"] {
            app.tabBars.buttons[tab].tap()
            try audit(tab)
        }
        app.tabBars.buttons["Library"].tap()
        button(startingWith: "The Red Boat").tap()
        XCTAssertTrue(app.links["beach"].firstMatch.waitForExistence(timeout: 10))
        try audit("Reader")
        app.links["beach"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Learn"].waitForExistence(timeout: 10))
        try audit("Word card")
        XCTAssertTrue(issues.isEmpty, "Accessibility issues:\n" + issues.joined(separator: "\n"))
    }

    /// Rows combine their texts into one label ("The Red Boat, Level A1, …").
    private func button(startingWith prefix: String) -> XCUIElement {
        let element = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: 10), "button starting with \(prefix)")
        return element
    }
}
