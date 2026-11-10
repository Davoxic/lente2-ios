import SwiftUI
import AVKit

public struct VideoPlayerView: View {
    let url: URL

    @State private var player: AVPlayer?
    @State private var isPlaying = true
    @State private var isMuted = false

    public init(url: URL) {
        self.url = url
    }

    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let player = player {
                VideoPlayer(player: player)
                    .aspectRatio(1, contentMode: .fit)
                    .onTapGesture {
                        if isPlaying {
                            player.pause()
                            isPlaying = false
                        } else {
                            player.play()
                            isPlaying = true
                        }
                    }
            } else {
                ProgressView()
                    .aspectRatio(1, contentMode: .fit)
            }

            // Pulsante Mute/Unmute
            Button(action: toggleMute) {
                Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.footnote)
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.black.opacity(0.65), in: Circle())
            }
            .padding(12)
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
        }
    }

    private func setupPlayer() {
        let p = AVPlayer(url: url)
        p.isMuted = isMuted
        p.actionAtItemEnd = .none

        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: p.currentItem,
            queue: .main
        ) { _ in
            p.seek(to: .zero)
            p.play()
        }

        self.player = p
        p.play()
        self.isPlaying = true
    }

    private func toggleMute() {
        isMuted.toggle()
        player?.isMuted = isMuted
    }
}
