import Foundation

enum QuickAction {
    static let notification = Notification.Name("RainroomQuickAction")
    static let pendingIdentifierKey = "pendingQuickActionIdentifier"

    static func identifier(from type: String) -> String? {
        if type.hasSuffix(".pomodoro") {
            return "pomodoro"
        }
        if type.hasSuffix(".break") {
            return "break"
        }
        guard let minutes = Int(type.components(separatedBy: ".").last ?? ""),
              [10, 30].contains(minutes) else {
            return nil
        }
        return "timer.\(minutes)"
    }

    static func queue(identifier: String) {
        UserDefaults.standard.set(identifier, forKey: pendingIdentifierKey)
        NotificationCenter.default.post(
            name: notification,
            object: nil,
            userInfo: ["identifier": identifier]
        )
    }

    static func takePendingIdentifier() -> String? {
        guard let identifier = UserDefaults.standard.string(forKey: pendingIdentifierKey) else {
            return nil
        }

        UserDefaults.standard.removeObject(forKey: pendingIdentifierKey)
        return identifier
    }
}
