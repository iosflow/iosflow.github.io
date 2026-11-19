import SwiftUI
import AVFoundation

struct LoopingRainVideo: UIViewRepresentable {
    let url: URL
    let playing: Bool
    func makeUIView(context: Context) -> RainVideoSurface { RainVideoSurface(url: url) }
    func updateUIView(_ view: RainVideoSurface, context: Context) {
        playing ? view.player.play() : view.player.pause()
    }
    static func dismantleUIView(_ view: RainVideoSurface, coordinator: ()) {
        view.player.pause()
        view.looper?.disableLooping()
        view.player.removeAllItems()
    }
}

final class RainVideoSurface: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    let player = AVQueuePlayer()
    var looper: AVPlayerLooper?
    init(url: URL) {
        super.init(frame: .zero)
        player.isMuted = true
        player.preventsDisplaySleepDuringVideoPlayback = false
        let videoLayer = layer as! AVPlayerLayer
        videoLayer.player = player
        videoLayer.videoGravity = .resizeAspectFill
        looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
}
