import SwiftUI

public struct PostGridView: View {
    let posts: [InstagramPost]
    let onSelectPost: (InstagramPost) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    public init(posts: [InstagramPost], onSelectPost: @escaping (InstagramPost) -> Void) {
        self.posts = posts
        self.onSelectPost = onSelectPost
    }

    public var body: some View {
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(posts) { post in
                Button(action: { onSelectPost(post) }) {
                    ZStack(alignment: .topTrailing) {
                        RemoteImageView(url: post.thumbnailURL)
                            .aspectRatio(1, contentMode: .fill)
                            .clipped()

                        // Badge Tipo Media
                        if post.mediaType == .carousel {
                            Image(systemName: "square.fill.on.square.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.6), radius: 3)
                                .padding(6)
                        } else if post.mediaType == .video {
                            Image(systemName: "play.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.6), radius: 3)
                                .padding(6)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}
