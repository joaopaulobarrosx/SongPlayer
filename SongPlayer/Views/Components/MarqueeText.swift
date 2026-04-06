import SwiftUI

private struct TextWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct MarqueeText: View {
    let text: String
    let font: Font
    let fontWeight: Font.Weight
    let color: Color

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var offset: CGFloat = 0
    @State private var animationTask: Task<Void, Never>?

    private var overflows: Bool {
        containerWidth > 0 && textWidth > containerWidth
    }

    var body: some View {
        GeometryReader { geo in
            styledText
                .fixedSize(horizontal: true, vertical: false)
                .offset(x: offset)
                // Measure text natural width
                .background(
                    styledText
                        .fixedSize(horizontal: true, vertical: false)
                        .hidden()
                        .overlay(GeometryReader { textGeo in
                            Color.clear.preference(
                                key: TextWidthKey.self,
                                value: textGeo.size.width
                            )
                        })
                )
                .onPreferenceChange(TextWidthKey.self) { width in
                    textWidth = width
                    containerWidth = geo.size.width
                    scheduleAnimation()
                }
                .onAppear {
                    containerWidth = geo.size.width
                }
                .onChange(of: text) {
                    offset = 0
                    animationTask?.cancel()
                    animationTask = nil
                    scheduleAnimation()
                }
        }
        .frame(height: 34)
        .clipped()
    }

    private var styledText: some View {
        Text(text)
            .font(font)
            .fontWeight(fontWeight)
            .foregroundStyle(color)
            .lineLimit(1)
    }

    private func scheduleAnimation() {
        animationTask?.cancel()
        guard overflows else { return }

        let scrollDistance = textWidth - containerWidth + 8

        animationTask = Task { @MainActor in
            // Initial pause before first scroll
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled, overflows else { return }

            while !Task.isCancelled {
                // Scroll left
                let duration = max(3.0, Double(scrollDistance) / 40.0)
                withAnimation(.linear(duration: duration)) {
                    offset = -scrollDistance
                }
                try? await Task.sleep(for: .seconds(duration + 1.0))
                guard !Task.isCancelled else { break }

                // Snap back instantly then pause
                withAnimation(.easeIn(duration: 0.4)) {
                    offset = 0
                }
                try? await Task.sleep(for: .seconds(2.0))
            }
        }
    }
}
