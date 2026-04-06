import SwiftUI

struct NowPlayingIcon: View {
    var isPlaying: Bool

    var body: some View {
        Image(systemName: "chart.bar.xaxis")
            .symbolEffect(.variableColor.iterative, options: .repeating, isActive: isPlaying)
            .foregroundStyle(.green)
            .font(.body)
            .frame(width: 24)
    }
}
