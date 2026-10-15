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
        app.staticTexts["Biology"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Biology"].waitForExistence(timeout: 5))
        capture("02-module")
        app.staticTexts["Cell Structure"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Cell Structure"].waitForExistence(timeout: 5))
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
        XCTAssertTrue(app.staticTexts["Mitochondria"].exists || app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Study '")).firstMatch.exists)
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
        app.staticTexts["Biology"].firstMatch.tap()
        app.buttons["More"].tap()
        XCTAssertTrue(app.buttons["Export Module"].waitForExistence(timeout: 5))
        app.buttons["Export Module"].tap()
        let pickerBar = app.navigationBars["FullDocumentManagerViewControllerNavigationBar"]
        XCTAssertTrue(pickerBar.waitForExistence(timeout: 10))
        XCTAssertTrue(app.textFields.matching(NSPredicate(format: "value == 'Biology'")).firstMatch.exists)
        pickerBar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
            .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)))
        XCTAssertTrue(app.buttons["Add Chapter"].waitForExistence(timeout: 5))
        app.buttons["Add Chapter"].tap()
        XCTAssertTrue(app.buttons["Import Chapter"].waitForExistence(timeout: 5))
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
