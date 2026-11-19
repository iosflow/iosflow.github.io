import SwiftUI

struct SleepTimerControl: View {
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
