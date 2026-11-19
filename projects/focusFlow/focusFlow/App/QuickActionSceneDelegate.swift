import UIKit

final class QuickActionSceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        if let shortcut = connectionOptions.shortcutItem,
           let identifier = QuickAction.identifier(from: shortcut.type) {
            QuickAction.queue(identifier: identifier)
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        Task {
            await LiveActivityCleanup.endAll()
        }
    }

    func windowScene(
        _ windowScene: UIWindowScene,
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
