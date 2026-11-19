import ActivityKit
import Foundation

struct RainSleepTimerAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let endDate: Date
        let timerTitle: String
        let timerStyle: String
    }

    let texture: String
}
