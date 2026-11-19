import ActivityKit

enum LiveActivityCleanup {
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
