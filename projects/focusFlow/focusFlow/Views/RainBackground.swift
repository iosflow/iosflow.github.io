import SwiftUI
import AVFoundation

struct RainBackground: View {
    let texture: String
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var palette: RainPalette { .forTexture(texture) }
    private var clip: URL? {
        ["mp4", "mov"].compactMap {
            Bundle.main.url(forResource: "thunderstorm video", withExtension: $0)
        }.first
    }
    var body: some View {
        ZStack {
            // Graphic placeholder until the matching rain clip is supplied.
            LinearGradient(colors: [palette.blue, palette.depth], startPoint: .topLeading, endPoint: .bottomTrailing)
            GeometryReader { geometry in
                ZStack {
                    Ellipse().fill(palette.highlight.opacity(0.25)).frame(width: geometry.size.width * 1.2, height: 320).blur(radius: 70).offset(x: -100, y: 30)
                    Ellipse().fill(palette.blue.opacity(0.7)).frame(width: 290, height: 480).blur(radius: 60).offset(x: 170, y: 280)
                    TimelineView(.animation(minimumInterval: 1.0 / 24, paused: reduceMotion || scenePhase != .active)) { context in
                        Canvas { canvas, size in
                            let time = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
                            let count = texture == "Soft" ? 45 : texture == "Heavy" ? 125 : 80
                            for index in 0..<count {
                                let x = CGFloat((index * 73 + 19) % 997) / 997 * size.width
                                let speed = Double(16 + index % 40)
                                let y = (CGFloat(time * speed) + CGFloat(index * 47)).truncatingRemainder(dividingBy: size.height + 100) - 50
                                let length = CGFloat(18 + index % 42)
                                var streak = Path()
                                streak.move(to: CGPoint(x: x, y: y))
                                streak.addLine(to: CGPoint(x: x - 3, y: y + length))
                                canvas.stroke(streak, with: .color(.white.opacity(index % 4 == 0 ? 0.22 : 0.08)), style: StrokeStyle(lineWidth: index % 4 == 0 ? 2 : 1, lineCap: .round))
                            }
                        }
                    }
                }
            }
            if let clip {
                LoopingRainVideo(url: clip, playing: scenePhase == .active && !reduceMotion)
                    .id(clip)
            }
            // Translucent color keeps the footage visible through each blue shade.
            palette.blue.opacity(palette.opacity)
            LinearGradient(stops: [.init(color: .black.opacity(0.23), location: 0), .init(color: .clear, location: 0.35), .init(color: palette.depth.opacity(0.40), location: 0.65), .init(color: .black.opacity(0.72), location: 1)], startPoint: .top, endPoint: .bottom)
        }.clipped().ignoresSafeArea().allowsHitTesting(false).accessibilityHidden(true)
    }
}
