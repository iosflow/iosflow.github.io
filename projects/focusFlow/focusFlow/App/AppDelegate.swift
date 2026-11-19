import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: nil,
            sessionRole: connectingSceneSession.role
        )
        if connectingSceneSession.role == .windowApplication {
            configuration.delegateClass = QuickActionSceneDelegate.self
        }
        return configuration
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if let shortcut = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem,
           let identifier = QuickAction.identifier(from: shortcut.type) {
            QuickAction.queue(identifier: identifier)
            return false
        }

        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        let backgroundTask = application.beginBackgroundTask(withName: "End Live Activities")
        Task {
            await LiveActivityCleanup.endAll()
            if backgroundTask != .invalid {
                application.endBackgroundTask(backgroundTask)
            }
        }
    }

    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        guard let identifier = QuickAction.identifier(from: shortcutItem.type) else {
            completionHandler(false)
            return
        }

        QuickAction.queue(identifier: identifier)
        completionHandler(true)
    }
}
