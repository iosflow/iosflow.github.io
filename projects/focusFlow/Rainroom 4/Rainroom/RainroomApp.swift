///scott
import SwiftUI
import AVFoundation
import MediaPlayer
import UIKit
import ActivityKit

struct RainSleepTimerAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let endDate: Date
        let timerTitle: String
        let timerStyle: String
    }

    let texture: String
}

private enum LiveActivityCleanup {
    static func endAll() async {
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
    }
}

private enum QuickAction {
    static let notification = Notification.Name("RainroomQuickAction")
    static let pendingIdentifierKey = "pendingQuickActionIdentifier"

    static func identifier(from type: String) -> String? {
        if type.hasSuffix(".pomodoro") {
            return "pomodoro"
        }
        if type.hasSuffix(".break") {
            return "break"
        }
        guard let minutes = Int(type.components(separatedBy: ".").last ?? ""),
              [10, 30].contains(minutes) else {
            return nil
        }
        return "timer.\(minutes)"
    }

    static func queue(identifier: String) {
        UserDefaults.standard.set(identifier, forKey: pendingIdentifierKey)
        NotificationCenter.default.post(
            name: notification,
            object: nil,
            userInfo: ["identifier": identifier]
        )
    }

    static func takePendingIdentifier() -> String? {
        guard let identifier = UserDefaults.standard.string(forKey: pendingIdentifierKey) else {
            return nil
        }

        UserDefaults.standard.removeObject(forKey: pendingIdentifierKey)
        return identifier
    }
}

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

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: nil,
            sessionRole: connectingSceneSession.role
        )
        if connectingSceneSession.role == .windowApplication {
            configuration.delegateClass = QuickActionSceneDelegate.self
        }
        return configuration
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if let shortcut = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem,
           let identifier = QuickAction.identifier(from: shortcut.type) {
            QuickAction.queue(identifier: identifier)
            return false
        }

        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        let backgroundTask = application.beginBackgroundTask(withName: "End Live Activities")
        Task {
            await LiveActivityCleanup.endAll()
            if backgroundTask != .invalid {
                application.endBackgroundTask(backgroundTask)
            }
        }
    }

    func application(
        _ application: UIApplication,
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

@main
struct AquaSunMeditationApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var audio = RainPlayer()
    var body: some Scene {
        WindowGroup { RainView().environmentObject(audio).preferredColorScheme(.dark) }
    }
}

