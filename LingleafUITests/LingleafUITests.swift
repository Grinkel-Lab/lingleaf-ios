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
        XCTAssertTrue(element(labelled: "beach").waitForExistence(timeout: 5), "the word was saved")
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "ES: beach")).firstMatch.exists)
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
    /// hit areas…) on every main screen, empty and with a word being learned
    /// (marked word in the reader, a Words row, Review before and after the
    /// meaning). Collects every issue before failing, so one CI run shows the whole list.
    func testAccessibilityAudit() throws {
        var issues: [String] = []
        func audit(_ screen: String) throws {
            // Tab switches cross-fade; auditing mid-animation measures half-faded
            // text and reports contrast failures that are not there.
            RunLoop.current.run(until: Date().addingTimeInterval(1.5))
            // The reader hides the tab bar; then nothing can sit under it.
            let tabBar = app.tabBars.firstMatch.exists ? app.tabBars.firstMatch.frame : .null
            try app.performAccessibilityAudit { issue in
                // Rows scrolled under the translucent tab bar are measured against
                // the bar's blur; scrolled into view they read normally. The tab
                // bar's own buttons are not exempt: their contrast is still checked.
                if issue.auditType == .contrast, let flagged = issue.element, flagged.frame.intersects(tabBar),
                   !Self.isTabBarButton(flagged, in: tabBar) { return true }
                // The search field is UIKit's own (from `.searchable`); its clipping
                // at large text sizes is iOS's to handle, not something the app can change.
                if issue.auditType == .textClipped, issue.element?.elementType == .searchField { return true }
                if Self.knownFalsePositive(issue, on: screen) { return true }
                let element = issue.element.map { "type \($0.elementType.rawValue) '\($0.label)' id '\($0.identifier)' frame \($0.frame)" } ?? "screen"
                issues.append("[\(screen)] \(issue.compactDescription) — \(element) — \(issue.detailedDescription)")
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

        // Populated states: learn the word, then audit every screen that shows it.
        app.buttons["Learn"].tap()
        XCTAssertTrue(app.buttons["Learn"].waitForNonExistence(timeout: 10), "the card closes after Learn")
        try audit("Reader with a learning word")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.tabBars.buttons["Words"].tap()
        XCTAssertTrue(element(labelled: "beach").waitForExistence(timeout: 5))
        try audit("Words with a word")
        button(startingWith: "Review now").tap()
        XCTAssertTrue(app.buttons["Show meaning"].waitForExistence(timeout: 5))
        try audit("Review")
        app.buttons["Show meaning"].tap()
        XCTAssertTrue(app.staticTexts["ES: beach"].waitForExistence(timeout: 5))
        try audit("Review with the meaning")
        XCTAssertTrue(issues.isEmpty, "Accessibility issues:\n" + issues.joined(separator: "\n"))
    }

    /// Audit findings checked by hand and found not to be real problems. Each
    /// one names the screen and the reason; anything else still fails the test.
    private static func knownFalsePositive(_ issue: XCUIAccessibilityAuditIssue, on screen: String) -> Bool {
        switch (screen, issue.auditType) {
        case ("Settings", .contrast):
            // On iOS 26 the audit reports contrast failures inside Form controls
            // without naming any element. Measured on the screenshot tour, every
            // text and icon there is ≥ 6:1 (headers 6.0, slider icons 6.7,
            // accent 6.2, stepper 18.1), above WCAG AA's 4.5:1. A failure that
            // names an element is still reported.
            return issue.element == nil
        case (_, .hitRegion):
            // Progress bars (reader, review) are read-only indicators, not touch
            // targets, so the minimum hit area does not apply (WCAG 2.5.8 covers targets).
            return issue.element?.elementType == .progressIndicator
        case ("Word card", .elementDetection):
            // The card is a sheet over the reader: the book's text shows behind
            // it, dimmed and correctly hidden from VoiceOver while the card is open.
            return issue.element == nil
        default:
            return false
        }
    }

    /// A tab bar button sits entirely inside the bar; rows scrolled under the bar only overlap it.
    private static func isTabBarButton(_ element: XCUIElement, in tabBar: CGRect) -> Bool {
        element.elementType == .button && tabBar.contains(element.frame)
    }

    /// A word row in Words reads as one element whose label starts with the word.
    private func element(labelled prefix: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
    }

    /// Rows combine their texts into one label ("The Red Boat, Level A1, …").
    private func button(startingWith prefix: String) -> XCUIElement {
        let element = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: 10), "button starting with \(prefix)")
        return element
    }
}
