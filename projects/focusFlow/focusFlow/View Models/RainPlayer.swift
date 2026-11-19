import SwiftUI
import Combine
import AVFoundation
import MediaPlayer
import ActivityKit

final class RainPlayer: ObservableObject {
    private enum PomodoroPhase { case focus, breakTime }
    @Published var playing = false
    @Published var texture = ["Soft", "Steady", "Heavy", "Thunderstorm"].randomElement() ?? "Steady"
    @Published var volume: Double = UserDefaults.standard.object(forKey: "volume") as? Double ?? 0.65 {
        didSet { guard !isPreview else { return }; engine.setVolume(Float(volume)); UserDefaults.standard.set(volume, forKey: "volume") }
    }
    @Published var deadline: Date?
    @Published var remaining = "No timer"
    @Published var timerProgress = 0.0
    @Published var pomodoroActive = false
    @Published var pomodoroStatus = "Pomodoro"
    @Published var pomodoroPhaseNumber = 0
    @Published var pomodoroIsFocus = true
    @Published var error: String?
    private let engine = RainAudioEngine()
    private let mindfulnessHealthStore = MindfulnessHealthStore()
    private var completionPlayer: AVAudioPlayer?
    private var breakPlayer: AVAudioPlayer?
    private var bellTransitionTimer: Timer?
    private var pomodoroPhase: PomodoroPhase?
    private var pomodoroCycle = 0
    private var playbackRequest = 0
    private var wantsPlayback = false
    private var timer: Timer?
    private var sleepTimerDuration: TimeInterval?
    private var mindfulnessSessionStart: Date?
    private var sleepActivity: Activity<RainSleepTimerAttributes>?
    private var didStartLaunchTimer = false
    private var resumeAfterInterruption = false
    private let isPreview: Bool

    init(isPreview: Bool = false) {
        self.isPreview = isPreview
        // Canvas fixtures skip observers, timer ticks, and changes to the real audio session.
        if isPreview {
            texture = "Heavy"
            volume = 0.65
            return
        }
        UserDefaults.standard.set(texture, forKey: "texture")
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        NotificationCenter.default.addObserver(self, selector: #selector(interrupted), name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(routeChanged), name: AVAudioSession.routeChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(quickActionRequested), name: QuickAction.notification, object: nil)
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.tick() }
    }

    func choose(_ name: String) {
        guard texture != name else { return }
        let wasPlaying = wantsPlayback
        texture = name
        if !isPreview { UserDefaults.standard.set(name, forKey: "texture") }
        if wasPlaying { play() }
    }

    func play(fadeDuration: TimeInterval = 0) {
        if isPreview { playing = true; wantsPlayback = true; return }
        playbackRequest += 1
        let request = playbackRequest
        wantsPlayback = true
        engine.play(
            texture: texture,
            volume: Float(volume),
            fadeDuration: fadeDuration
        ) { [weak self] message in
            guard let self, self.playbackRequest == request else { return }
            self.playing = message == nil
            self.wantsPlayback = message == nil
            self.error = message
            self.updateNowPlaying()
        }
    }

    func pause() {
        playbackRequest += 1
        wantsPlayback = false
        if !isPreview { engine.pause() }
        playing = false; resumeAfterInterruption = false; updateNowPlaying()
    }
    func toggle() { wantsPlayback ? pause() : play() }

    func startLaunchTimer() {
        guard !isPreview, !didStartLaunchTimer else { return }
        didStartLaunchTimer = true

        if let identifier = QuickAction.takePendingIdentifier() {
            startQuickAction(identifier)
        } else {
            startSession(minutes: 60)
        }
    }

    private func startQuickAction(_ identifier: String) {
        switch identifier {
        case "pomodoro":
            startPomodoro()
        case "break":
            startPomodoroBreak()
        default:
            guard let minutes = Int(identifier.components(separatedBy: ".").last ?? "") else {
                return
            }
            startSession(minutes: minutes)
        }
    }

    private func startSession(minutes: Int) {
        setTimer(minutes)
        play()
    }

    private func startPomodoroBreak() {
        cancelPomodoro()
        pomodoroActive = true
        pomodoroCycle = 1
        startBreak()
    }

    func setTimer(_ minutes: Int?) {
        guard !isPreview else { return }
        cancelPomodoro()
        configureTimer(minutes)
    }

    func togglePomodoro() {
        guard !isPreview else { return }
        if pomodoroActive {
            skipPomodoroPhase()
        } else {
            startPomodoro()
        }
    }

