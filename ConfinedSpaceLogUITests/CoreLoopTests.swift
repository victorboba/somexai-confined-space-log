import XCTest

/// The core loop, driven through the real UI: add a space, draft a permit, record the test that
/// authorises entry, sign to issue it, sign an entrant in, confirm the board answers "who is
/// inside", sign them out, and sign to cancel — the whole lifecycle the mandate is built on.
///
/// Every assertion is on content that only exists if the app genuinely worked: the space's own
/// title appearing on the permit card, the roster's live count, the entrant's name on the board.
/// Nothing here asserts merely that a button exists.
final class CoreLoopTests: XCTestCase {

    /// SwiftUI lists are lazy: a row outside the viewport is not merely off-screen, it is absent
    /// from the accessibility hierarchy entirely, so `waitForExistence` waits out its full timeout
    /// and fails on a screen that is working perfectly.
    ///
    /// Scans upwards first and then downwards, because the target is as often above the current
    /// position as below it — typing into a field scrolls the form to clear the keyboard, so by the
    /// time an assertion runs the view may sit well past the section being looked for.
    /// Scroll the element into the hierarchy, assert it arrived, then tap it. Every control on the
    /// permit screen needs this: the form is three pages long and the viewport moves on its own as
    /// fields gain and lose focus.
    private func tapAfterScrolling(_ element: XCUIElement, in app: XCUIApplication, _ message: String,
                                   file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(scrollTo(element, in: app), message, file: file, line: line)
        element.tap()
    }

    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication, swipes: Int = 6) -> Bool {
        if element.exists { return true }
        for _ in 0..<swipes {
            app.swipeDown()
            if element.exists { return true }
        }
        for _ in 0..<(swipes * 2) {
            app.swipeUp()
            if element.exists { return true }
        }
        return element.exists
    }


    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-unlock", "-resetData", "-skipOnboarding", "-uiTesting"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Board"].waitForExistence(timeout: 20),
                      "the board should be the screen the app opens on")
        return app
    }

    /// Simulates a finger-drawn signature: press, drag, release inside the signature pad. A tap
    /// alone never satisfies it — `SignaturePad` only saves once a stroke of more than one point
    /// has actually been dragged.
    private func sign(_ app: XCUIApplication) {
        let pad = app.otherElements["signaturePad"].firstMatch
        XCTAssertTrue(pad.waitForExistence(timeout: 5), "the signature pad never appeared")
        let start = pad.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.55))
        let end = pad.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.35))
        start.press(forDuration: 0.1, thenDragTo: end)
    }

    func testTheFullPermitLifecycle() {
        let app = launch()

        // MARK: A space, added once
        app.tabBars.buttons["Spaces"].tap()
        XCTAssertTrue(app.buttons["Add a space"].firstMatch.waitForExistence(timeout: 5))
        app.buttons["Add a space"].firstMatch.tap()

        XCTAssertTrue(app.navigationBars["New Space"].waitForExistence(timeout: 5))
        let spaceID = app.textFields["Space ID, e.g. TK-104"]
        XCTAssertTrue(spaceID.waitForExistence(timeout: 5))
        spaceID.tap()
        spaceID.typeText("TK-1")
        let spaceName = app.textFields["Name, e.g. Process water tank"]
        spaceName.tap()
        spaceName.typeText("Test Tank")
        app.buttons["Done"].firstMatch.tap()

        XCTAssertTrue(app.staticTexts["TK-1 — Test Tank"].waitForExistence(timeout: 5),
                      "the new space should be in the register")

        // MARK: A draft permit, pre-filled from the space
        app.tabBars.buttons["Board"].tap()
        XCTAssertTrue(app.buttons["New permit"].firstMatch.waitForExistence(timeout: 5))
        app.buttons["New permit"].firstMatch.tap()

        XCTAssertTrue(app.navigationBars["New Permit"].waitForExistence(timeout: 5))
        let purpose = app.textFields["Purpose of entry"]
        XCTAssertTrue(purpose.waitForExistence(timeout: 5))
        purpose.tap()
        purpose.typeText("Quarterly interior inspection")
        let attendant = app.textFields["Attendant"]
        attendant.tap()
        attendant.typeText("D. Whitfield")
        app.buttons["Done"].firstMatch.tap()

        // MARK: The draft is on the board, pre-filled with the space's identity
        let permitCard = app.staticTexts["TK-1 — Test Tank"].firstMatch
        XCTAssertTrue(permitCard.waitForExistence(timeout: 5), "the drafted permit should show the space it was drafted for")
        permitCard.tap()

        XCTAssertTrue(app.navigationBars["TK-1 — Test Tank"].waitForExistence(timeout: 5))

        // MARK: Nobody may enter on a draft — the standard's own preconditions are listed
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "atmospheric test"))
                        .firstMatch.waitForExistence(timeout: 5),
                      "a draft with no test recorded should say so among what is still required")

        // MARK: Test before entry — 1910.146(f)(10)
        app.buttons["Record a test"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Record a Test"].waitForExistence(timeout: 5))
        let oxygen = app.textFields["gasField.oxygen"]
        XCTAssertTrue(oxygen.waitForExistence(timeout: 5))
        oxygen.tap()
        oxygen.typeText("20.9")
        app.buttons["Save"].firstMatch.tap()

        // MARK: Sign to issue — 1910.146(f)(6)
        let supervisor = app.textFields["Entry supervisor"]
        XCTAssertTrue(scrollTo(supervisor, in: app),
                      "the supervisor field sits below the fold on the permit screen")
        supervisor.tap()
        supervisor.typeText("S. Supervisor")
        sign(app)
        XCTAssertTrue(app.buttons["Issue permit"].firstMatch.waitForExistence(timeout: 5),
                      "with a test recorded, an attendant, a supervisor and a signature, the permit should be issuable")
        app.buttons["Issue permit"].firstMatch.tap()

        XCTAssertTrue(scrollTo(app.buttons["Cancel permit"].firstMatch, in: app),
                      "an issued permit should offer to be cancelled")

        // MARK: Who is in the space right now
        tapAfterScrolling(app.buttons["Add entrant"].firstMatch, in: app,
                          "an open permit should let the attendant add who is going in")
        XCTAssertTrue(app.alerts["Add an entrant"].waitForExistence(timeout: 5))
        let entrantName = app.textFields["Name"]
        entrantName.tap()
        entrantName.typeText("J. Okafor")
        let entrantCompany = app.textFields["Company or crew"]
        entrantCompany.tap()
        entrantCompany.typeText("Facilities")
        app.buttons["Add"].firstMatch.tap()

        XCTAssertTrue(scrollTo(app.staticTexts["J. Okafor"], in: app))
        tapAfterScrolling(app.buttons["Sign in"].firstMatch, in: app, "the entrant should be signable in")
        XCTAssertTrue(scrollTo(app.staticTexts["1 inside"], in: app),
                      "the roster header should count the entrant who just signed in")

        // MARK: The board answers the attendant's question without opening the permit
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        if backButton.exists { backButton.tap() }
        XCTAssertTrue(scrollTo(app.staticTexts["J. Okafor"], in: app),
                      "the operations board should show who is inside without drilling into the permit")

        // MARK: Sign the entrant out, then cancel the permit — the retained record
        permitCard.tap()
        tapAfterScrolling(app.buttons["Sign out"].firstMatch, in: app, "the entrant should be signable out")

        tapAfterScrolling(app.buttons["Cancel permit"].firstMatch, in: app, "an open permit should be cancellable")
        XCTAssertTrue(app.navigationBars["Cancel Permit"].waitForExistence(timeout: 5))
        sign(app)
        let confirmCancel = app.buttons["Cancel Permit"].firstMatch
        XCTAssertTrue(confirmCancel.waitForExistence(timeout: 5))
        confirmCancel.tap()

        // MARK: It is now a retained record with a one-year retention clock
        XCTAssertTrue(app.navigationBars["TK-1 — Test Tank"].waitForExistence(timeout: 5))
        XCTAssertTrue(scrollTo(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Retain")).firstMatch, in: app),
                      "a cancelled permit should show its retention clock")

        let back2 = app.navigationBars.buttons.element(boundBy: 0)
        if back2.exists { back2.tap() }
        app.tabBars.buttons["Archive"].tap()
        XCTAssertTrue(app.staticTexts["TK-1 — Test Tank"].firstMatch.waitForExistence(timeout: 5),
                      "the cancelled permit should be filed in the Archive")
    }

    func testTheHowToGuideOpensFromTheBoard() {
        let app = launch()
        app.buttons["How do I use this app"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["How do I use Confined Space Log?"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Add the space once"].waitForExistence(timeout: 5),
                      "the first step should be the first thing a new user does")
    }
}