final class RainPlayer: ObservableObject {
    private enum PomodoroPhase { case focus, breakTime }
    @Published var playing = false
    @Published var texture = ["Soft", "Steady", "Heavy", "Thunderstorm"].randomElement() ?? "Steady"
    @Published var volume: Double = UserDefaults.standard.object(forKey: "volume") as? Double ?? 0.65 {
        didSet { engine.setVolume(Float(volume)); UserDefaults.standard.set(volume, forKey: "volume") }
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

    init() {
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
        UserDefaults.standard.set(name, forKey: "texture")
        if wasPlaying { play() }
    }

    func play(fadeDuration: TimeInterval = 0) {
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
        engine.pause()
        playing = false; resumeAfterInterruption = false; updateNowPlaying()
    }
    func toggle() { wantsPlayback ? pause() : play() }

    func startLaunchTimer() {
        guard !didStartLaunchTimer else { return }
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
        cancelPomodoro()
        configureTimer(minutes)
    }

    func togglePomodoro() {
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

struct RainView: View {
    @EnvironmentObject private var audio: RainPlayer
    @State private var controlsHidden = true

    private let pomodoroGreen = Color(red: 0.64, green: 1, blue: 0.12)
    private let pomodoroRed = Color(red: 1, green: 0.2, blue: 0.24)
    private var mint: Color { RainPalette.forTexture(audio.texture).highlight }
    private var pomodoroColor: Color {
        audio.pomodoroActive && !audio.pomodoroIsFocus ? pomodoroRed : pomodoroGreen
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RainBackground(texture: audio.texture)
                ScrollView {
                    VStack(spacing: 18) {
                        Spacer(minLength: max(150, geometry.size.height * 0.34))
                        VStack(spacing: 6) {
                            Text("\(audio.texture) rain")
                                .font(.system(size: 26, weight: .light, design: .rounded))
                            Text(audio.texture == "Soft" ? "A gentle wash of calm." : audio.texture == "Heavy" ? "Let the world fall away." : "Settle into the sound.")
                                .font(.subheadline).foregroundStyle(.white.opacity(0.8))
                        }.shadow(color: .black.opacity(0.3), radius: 12, y: 2)
                        HStack(spacing: 12) {
                            Button { audio.toggle() } label: {
                                Image(systemName: audio.playing ? "pause.fill" : "play.fill")
                                    .font(.system(size: 18, weight: .regular))
                                    .offset(x: audio.playing ? 0 : 2)
                                    .foregroundStyle(.white)
                                    .frame(width: 48, height: 48)
                                    .background(.white.opacity(0.13), in: Circle())
                                    .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 1))
                            }.accessibilityLabel(audio.playing ? "Pause rain" : "Play rain")
                            Button { audio.togglePomodoro() } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "timer")
                                    Text("Pomo")
                                    if audio.pomodoroActive {
                                        Text(audio.pomodoroStatus)
                                    }
                                    Text("55")
                                        .foregroundStyle(pomodoroGreen)
                                    Text("/")
                                        .foregroundStyle(.white.opacity(0.55))
                                    Text("5")
                                        .foregroundStyle(pomodoroRed)
                                }
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(pomodoroColor)
                                .padding(.horizontal, 14)
                                .frame(height: 42)
                                .background(pomodoroColor.opacity(0.14), in: Capsule())
                                .overlay(Capsule().stroke(pomodoroColor.opacity(0.9)))
                                .shadow(color: pomodoroColor.opacity(0.85), radius: 9)
                            }
                            .accessibilityLabel(
                                audio.pomodoroActive
                                    ? "Pomodoro \(audio.pomodoroStatus). Skip to \(audio.pomodoroIsFocus ? "break" : "focus")"
                                    : "Start Pomodoro, 55 minute focus and 5 minute break"
                            )
                            .accessibilityAddTraits(audio.pomodoroActive ? .isSelected : [])
                        }
                        VStack(spacing: 14) {
                            HStack(spacing: 6) {
                                ForEach(["Soft", "Steady", "Heavy", "Thunderstorm"], id: \.self) { name in
                                    Button { audio.choose(name) } label: {
                                        VStack(spacing: 6) {
                                            Image(systemName: name == "Soft" ? "cloud.drizzle" : name == "Steady" ? "cloud.rain" : name == "Heavy" ? "cloud.heavyrain" : "cloud.bolt.rain")
                                                .font(.system(size: 18))
                                            Text(name)
                                                .font(.system(size: 10, weight: .medium))
                                                .minimumScaleFactor(0.75)
                                                .lineLimit(1)
                                        }.frame(maxWidth: .infinity).padding(.vertical, 9)
                                            .foregroundStyle(audio.texture == name ? mint : .white.opacity(0.7))
                                            .background(audio.texture == name ? mint.opacity(0.24) : .white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
                                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(audio.texture == name ? mint.opacity(0.35) : .clear))
                                    }.accessibilityAddTraits(audio.texture == name ? .isSelected : [])
                                }
                            }
                            HStack(spacing: 14) {
                                Image(systemName: "speaker.wave.1").foregroundStyle(mint.opacity(0.6))
                                Slider(value: $audio.volume).tint(mint).accessibilityLabel("Rain volume")
                                Image(systemName: "speaker.wave.3").foregroundStyle(mint.opacity(0.6))
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 22)
                    .padding(.bottom, 100)
                    .frame(minHeight: geometry.size.height)
                    .opacity(controlsHidden ? 0 : 1)
                    .offset(y: controlsHidden ? -32 : 0)
                    .allowsHitTesting(!controlsHidden)
                    .animation(.snappy(duration: 0.35), value: controlsHidden)
                }
                .scrollIndicators(.never)

                AquaSunHeader(highlight: mint)
                    .padding(.horizontal, 28)
                    .padding(.top, 22)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                VStack(spacing: 2) {
                    Text("AquaSun Labs")
                        .font(.system(size: 9, design: .monospaced))
                        .tracking(2)
                    Text("_")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                    Text("peace through water")
                        .font(.system(size: 8, design: .monospaced))
                        .tracking(1)
                }
                .foregroundStyle(.white.opacity(0.6))

                SleepTimerControl(highlight: mint)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 8)
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    let verticalDistance = value.translation.height
                    guard abs(verticalDistance) > abs(value.translation.width),
                          abs(verticalDistance) >= 70 else { return }

