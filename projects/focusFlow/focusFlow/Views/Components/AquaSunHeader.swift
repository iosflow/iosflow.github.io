import SwiftUI

struct AquaSunHeader: View {
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
