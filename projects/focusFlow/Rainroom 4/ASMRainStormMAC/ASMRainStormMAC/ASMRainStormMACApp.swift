import SwiftUI

@main
struct ASMRainStormMACApp: App {
    @State private var player = RainPlayer()

    var body: some Scene {
        WindowGroup {
            RainView(player: player)
                .preferredColorScheme(.dark)
                .frame(minWidth: 620, minHeight: 720)
        }
        .defaultSize(width: 720, height: 860)
        .commands {
            CommandGroup(after: .appInfo) {
                Button(player.playing ? "Pause Rain" : "Play Rain") {
                    player.toggle()
                }
                .keyboardShortcut(.space, modifiers: [])
            }
        }
    }
}
