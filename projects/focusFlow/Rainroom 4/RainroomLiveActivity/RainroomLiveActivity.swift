import ActivityKit
import SwiftUI
import WidgetKit

struct RainSleepTimerAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let endDate: Date
        let timerTitle: String
        let timerStyle: String

        var accentColor: Color {
            switch timerStyle {
            case "focus":
                Color(red: 0.64, green: 1, blue: 0.12)
            case "break":
                Color(red: 1, green: 0.2, blue: 0.24)
            default:
                .blue
            }
        }
    }

    let texture: String
}

struct RainroomLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RainSleepTimerAttributes.self) { context in
            RainSleepTimerLockScreenView(
                texture: context.attributes.texture,
                endDate: context.state.endDate,
                timerTitle: context.state.timerTitle,
                accentColor: context.state.accentColor
            )
            .activityBackgroundTint(Color(red: 0.04, green: 0.12, blue: 0.16))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "moon.zzz.fill")
                        .foregroundStyle(context.state.accentColor)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.timerTitle)
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: Date.now...context.state.endDate, countsDown: true)
                        .monospacedDigit()
                        .foregroundStyle(context.state.accentColor)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Image(systemName: "moon.zzz.fill")
                        Text(context.state.timerTitle)
                        Spacer()
                        Text(context.state.endDate, style: .time)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "cloud.rain.fill")
                    .foregroundStyle(context.state.accentColor)
            } compactTrailing: {
                Text(timerInterval: Date.now...context.state.endDate, countsDown: true)
                    .monospacedDigit()
                    .foregroundStyle(context.state.accentColor)
                    .frame(width: 44)
            } minimal: {
                Image(systemName: "moon.zzz.fill")
                    .foregroundStyle(context.state.accentColor)
            }
            .keylineTint(context.state.accentColor)
        }
    }
}

private struct RainSleepTimerLockScreenView: View {
    let texture: String
    let endDate: Date
    let timerTitle: String
    let accentColor: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "cloud.rain.fill")
                .font(.title2)
                .foregroundStyle(accentColor)

            VStack(alignment: .leading, spacing: 3) {
                Text("\(texture) rain")
                    .font(.headline)
                Text(timerTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(timerInterval: Date.now...endDate, countsDown: true)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(accentColor)
        }
        .padding()
    }
}
