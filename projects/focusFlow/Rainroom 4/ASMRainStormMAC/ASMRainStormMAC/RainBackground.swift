import AppKit
import AVFoundation
import SwiftUI

struct RainPalette {
    let blue: Color
    let highlight: Color
    let depth: Color
    let opacity: Double

    static func forTexture(_ name: String) -> RainPalette {
        switch name {
        case "Soft":
            .init(blue: Color(red: 0.08, green: 0.26, blue: 0.48), highlight: Color(red: 0.48, green: 0.70, blue: 0.90), depth: Color(red: 0.02, green: 0.08, blue: 0.18), opacity: 0.48)
        case "Heavy":
            .init(blue: Color(red: 0.035, green: 0.09, blue: 0.28), highlight: Color(red: 0.38, green: 0.52, blue: 0.82), depth: Color(red: 0.008, green: 0.02, blue: 0.08), opacity: 0.62)
        default:
            .init(blue: Color(red: 0.05, green: 0.17, blue: 0.42), highlight: Color(red: 0.42, green: 0.64, blue: 0.90), depth: Color(red: 0.012, green: 0.05, blue: 0.16), opacity: 0.54)
        }
    }
}

struct RainBackground: View {
    let texture: String
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var palette: RainPalette { .forTexture(texture) }
    private var clip: URL? { Bundle.main.url(forResource: "thunderstorm video", withExtension: "mp4") }

    var body: some View {
        ZStack {
            LinearGradient(colors: [palette.blue, palette.depth], startPoint: .topLeading, endPoint: .bottomTrailing)
            TimelineView(.animation(minimumInterval: 1.0 / 24, paused: reduceMotion || scenePhase != .active)) { context in
                Canvas { canvas, size in
                    let time = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
                    let count = texture == "Soft" ? 45 : texture == "Heavy" ? 125 : 80
                    for index in 0..<count {
                        let x = CGFloat((index * 73 + 19) % 997) / 997 * size.width
                        let y = (CGFloat(time * Double(16 + index % 40)) + CGFloat(index * 47))
                            .truncatingRemainder(dividingBy: size.height + 100) - 50
                        var streak = Path()
                        streak.move(to: CGPoint(x: x, y: y))
                        streak.addLine(to: CGPoint(x: x - 3, y: y + CGFloat(18 + index % 42)))
                        canvas.stroke(streak, with: .color(.white.opacity(index % 4 == 0 ? 0.22 : 0.08)), lineWidth: index % 4 == 0 ? 2 : 1)
                    }
                }
            }
            if let clip {
                LoopingRainVideo(url: clip, playing: scenePhase == .active && !reduceMotion)
            }
            palette.blue.opacity(palette.opacity)
            LinearGradient(colors: [.black.opacity(0.18), .clear, palette.depth.opacity(0.4), .black.opacity(0.72)], startPoint: .top, endPoint: .bottom)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct LoopingRainVideo: NSViewRepresentable {
    let url: URL
    let playing: Bool

    func makeNSView(context: Context) -> RainVideoSurface { RainVideoSurface(url: url) }

    func updateNSView(_ view: RainVideoSurface, context: Context) {
        playing ? view.player.play() : view.player.pause()
    }

    static func dismantleNSView(_ view: RainVideoSurface, coordinator: ()) {
        view.player.pause()
        view.looper?.disableLooping()
        view.player.removeAllItems()
    }
}

private final class RainVideoSurface: NSView {
    let player = AVQueuePlayer()
    var looper: AVPlayerLooper?

    init(url: URL) {
        super.init(frame: .zero)
        wantsLayer = true
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspectFill
        layer = playerLayer
        player.isMuted = true
        player.preventsDisplaySleepDuringVideoPlayback = false
        looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }
}
