import SwiftUI

struct NowPlayingIcon: View {
    var isPlaying: Bool

    var body: some View {
        Image(systemName: "chart.bar.xaxis")
            .symbolEffect(
                .variableColor.iterative.hideInactiveLayers.nonReversing,
                options: .repeat(.continuous),
                isActive: isPlaying
            )
            .foregroundStyle(.green.opacity(isPlaying ? 1 : 0.15))
            .font(.body)
            .frame(width: 24)
    }
}
