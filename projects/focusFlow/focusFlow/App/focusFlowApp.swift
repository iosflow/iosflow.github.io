import SwiftUI

@main
struct focusFlowApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    var body: some Scene {
        WindowGroup { ContentView().preferredColorScheme(.dark) }
    }
}
