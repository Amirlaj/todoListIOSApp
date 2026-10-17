import XCTest

@MainActor
final class FlashiesUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-study.shuffle", "NO"]
        app.launch()
        XCTAssertTrue(app.buttons["Library"].firstMatch.waitForExistence(timeout: 15))
    }

    func testStudyFlowAndCaptureScreenshots() throws {
        capture("01-library")
        app.staticTexts["Theory of Computation"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Theory of Computation"].waitForExistence(timeout: 5))
        capture("02-module")
        app.staticTexts["Week 1: Finite State Automata"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Week 1: Finite State Automata"].waitForExistence(timeout: 5))
        capture("03-chapter")
        app.buttons["Study All"].tap()
        XCTAssertTrue(app.buttons["Show Answer"].waitForExistence(timeout: 5))
        capture("04-study")
        app.buttons["Show Answer"].tap()
        XCTAssertTrue(app.buttons["Got It"].waitForExistence(timeout: 5))
        app.buttons["Got It"].tap()
        XCTAssertTrue(app.buttons["Show Answer"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        app.buttons["Review"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Review"].waitForExistence(timeout: 5))
        capture("05-review")
        app.buttons["Favourites"].tap()
        XCTAssertTrue(app.staticTexts["What is an alphabet Σ?"].exists || app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Study '")).firstMatch.exists)
        app.buttons["Statistics"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Reviews today"].waitForExistence(timeout: 5))
        app.swipeUp()
        capture("06-statistics")
        app.buttons["Settings"].firstMatch.tap()
        XCTAssertTrue(app.switches["Daily Study Reminder"].waitForExistence(timeout: 5))
        capture("07-settings")
    }

    func testCreateModuleChapterAndTaggedFavouriteCard() throws {
        app.buttons["Add Module"].tap()
        app.buttons["New Module"].tap()
        let name = app.textFields["Name (e.g. Biology)"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Test Module")
        app.buttons["Create"].tap()
        XCTAssertTrue(app.staticTexts["Test Module"].waitForExistence(timeout: 5))
        app.staticTexts["Test Module"].tap()
        app.buttons["Add your first chapter"].tap()
        let chapter = app.textFields["Chapter name"]
        XCTAssertTrue(chapter.waitForExistence(timeout: 5))
        chapter.tap()
        chapter.typeText("Test Chapter")
        app.buttons["Create"].tap()
        XCTAssertTrue(app.staticTexts["Test Chapter"].waitForExistence(timeout: 5))
        app.staticTexts["Test Chapter"].tap()
        app.buttons["Add a Card Manually"].tap()
        let front = app.textViews["card-front-input"]
        XCTAssertTrue(front.waitForExistence(timeout: 5))
        front.tap()
        front.typeText("Integration question")
        let back = app.textViews["card-back-input"]
        // Tap the first text line, above the multiline field's empty padding.
        back.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.15)).tap()
        back.typeText("Integration answer")
        app.swipeUp()
        let tags = app.textFields["Tags, separated by commas"]
        XCTAssertTrue(tags.waitForExistence(timeout: 5))
        tags.tap()
        tags.typeText("exam, integration")
        let favourite = app.switches["Favourite"]
        favourite.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(favourite.value as? String, "1")
        app.buttons["Save"].tap()
        app.buttons["Review"].firstMatch.tap()
        app.buttons["Favourites"].tap()
        let search = app.searchFields["Search cards and tags"]
        search.tap()
        search.typeText("Integration question")
        XCTAssertTrue(app.staticTexts["Integration question"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["#exam #integration"].exists)
    }

    func testBackupActionsAreAvailable() throws {
        app.buttons["Add Module"].tap()
        XCTAssertTrue(app.buttons["Import Module"].waitForExistence(timeout: 5))
        app.buttons["New Module"].tap()
        app.buttons["Cancel"].tap()
        app.staticTexts["Theory of Computation"].firstMatch.tap()
        app.buttons["More"].tap()
        XCTAssertTrue(app.buttons["Export Module"].waitForExistence(timeout: 5))
        app.buttons["Export Module"].tap()
        let pickerBar = app.navigationBars["FullDocumentManagerViewControllerNavigationBar"]
        XCTAssertTrue(pickerBar.waitForExistence(timeout: 10))
        XCTAssertTrue(app.textFields.matching(NSPredicate(format: "value == 'Theory of Computation'")).firstMatch.exists)
        pickerBar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
            .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)))
        XCTAssertTrue(app.buttons["Add Chapter"].waitForExistence(timeout: 5))
        app.buttons["Add Chapter"].tap()
        XCTAssertTrue(app.buttons["Import Chapter"].waitForExistence(timeout: 5))
    }

    func testSwipesGradeEitherSideAndMissedCardsCanBeReviewed() throws {
        app.staticTexts["Spanish"].firstMatch.tap()
        app.staticTexts["Everyday Words"].firstMatch.tap()
        app.buttons["Study All"].tap()
        XCTAssertTrue(app.staticTexts["Card 1 of 3"].waitForExistence(timeout: 5))
        let card = app.descendants(matching: .any).matching(identifier: "study-card").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))

        // A short horizontal movement or a vertical scroll must not grade a card.
        let center = card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        center.press(forDuration: 0.1, thenDragTo: center.withOffset(CGVector(dx: 35, dy: 0)))
        XCTAssertTrue(app.staticTexts["Card 1 of 3"].exists)
        center.press(forDuration: 0.1, thenDragTo: center.withOffset(CGVector(dx: 15, dy: -150)))
        XCTAssertTrue(app.staticTexts["Card 1 of 3"].exists)

        // Accept and reject without first revealing the answer.
        card.swipeRight()
        XCTAssertTrue(app.staticTexts["Card 2 of 3"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Show Answer"].exists)
        card.swipeLeft()
        XCTAssertTrue(app.staticTexts["Card 3 of 3"].waitForExistence(timeout: 5))

        // Swiping works from the revealed answer too.
        app.buttons["Show Answer"].tap()
        XCTAssertTrue(app.buttons["Got It"].waitForExistence(timeout: 5))
        card.swipeRight()
        XCTAssertTrue(app.staticTexts["You knew 2 of 3 card(s)."].waitForExistence(timeout: 5))
        app.buttons["Review 1 Missed Card(s)"].tap()
        XCTAssertTrue(app.staticTexts["Card 1 of 1"].waitForExistence(timeout: 5))
        XCTAssertTrue(card.label.contains("gracias"))
        card.swipeRight()
        XCTAssertTrue(app.staticTexts["Perfect Round!"].waitForExistence(timeout: 5))
    }

    func testTheorySampleHasAllFiveWeeksAndCanBeAddedToAnExistingLibrary() throws {
        app.staticTexts["Theory of Computation"].firstMatch.tap()
        for title in ["Week 1: Finite State Automata", "Week 2: Regular Expressions",
                      "Week 3: Pumping Lemma for Regular Languages", "Week 4: Context-Free Grammars and PDAs",
                      "Week 5: CFL Pumping Lemma and PDA Practice"] {
            let row = app.staticTexts[title].firstMatch
            if !row.isHittable { app.swipeUp() }
            XCTAssertTrue(row.exists)
        }
        capture("08-theory-weeks")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["Add Module"].tap()
        app.buttons["Add Theory of Computation Sample"].tap()
        XCTAssertEqual(app.staticTexts.matching(identifier: "Theory of Computation").count, 1)
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
