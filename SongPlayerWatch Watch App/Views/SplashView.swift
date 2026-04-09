import SwiftUI

/// Splash screen styled like a real iOS/watchOS app icon tile: a rounded
/// square with a gradient fill and the music note mark. Matches the Figma
/// splash and doubles as the app icon look.
struct SplashView: View {
    var onFinish: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            // Dark background matching the Figma splash.
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.04, blue: 0.08),
                    Color(red: 0.06, green: 0.10, blue: 0.18),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            iconTile
                .frame(width: 96, height: 96)
                .shadow(color: .black.opacity(0.5), radius: 12, y: 6)
                .scaleEffect(appeared ? 1.0 : 0.85)
                .opacity(appeared ? 1.0 : 0.0)
        }
        .task {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                appeared = true
            }
            try? await Task.sleep(for: .seconds(1.3))
            onFinish()
        }
    }

    /// An on-the-fly "app icon" tile. Gradient fill + glossy music note.
    private var iconTile: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.12, green: 0.18, blue: 0.32),
                        Color(red: 0.02, green: 0.05, blue: 0.12),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                // Subtle inner highlight to feel like a glossy icon.
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.25),
                                Color.white.opacity(0.0),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: 52, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, Color.white.opacity(0.65)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .white.opacity(0.25), radius: 4)
            )
    }
}
