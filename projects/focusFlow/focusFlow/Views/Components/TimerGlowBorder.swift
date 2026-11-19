import SwiftUI

struct TimerGlowBorder: View {
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
