import SwiftUI

public struct MediaPagingView: View {
    let mediaItems: [MediaItem]
    @Binding var selectedIndex: Int

    public init(mediaItems: [MediaItem], selectedIndex: Binding<Int>) {
        self.mediaItems = mediaItems
        self._selectedIndex = selectedIndex
    }

    public var body: some View {
        if mediaItems.count == 1, let item = mediaItems.first {
            mediaView(for: item)
        } else {
            TabView(selection: $selectedIndex) {
                ForEach(Array(mediaItems.enumerated()), id: \.element.id) { index, item in
                    mediaView(for: item)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .interactive))
            .aspectRatio(1, contentMode: .fit)
        }
    }

    @ViewBuilder
    private func mediaView(for item: MediaItem) -> some View {
        if item.isVideo, let videoURL = item.videoURL {
            VideoPlayerView(url: videoURL)
        } else {
            RemoteImageView(url: item.displayURL, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .background(Color.black.opacity(0.04))
        }
    }
}
