import SwiftUI

public struct RemoteImageView: View {
    let url: URL?
    var contentMode: ContentMode = .fill

    @State private var loadedImage: UIImage?
    @State private var isLoading = false

    private static let cache = NSCache<NSURL, UIImage>()

    public init(url: URL?, contentMode: ContentMode = .fill) {
        self.url = url
        self.contentMode = contentMode
    }

    public var body: some View {
        Group {
            if let image = loadedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if isLoading {
                ZStack {
                    Color(.secondarySystemBackground)
                    ProgressView()
                }
            } else {
                ZStack {
                    Color(.secondarySystemBackground)
                    Image(systemName: "photo")
                        .foregroundColor(.secondary)
                }
            }
        }
        .task(id: url) {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let url = url else { return }
        let nsURL = url as NSURL

        if let cached = Self.cache.object(forKey: nsURL) {
            self.loadedImage = cached
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let img = UIImage(data: data) {
                Self.cache.setObject(img, forKey: nsURL)
                self.loadedImage = img
            }
        } catch {
            // Placeholder shown
        }
    }
}
