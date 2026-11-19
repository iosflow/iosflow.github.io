import AVFoundation

@MainActor
final class RainAudioEngine {
    private var player: AVAudioPlayer?
    private var loadedTexture: String?

    func play(texture: String, volume: Float, fadeDuration: TimeInterval = 0) throws {
        if loadedTexture != texture || player == nil {
            player?.stop()

            let resourceName = switch texture {
            case "Soft": "new soft"
            case "Heavy": "new heavy"
            case "Thunderstorm": "thunderstorm"
            default: "new medium"
            }

            let audioURL = ["m4a", "wav", "mp3", "aiff"].lazy.compactMap {
                Bundle.main.url(forResource: resourceName, withExtension: $0)
            }.first

            guard let audioURL else {
                throw CocoaError(.fileNoSuchFile)
            }

            player = try AVAudioPlayer(contentsOf: audioURL)
            player?.numberOfLoops = -1
            loadedTexture = texture
        }

        player?.volume = fadeDuration > 0 ? 0 : volume
        guard player?.play() == true else {
            throw CocoaError(.fileReadUnknown)
        }
        if fadeDuration > 0 {
            player?.setVolume(volume, fadeDuration: fadeDuration)
        }
    }

    func pause() {
        player?.pause()
    }

    func setVolume(_ value: Float) {
        player?.volume = value
    }
}
