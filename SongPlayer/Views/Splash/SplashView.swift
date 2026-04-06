import SwiftUI

struct SplashView: View {
    @State private var isActive = false
    @State private var opacity: Double = 0

    var body: some View {
        if isActive {
            MainTabView()
        } else {
            Image(.splash)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .opacity(opacity)
                .task {
                    withAnimation(.easeIn(duration: 0.6)) {
                        opacity = 1
                    }
                    try? await Task.sleep(for: .seconds(1.5))
                    withAnimation(.easeOut(duration: 0.3)) {
                        isActive = true
                    }
                }
        }
    }
}
