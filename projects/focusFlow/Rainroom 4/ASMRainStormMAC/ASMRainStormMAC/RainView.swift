import SwiftUI

struct RainView: View {
    @Bindable var player: RainPlayer
    @State private var controlsHidden = false

    private var highlight: Color { RainPalette.forTexture(player.texture).highlight }

    var body: some View {
        ZStack {
            RainBackground(texture: player.texture)
            VStack(spacing: 24) {
                header
                Spacer()
                title
                playbackControls
                texturePicker
                volumeControl
                Spacer()
                timerControl
                footer
            }
            .padding(32)
            .opacity(controlsHidden ? 0 : 1)
            .animation(.snappy(duration: 0.35), value: controlsHidden)
        }
        .toolbar {
            ToolbarItem {
                Button {
                    controlsHidden.toggle()
                } label: {
                    Label(controlsHidden ? "Show Controls" : "Hide Controls", systemImage: controlsHidden ? "eye" : "eye.slash")
                }
            }
        }
        .alert("Couldn’t play rain", isPresented: Binding(get: { player.error != nil }, set: { if !$0 { player.error = nil } })) {
            Button("OK") { player.error = nil }
        } message: {
            Text(player.error ?? "")
        }
    }

    private var header: some View {
        VStack(spacing: 2) {
            Text("ASMRainStormMAC")
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .tracking(3)
            Text("AquaSun Labs")
                .font(.system(size: 9, design: .monospaced))
                .tracking(1)
        }
        .foregroundStyle(highlight.opacity(0.85))
    }

    private var title: some View {
        VStack(spacing: 6) {
            Text("\(player.texture) rain")
                .font(.system(size: 32, weight: .light, design: .rounded))
            Text(player.texture == "Soft" ? "A gentle wash of calm." : player.texture == "Heavy" ? "Let the world fall away." : "Settle into the sound.")
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    private var playbackControls: some View {
        HStack(spacing: 16) {
            Button {
                player.toggle()
            } label: {
                Image(systemName: player.playing ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .frame(width: 54, height: 54)
                    .background(.white.opacity(0.14), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.7)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(player.playing ? "Pause rain" : "Play rain")

            Button {
                player.togglePomodoro()
            } label: {
                Label(player.pomodoroActive ? "Pomodoro \(player.pomodoroStatus)" : "Pomodoro 55 / 5", systemImage: "timer")
                    .padding(.horizontal, 16)
                    .frame(height: 44)
                    .background(highlight.opacity(0.18), in: Capsule())
                    .overlay(Capsule().stroke(highlight.opacity(0.8)))
            }
            .buttonStyle(.plain)
        }
    }

    private var texturePicker: some View {
        HStack(spacing: 10) {
            ForEach(["Soft", "Steady", "Heavy", "Thunderstorm"], id: \.self) { name in
                Button {
                    player.choose(name)
                } label: {
                    VStack(spacing: 7) {
                        Image(systemName: icon(for: name)).font(.title3)
                        Text(name).font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(player.texture == name ? highlight : .white.opacity(0.72))
                    .background(player.texture == name ? highlight.opacity(0.24) : .white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(player.texture == name ? .isSelected : [])
            }
        }
        .frame(maxWidth: 580)
    }

    private var volumeControl: some View {
        HStack {
            Image(systemName: "speaker.wave.1")
            Slider(value: $player.volume)
                .tint(highlight)
                .accessibilityLabel("Rain volume")
            Image(systemName: "speaker.wave.3")
        }
        .foregroundStyle(highlight.opacity(0.8))
        .frame(maxWidth: 480)
    }

    private var timerControl: some View {
        Menu {
            Button("Off") { player.setTimer(nil) }
            ForEach([1, 3, 5, 10, 15, 30, 45, 60, 90, 120, 240, 480], id: \.self) { minutes in
                Button(timerLabel(minutes)) { player.setTimer(minutes) }
            }
        } label: {
            HStack {
                Label(player.pomodoroActive ? (player.pomodoroIsFocus ? "Focus" : "Break") : "Sleep timer", systemImage: "moon.zzz")
                Spacer()
                Text(player.deadline == nil ? "Off" : player.remaining).monospacedDigit()
            }
            .padding(16)
            .background(.black.opacity(0.38), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(highlight.opacity(0.45)))
        }
        .menuStyle(.borderlessButton)
        .frame(maxWidth: 580)
    }

    private var footer: some View {
        Text("peace through water")
            .font(.system(size: 9, design: .monospaced))
            .tracking(2)
            .foregroundStyle(.white.opacity(0.55))
    }

    private func icon(for name: String) -> String {
        switch name {
        case "Soft": "cloud.drizzle"
        case "Heavy": "cloud.heavyrain"
        case "Thunderstorm": "cloud.bolt.rain"
        default: "cloud.rain"
        }
    }

    private func timerLabel(_ minutes: Int) -> String {
        if minutes == 1 { return "1 minute" }
        if minutes == 60 { return "1 hour" }
        if minutes > 60 { return "\(minutes / 60) hours" }
        return "\(minutes) minutes"
    }
}
