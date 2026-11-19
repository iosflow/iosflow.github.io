import AVFoundation
import Observation

@MainActor
@Observable
final class RainPlayer {
    private enum PomodoroPhase {
        case focus
        case breakTime
    }

    var playing = false
    var texture = UserDefaults.standard.string(forKey: "texture") ?? "Steady"
    var volume = UserDefaults.standard.object(forKey: "volume") as? Double ?? 0.65 {
        didSet {
            engine.setVolume(Float(volume))
            UserDefaults.standard.set(volume, forKey: "volume")
        }
    }
    var deadline: Date?
    var remaining = "No timer"
    var timerProgress = 0.0
    var pomodoroActive = false
    var pomodoroStatus = "Pomodoro"
    var pomodoroIsFocus = true
    var error: String?

    private let engine = RainAudioEngine()
    private var completionPlayer: AVAudioPlayer?
    private var breakPlayer: AVAudioPlayer?
    private var bellTransitionTimer: Timer?
    private var timer: Timer?
    private var sleepTimerDuration: TimeInterval?
    private var pomodoroPhase: PomodoroPhase?
    private var pomodoroCycle = 0

    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func choose(_ name: String) {
        guard texture != name else { return }
        let shouldResume = playing
        texture = name
        UserDefaults.standard.set(name, forKey: "texture")
        if shouldResume { play() }
    }

    func play(fadeDuration: TimeInterval = 0) {
        do {
            try engine.play(texture: texture, volume: Float(volume), fadeDuration: fadeDuration)
            playing = true
            error = nil
        } catch {
            playing = false
            self.error = "The rain sound could not be played."
        }
    }

    func pause() {
        engine.pause()
        playing = false
    }

    func toggle() {
        playing ? pause() : play()
    }

    func setTimer(_ minutes: Int?) {
        cancelPomodoro()
        configureTimer(minutes)
    }

    func togglePomodoro() {
        pomodoroActive ? skipPomodoroPhase() : startPomodoro()
    }

    private func configureTimer(_ minutes: Int?) {
        sleepTimerDuration = minutes.map { TimeInterval($0 * 60) }
        deadline = sleepTimerDuration.map { Date().addingTimeInterval($0) }
        timerProgress = minutes == nil ? 0 : 1
        tick()
    }

    private func startPomodoro() {
        cancelPomodoro()
        pomodoroActive = true
        pomodoroCycle = 1
        playCompletionSound(named: "ding airplane", extension: "m4a")
        startFocus(fadeIn: true)
    }

    private func startFocus(fadeIn: Bool = false) {
        pomodoroPhase = .focus
        pomodoroIsFocus = true
        pomodoroStatus = "\(pomodoroCycle * 2 - 1)/4"
        configureTimer(55)
        play(fadeDuration: fadeIn ? 4 : 0)
    }

    private func startBreak() {
        pause()
        pomodoroPhase = .breakTime
        pomodoroIsFocus = false
        pomodoroStatus = "\(pomodoroCycle * 2)/4"
        configureTimer(5)

        guard let url = Bundle.main.url(forResource: "break ocean seagulls", withExtension: "mp4") else { return }
        breakPlayer = try? AVAudioPlayer(contentsOf: url)
        breakPlayer?.numberOfLoops = -1
        breakPlayer?.volume = Float(volume)
        breakPlayer?.play()
    }

    private func skipPomodoroPhase() {
        switch pomodoroPhase {
        case .focus:
            startBreak()
        case .breakTime:
            breakPlayer?.stop()
            if pomodoroCycle < 2 {
                pomodoroCycle += 1
                startFocus()
            } else {
                cancelPomodoro()
                configureTimer(nil)
            }
        case nil:
            startPomodoro()
        }
    }

    private func finishBreak() {
        breakPlayer?.stop()
        playCompletionSound(named: "bells", extension: "mp4", loops: 2)
        let duration = (completionPlayer?.duration ?? 0) * 3
        bellTransitionTimer = Timer.scheduledTimer(withTimeInterval: max(duration, 0.1), repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.pomodoroCycle < 2 {
                    self.pomodoroCycle += 1
                    self.startFocus()
                } else {
                    self.cancelPomodoro()
                    self.configureTimer(nil)
                }
            }
        }
    }

    private func cancelPomodoro() {
        breakPlayer?.stop()
        breakPlayer = nil
        bellTransitionTimer?.invalidate()
        bellTransitionTimer = nil
        pomodoroActive = false
        pomodoroPhase = nil
        pomodoroCycle = 0
        pomodoroIsFocus = true
        pomodoroStatus = "Pomodoro"
    }

    private func tick() {
        guard let deadline else {
            remaining = "No timer"
            timerProgress = 0
            return
        }

        let secondsRemaining = max(0, deadline.timeIntervalSinceNow)
        if let sleepTimerDuration, sleepTimerDuration > 0 {
            timerProgress = min(1, secondsRemaining / sleepTimerDuration)
        }
        let seconds = max(0, Int(ceil(secondsRemaining)))
        remaining = String(format: "%d:%02d", seconds / 60, seconds % 60)

        guard seconds == 0 else { return }
        self.deadline = nil
        sleepTimerDuration = nil
        timerProgress = 0
        switch pomodoroPhase {
        case .focus: startBreak()
        case .breakTime: finishBreak()
        case nil:
            pause()
            playCompletionSound(named: "ding airplane", extension: "m4a")
        }
    }

    private func playCompletionSound(named name: String, extension fileExtension: String, loops: Int = 0) {
        guard let url = Bundle.main.url(forResource: name, withExtension: fileExtension) else { return }
        completionPlayer = try? AVAudioPlayer(contentsOf: url)
        completionPlayer?.numberOfLoops = loops
        completionPlayer?.play()
    }
}
