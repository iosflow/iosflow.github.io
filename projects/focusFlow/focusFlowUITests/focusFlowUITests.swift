import XCTest

final class focusFlowUITests: XCTestCase {
    @MainActor
    func testRainroomControlsAndSleepTimer() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let health = XCUIApplication(bundleIdentifier: "com.apple.Health")
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        addUIInterruptionMonitor(withDescription: "Health permission") { alert in
            if alert.buttons["Cancel"].exists { alert.buttons["Cancel"].tap(); return true }
            if alert.buttons["Don’t Allow"].exists { alert.buttons["Don’t Allow"].tap(); return true }
            return false
        }
        XCTAssertTrue(app.staticTexts["ASMRainStorm"].waitForExistence(timeout: 15))
        // Rainroom starts with controls hidden; a vertical swipe reveals them.
        if app.buttons["Cancel"].exists { app.buttons["Cancel"].tap() }
        app.swipeUp()
        if springboard.buttons["Don’t Allow"].exists { springboard.buttons["Don’t Allow"].tap() }
        if health.buttons["Don’t Allow"].exists { health.buttons["Don’t Allow"].tap() }
        XCTAssertTrue(app.buttons["Soft"].waitForExistence(timeout: 5))
        app.buttons["Heavy"].tap()
        XCTAssertTrue(app.staticTexts["Heavy rain"].exists)
        XCTAssertTrue(app.buttons["Thunderstorm"].exists)
        app.buttons["Sleep timer"].tap()
        app.buttons["Off"].tap()
        XCTAssertTrue(app.buttons["Sleep timer"].exists)
    }
}