    private func configureTimer(_ minutes: Int?) {
        let transitionDate = Date()
        finishMindfulnessSession(at: transitionDate)

        sleepTimerDuration = minutes.map { TimeInterval($0 * 60) }
        deadline = sleepTimerDuration.map { transitionDate.addingTimeInterval($0) }
        timerProgress = minutes == nil ? 0 : 1

        if minutes != nil {
            mindfulnessSessionStart = transitionDate
            mindfulnessHealthStore.requestAuthorization()
        }
        tick()
        updateNowPlaying()
        updateSleepActivity()
    }

    private func startPomodoro() {
        cancelPomodoro()
        pomodoroActive = true
        pomodoroCycle = 1
        playTimerCompletionSound()
        startFocus(fadeIn: true)
    }

    private func startFocus(fadeIn: Bool = false) {
        pomodoroPhase = .focus
        pomodoroPhaseNumber = pomodoroCycle * 2 - 1
        pomodoroIsFocus = true
        pomodoroStatus = "\(pomodoroPhaseNumber)/4"
        configureTimer(55)
        play(fadeDuration: fadeIn ? 4 : 0)
    }

    private func startBreak() {
        pause()
        pomodoroPhase = .breakTime
        pomodoroPhaseNumber = pomodoroCycle * 2
        pomodoroIsFocus = false
        pomodoroStatus = "\(pomodoroPhaseNumber)/4"
        configureTimer(5)
        guard let soundURL = Bundle.main.url(forResource: "break ocean seagulls", withExtension: "mp4") else {
            error = "The beach break sound could not be found."
            return
        }
        do {
            breakPlayer = try AVAudioPlayer(contentsOf: soundURL)
            breakPlayer?.numberOfLoops = -1
            breakPlayer?.volume = Float(volume)
            breakPlayer?.prepareToPlay()
            breakPlayer?.play()
        } catch {
            breakPlayer = nil
            self.error = "The beach break sound could not be played."
        }
    }

    private func skipPomodoroPhase() {
        bellTransitionTimer?.invalidate()
        bellTransitionTimer = nil
        completionPlayer?.stop()
        completionPlayer = nil

        switch pomodoroPhase {
        case .focus:
            startBreak()
        case .breakTime:
            breakPlayer?.stop()
            breakPlayer = nil
            if pomodoroCycle < 2 {
                pomodoroCycle += 1
                startFocus()
            } else {
                cancelPomodoro()
                configureTimer(nil)
                pause()
            }
        case nil:
            startPomodoro()
        }
    }

    private func finishBreak() {
        breakPlayer?.stop()
        breakPlayer = nil
        updateSleepActivity()
        guard let soundURL = Bundle.main.url(forResource: "bells", withExtension: "mp4") else {
            advancePomodoroAfterBells()
            return
        }
        do {
            completionPlayer = try AVAudioPlayer(contentsOf: soundURL)
            completionPlayer?.numberOfLoops = 2
            completionPlayer?.prepareToPlay()
            let totalDuration = (completionPlayer?.duration ?? 0) * 3
            completionPlayer?.play()
            bellTransitionTimer = Timer.scheduledTimer(withTimeInterval: max(totalDuration, 0.1), repeats: false) { [weak self] _ in
                self?.advancePomodoroAfterBells()
            }
        } catch {
            completionPlayer = nil
            advancePomodoroAfterBells()
        }
    }

    private func advancePomodoroAfterBells() {
        bellTransitionTimer = nil
        completionPlayer = nil
        if pomodoroCycle < 2 {
            pomodoroCycle += 1
            startFocus()
        } else {
            cancelPomodoro()
            configureTimer(nil)
        }
    }

    private func cancelPomodoro() {
        breakPlayer?.stop()
        breakPlayer = nil
        bellTransitionTimer?.invalidate()
        bellTransitionTimer = nil
        if pomodoroActive || pomodoroPhase != nil {
            completionPlayer?.stop()
            completionPlayer = nil
        }
        pomodoroActive = false
        pomodoroPhase = nil
        pomodoroCycle = 0
        pomodoroPhaseNumber = 0
        pomodoroIsFocus = true
        pomodoroStatus = "Pomodoro"
    }

