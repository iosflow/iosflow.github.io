import SwiftUI

/// The app's single screen: rain, playback controls, and sleep/Pomodoro timers.
struct ContentView: View {
    @StateObject private var audio: RainPlayer
    @State private var controlsHidden: Bool

    init(isPreview: Bool = false, controlsInitiallyHidden: Bool = true) {
        _audio = StateObject(wrappedValue: RainPlayer(isPreview: isPreview))
        _controlsHidden = State(initialValue: controlsInitiallyHidden)
    }

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
        .environmentObject(audio)
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

#Preview("Rain controls") {
    ContentView(isPreview: true, controlsInitiallyHidden: false)
        .preferredColorScheme(.dark)
}

#Preview("Immersive rain") {
    ContentView(isPreview: true)
        .preferredColorScheme(.dark)
}
