import XCTest

/// Real touches on the main screen: the swipe up opens the settings and disturbs nothing else.
final class GestureTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = true
    }

    private func start(_ arguments: [String] = []) {
        app = XCUIApplication()
        app.launchArguments = ["-demo", "-still"] + arguments
        app.launch()
        XCTAssertTrue(app.buttons["Играть"].waitForExistence(timeout: 90), "the song is not loaded")
        sleep(4)
    }

    private var settingsOpen: Bool { app.navigationBars["Настройки"].waitForExistence(timeout: 4) }

    private func swipe(_ from: XCUICoordinate, dx: CGFloat = 0, dy: CGFloat = 0) {
        from.press(forDuration: 0.02, thenDragTo: from.withOffset(CGVector(dx: dx, dy: dy)), withVelocity: .fast, thenHoldForDuration: 0)
    }

    private func middle(_ e: XCUIElement) -> XCUICoordinate { e.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)) }

    private func close() {
        swipe(middle(app.navigationBars["Настройки"]), dy: 500)
        XCTAssertTrue(app.navigationBars["Настройки"].waitForNonExistence(timeout: 5), "the swipe down did not close the settings")
        sleep(1)
    }

    private var cover: XCUIElement { app.descendants(matching: .any)["Обложка. Смахивание переключает песню"].firstMatch }

    func testSwipeUpOpensSettings() {
        start()
        // the visualisation is between the title and the wave
        let wave = app.descendants(matching: .any)["Позиция в треке"].firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0))
        let places: [(String, XCUICoordinate)] = [
            ("cover", middle(cover)), ("title", middle(app.staticTexts["Обійми"].firstMatch)),
            ("visualisation", wave.withOffset(CGVector(dx: 0, dy: -35))),
            ("play", middle(app.buttons["Играть"])), ("next", middle(app.buttons["Следующий"])),
            ("songs", middle(app.buttons["Песни"])), ("volume", middle(app.buttons["Громкость"])),
        ]
        for (name, place) in places {
            swipe(place, dy: -160)
            XCTAssertTrue(settingsOpen, name)
            if app.navigationBars["Настройки"].exists { close() }
            XCTAssertTrue(app.buttons["Играть"].exists, "\(name): the button was pressed by the swipe")
            XCTAssertTrue(app.staticTexts["Обійми"].exists, "\(name): the song changed")
        }
    }

    func testButtonsAndSwipesStillWork() {
        start()
        app.buttons["Следующий"].tap()
        XCTAssertTrue(app.staticTexts["Бас і біт"].waitForExistence(timeout: 5), "next")
        swipe(middle(cover), dx: -200)
        XCTAssertTrue(app.staticTexts["ITALODISCO"].waitForExistence(timeout: 5), "cover to the left")
        XCTAssertFalse(app.navigationBars["Настройки"].exists, "the sideways swipe opened the settings")
        app.buttons["Громкость"].tap()
        XCTAssertTrue(app.buttons["Скрыть громкость"].waitForExistence(timeout: 4), "volume")
        app.buttons["Скрыть громкость"].tap()
        sleep(1)
        app.buttons["Песни"].tap()
        XCTAssertTrue(app.buttons["Закрыть"].waitForExistence(timeout: 5), "songs")
        XCTAssertFalse(app.navigationBars["Настройки"].exists, "songs opened the settings")
    }

    func testLyricsScroll() {
        start(["-lyrics"])
        swipe(app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)), dy: -200)
        XCTAssertFalse(settingsOpen, "the swipe on the lyrics opened the settings")
    }
}
