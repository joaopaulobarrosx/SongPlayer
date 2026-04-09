import SwiftUI

/// Slim banner shown at the top of the app whenever the reachability probe
/// reports no internet. Auto-hides as soon as connectivity comes back.
struct OfflineBanner: View {
    @Bindable var reachability: ReachabilityService

    var body: some View {
        if !reachability.isOnline {
            HStack(spacing: 6) {
                Image(systemName: "wifi.slash")
                    .font(.caption2)
                Text("Sem conexão com a internet")
                    .font(.caption2)
                Spacer()
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemBackground))
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
