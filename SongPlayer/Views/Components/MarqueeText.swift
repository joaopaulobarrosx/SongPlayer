import SwiftUI

struct MarqueeText: View {
    let text: String
    let font: Font
    let fontWeight: Font.Weight
    let color: Color

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var offset: CGFloat = 0
    @State private var animating = false

    private var needsScroll: Bool {
        textWidth > containerWidth
    }

    var body: some View {
        GeometryReader { geo in
            let containerW = geo.size.width
            Text(text)
                .font(font)
                .fontWeight(fontWeight)
                .foregroundStyle(color)
                .fixedSize()
                .offset(x: offset)
                .onAppear {
                    containerWidth = containerW
                }
                .onChange(of: containerW) {
                    containerWidth = containerW
                }
                .background {
                    Text(text)
                        .font(font)
                        .fontWeight(fontWeight)
                        .fixedSize()
                        .hidden()
                        .background(GeometryReader { textGeo in
                            Color.clear.onAppear {
                                textWidth = textGeo.size.width
                                startAnimationIfNeeded()
                            }
                        })
                }
                .onChange(of: text) {
                    offset = 0
                    animating = false
                    Task {
                        try? await Task.sleep(for: .seconds(0.5))
                        textWidth = 0 // reset, will be recalculated
                    }
                }
        }
        .frame(height: 30)
        .clipped()
    }

    private func startAnimationIfNeeded() {
        guard needsScroll, !animating else { return }
        animating = true
        let scrollDistance = textWidth - containerWidth + 16

        Task { @MainActor in
            // Wait before starting
            try? await Task.sleep(for: .seconds(2))
            guard animating else { return }

            // Scroll left
            withAnimation(.linear(duration: Double(scrollDistance) / 30.0)) {
                offset = -scrollDistance
            }

            // Wait at the end
            try? await Task.sleep(for: .seconds(Double(scrollDistance) / 30.0 + 1.5))
            guard animating else { return }

            // Jump back
            withAnimation(.easeOut(duration: 0.3)) {
                offset = 0
            }

            try? await Task.sleep(for: .seconds(1))
            animating = false
            startAnimationIfNeeded()
        }
    }
}
