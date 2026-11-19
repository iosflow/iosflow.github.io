import XCTest
@testable import focusFlow

final class focusFlowTests: XCTestCase {
    func testHomeScreenShortcutRoutingMatchesRainroom() {
        XCTAssertEqual(QuickAction.identifier(from: "iosflow.focusFlow.pomodoro"), "pomodoro")
        XCTAssertEqual(QuickAction.identifier(from: "iosflow.focusFlow.break"), "break")
        XCTAssertEqual(QuickAction.identifier(from: "iosflow.focusFlow.timer.10"), "timer.10")
        XCTAssertEqual(QuickAction.identifier(from: "iosflow.focusFlow.timer.30"), "timer.30")
        XCTAssertNil(QuickAction.identifier(from: "iosflow.focusFlow.timer.15"))
        XCTAssertNil(QuickAction.identifier(from: "invalid"))
    }

    func testEveryRainroomMediaResourceIsBundled() {
        let bundle = Bundle(for: RainPlayer.self)
        for name in ["new soft", "new medium", "new heavy", "thunderstorm", "ding airplane"] {
            XCTAssertNotNil(bundle.url(forResource: name, withExtension: "m4a"), "Missing \(name)")
        }
        for name in ["thunderstorm video", "break ocean seagulls", "bells"] {
            XCTAssertNotNil(bundle.url(forResource: name, withExtension: "mp4"), "Missing \(name)")
        }
    }
}