                    controlsHidden.toggle()
                }
        )
        .sensoryFeedback(.selection, trigger: controlsHidden)
        .task {
            audio.startLaunchTimer()
        }
        .alert("Couldn’t play rain", isPresented: Binding(get: { audio.error != nil }, set: { if !$0 { audio.error = nil } })) {
            Button("OK") { audio.error = nil }
        } message: { Text(audio.error ?? "") }
    }
}
private struct AquaSunHeader: View {
    let highlight: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("ASMRainStorm")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .tracking(3)
            Text("_")
                .font(.system(size: 8, weight: .medium, design: .monospaced))
            Text("AquaSun Labs")
                .font(.system(size: 8, design: .monospaced))
                .tracking(1)
        }
        .foregroundStyle(highlight.opacity(0.75))
        .frame(maxWidth: .infinity)
    }
}

private struct SleepTimerControl: View {
    @EnvironmentObject private var audio: RainPlayer

    let highlight: Color

    private let electricBlue = Color(red: 0.0, green: 0.62, blue: 1.0)
    private let focusGreen = Color(red: 0.64, green: 1, blue: 0.12)
    private let breakRed = Color(red: 1, green: 0.2, blue: 0.24)

    private var timerTitle: String {
        guard audio.pomodoroActive else { return "Sleep timer" }
        return audio.pomodoroIsFocus ? "Focus" : "Break"
    }

    private var timerColor: Color {
        guard audio.pomodoroActive else { return electricBlue }
        return audio.pomodoroIsFocus ? focusGreen : breakRed
    }

    var body: some View {
        Menu {
            Button("Off") {
                audio.setTimer(nil)
            }

            ForEach([1, 3, 5, 10, 15, 30, 40, 45, 60, 90, 120, 240, 480], id: \.self) { minutes in
                Button(timerLabel(for: minutes)) {
                    audio.setTimer(minutes)
                }
            }
        } label: {
            HStack {
                Image(systemName: "moon.zzz")
                Text(timerTitle)
                Spacer()
                Text(audio.deadline == nil ? "Off" : audio.remaining)
                    .monospacedDigit()
                    .foregroundStyle(
                        audio.deadline == nil ? highlight.opacity(0.85) : timerColor
                    )
                    .shadow(
                        color: audio.deadline == nil ? .clear : timerColor.opacity(0.95),
                        radius: 7
                    )
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .font(.system(size: 14, weight: audio.deadline == nil ? .regular : .semibold))
            .foregroundStyle(audio.deadline == nil ? highlight.opacity(0.85) : .white)
            .padding(18)
            .background(
                audio.deadline == nil ? .black.opacity(0.38) : timerColor.opacity(0.16),
                in: RoundedRectangle(cornerRadius: 16)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.white.opacity(audio.deadline == nil ? 0.12 : 0.08), lineWidth: 1)
            )
            .overlay {
                TimerGlowBorder(
                    progress: audio.timerProgress,
                    isActive: audio.deadline != nil,
                    color: timerColor
                )
            }
            .shadow(
                color: audio.deadline == nil ? .black.opacity(0.25) : .clear,
                radius: 10
            )
        }
        .accessibilityLabel(timerTitle)
        .accessibilityValue(audio.deadline == nil ? "Off" : audio.remaining)
    }

    private func timerLabel(for minutes: Int) -> String {
        if minutes == 1 {
            return "1 minute"
        }

        if minutes == 60 {
            return "1 hour"
        }

        if minutes >= 60 {
            return "\(minutes / 60) hours"
        }

        return "\(minutes) minutes"
    }
}

private struct TimerGlowBorder: View {
    let progress: Double
    let isActive: Bool
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            RoundedRectangle(cornerRadius: 16)
                .stroke(color, lineWidth: 1.75)
                .shadow(color: color.opacity(0.95), radius: 14)
                .mask(alignment: .leading) {
                    Rectangle()
                        .frame(
                            width: geometry.size.width * max(0, min(progress, 1))
                        )
                }
                .opacity(isActive ? 1 : 0)
                .animation(.linear(duration: 0.5), value: progress)
        }
        .allowsHitTesting(false)
    }
}
