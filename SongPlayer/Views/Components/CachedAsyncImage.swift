import SwiftUI
import UIKit

/// Drop-in replacement for AsyncImage that reads from MediaCacheService first
/// (so artwork is shown instantly and works offline) and downloads-then-caches
/// on a miss.
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    @ViewBuilder var content: (Image) -> Content
    @ViewBuilder var placeholder: () -> Placeholder

    @State private var uiImage: UIImage?
    @State private var didFail = false

    private let cache = MediaCacheService.shared

    var body: some View {
        Group {
            if let uiImage {
                content(Image(uiImage: uiImage))
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            await load()
        }
    }

    private func load() async {
        uiImage = nil
        didFail = false
        guard let url else { return }

        if let local = cache.localURL(for: url, kind: .image),
           let data = try? Data(contentsOf: local),
           let image = UIImage(data: data) {
            self.uiImage = image
            return
        }

        do {
            let local = try await cache.download(url, kind: .image)
            if Task.isCancelled { return }
            if let data = try? Data(contentsOf: local), let image = UIImage(data: data) {
                self.uiImage = image
            } else {
                didFail = true
            }
        } catch {
            didFail = true
        }
    }
}
