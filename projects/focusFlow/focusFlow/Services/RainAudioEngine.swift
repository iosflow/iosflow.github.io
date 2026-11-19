import AVFoundation

/// All potentially blocking audio work runs on one queue, never on the UI thread.
final class RainAudioEngine {
    private let queue = DispatchQueue(label: "personal.rainroom.audio", qos: .userInitiated)
    private var player: AVAudioPlayer?
    private var loadedTexture: String?

    func play(
        texture: String,
        volume: Float,
        fadeDuration: TimeInterval = 0,
        completion: @escaping (String?) -> Void
    ) {
        queue.async { [self] in
            do {
                let session = AVAudioSession.sharedInstance()
                if session.category != .playback { try session.setCategory(.playback, mode: .default) }
                try session.setActive(true)
                if loadedTexture != texture || player == nil {
                    player?.stop()
                    player = nil
                    loadedTexture = nil
                    let resourceName: String
                    switch texture {
                    case "Soft":
                        resourceName = "new soft"
                    case "Heavy":
                        resourceName = "new heavy"
                    case "Thunderstorm":
                        resourceName = "thunderstorm"
                    default:
                        resourceName = "new medium"
                    }
                    let audioURL = ["m4a", "wav", "mp3", "aiff"].compactMap {
                        Bundle.main.url(forResource: resourceName, withExtension: $0)
                    }.first
                    guard let url = audioURL else {
                        throw NSError(domain: "Rainroom", code: 1, userInfo: [NSLocalizedDescriptionKey: "The rain sound could not be loaded."])
                    }
                    player = try AVAudioPlayer(contentsOf: url)
                    player?.numberOfLoops = -1
                    loadedTexture = texture
                }
                player?.volume = fadeDuration > 0 ? 0 : volume
                guard player?.play() == true else {
                    throw NSError(domain: "Rainroom", code: 2, userInfo: [NSLocalizedDescriptionKey: "Playback could not start."])
                }
                if fadeDuration > 0 {
                    player?.setVolume(volume, fadeDuration: fadeDuration)
                }
                DispatchQueue.main.async { completion(nil) }
            } catch {
                player?.pause()
                try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                let message = error.localizedDescription
                DispatchQueue.main.async { completion(message) }
            }
        }
    }

    func pause() {
        queue.async { [self] in
            player?.pause()
        }
    }

    func setVolume(_ value: Float) {
        queue.async { [self] in player?.volume = value }
    }
}