    private func checkpointMindfulnessSession(at date: Date) {
        guard let startDate = mindfulnessSessionStart else { return }
        let completeMinutes = floor(date.timeIntervalSince(startDate) / 60)
        guard completeMinutes >= 1 else { return }

        let checkpointDate = startDate.addingTimeInterval(completeMinutes * 60)
        mindfulnessSessionStart = checkpointDate
        mindfulnessHealthStore.saveSession(from: startDate, to: checkpointDate)
    }

    private func finishMindfulnessSession(at endDate: Date) {
        guard let startDate = mindfulnessSessionStart else { return }
        mindfulnessSessionStart = nil
        mindfulnessHealthStore.saveSession(from: startDate, to: endDate)
    }

    private func updateSleepActivity() {
        let newDeadline = deadline
        let selectedTexture = texture
        let timerTitle: String
        let timerStyle: String
        switch pomodoroPhase {
        case .focus:
            timerTitle = "Focus \(pomodoroPhaseNumber)/4"
            timerStyle = "focus"
        case .breakTime:
            timerTitle = "Break \(pomodoroPhaseNumber)/4"
            timerStyle = "break"
        case nil:
            timerTitle = "Sleep timer"
            timerStyle = "sleep"
        }

        Task {
            for activity in Activity<RainSleepTimerAttributes>.activities {
                let finalState = RainSleepTimerAttributes.ContentState(
                    endDate: activity.content.state.endDate,
                    timerTitle: activity.content.state.timerTitle,
                    timerStyle: activity.content.state.timerStyle
                )
                await activity.end(
                    ActivityContent(state: finalState, staleDate: nil),
                    dismissalPolicy: .immediate
                )
            }

            guard let newDeadline,
                  ActivityAuthorizationInfo().areActivitiesEnabled else {
                sleepActivity = nil
                return
            }

            do {
                let attributes = RainSleepTimerAttributes(texture: selectedTexture)
                let state = RainSleepTimerAttributes.ContentState(
                    endDate: newDeadline,
                    timerTitle: timerTitle,
                    timerStyle: timerStyle
                )
                sleepActivity = try Activity.request(
                    attributes: attributes,
                    content: ActivityContent(state: state, staleDate: newDeadline),
                    pushType: nil
                )
            } catch {
                sleepActivity = nil
            }
        }
    }

    private func tick() {
        guard let deadline else {
            remaining = "No timer"
            timerProgress = 0
            return
        }
        let now = Date()
        checkpointMindfulnessSession(at: min(now, deadline))
        let secondsRemaining = max(0, deadline.timeIntervalSince(now))
        if let sleepTimerDuration, sleepTimerDuration > 0 {
            timerProgress = min(1, secondsRemaining / sleepTimerDuration)
        }
        let seconds = max(0, Int(ceil(secondsRemaining)))
        remaining = String(format: "%d:%02d", seconds / 60, seconds % 60)
        if seconds == 0 {
            finishMindfulnessSession(at: min(now, deadline))
            self.deadline = nil
            sleepTimerDuration = nil
            remaining = "No timer"
            timerProgress = 0
            switch pomodoroPhase {
            case .focus: startBreak()
            case .breakTime: finishBreak()
            case nil:
                pause()
                playTimerCompletionSound()
                updateSleepActivity()
            }
        }
    }
    private func playTimerCompletionSound() {
        guard let soundURL = Bundle.main.url(
            forResource: "ding airplane",
            withExtension: "m4a"
        ) else { return }

        do {
            completionPlayer = try AVAudioPlayer(contentsOf: soundURL)
            completionPlayer?.prepareToPlay()
            completionPlayer?.play()
        } catch {
            completionPlayer = nil
        }
    }

    private func updateNowPlaying() {
        guard !isPreview else { return }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
    @objc private func interrupted(_ notification: Notification) {
        guard let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        if type == .began {
            let shouldResume = wantsPlayback
            pause()
            resumeAfterInterruption = shouldResume
        }
        else {
            let rawOptions = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            if resumeAfterInterruption && AVAudioSession.InterruptionOptions(rawValue: rawOptions).contains(.shouldResume) { play() }
            resumeAfterInterruption = false
        }
    }
    @objc private func quickActionRequested(_ notification: Notification) {
        guard let identifier = notification.userInfo?["identifier"] as? String else { return }
        didStartLaunchTimer = true
        _ = QuickAction.takePendingIdentifier()
        startQuickAction(identifier)
    }

    @objc private func routeChanged(_ notification: Notification) {
        if notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue { pause() }
    }
    deinit {
        timer?.invalidate()
        bellTransitionTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
}
