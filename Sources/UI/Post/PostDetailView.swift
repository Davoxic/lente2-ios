import SwiftUI

public struct PostDetailView: View {
    let post: InstagramPost

    @Environment(\.dismiss) private var dismiss
    @StateObject private var regramService = RegramService.shared

    @State private var selectedMediaIndex = 0
    @State private var showRegramSheet = false
    @State private var isDownloading = false
    @State private var toast: ToastMessage?
    @State private var isCaptionExpanded = false

    public init(post: InstagramPost) {
        self.post = post
    }

    private var currentMediaItem: MediaItem {
        guard selectedMediaIndex < post.mediaItems.count else {
            return post.mediaItems.first ?? MediaItem(displayURL: post.thumbnailURL ?? URL(string: "about:blank")!)
        }
        return post.mediaItems[selectedMediaIndex]
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Header Autore
                HStack(spacing: 12) {
                    RemoteImageView(url: post.author.profilePicURL)
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(post.author.username)
                                .font(.subheadline)
                                .fontWeight(.bold)

                            if post.author.isVerified {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                            }
                        }

                        if let date = post.takenAt {
                            Text(formattedDate(date))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    Menu {
                        Button(action: copyLink) {
                            Label("Copia link post", systemImage: "link")
                        }
                        Button(action: openInInstagram) {
                            Label("Apri nell'app Instagram", systemImage: "arrow.up.right.square")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(8)
                    }
                }
                .padding(.horizontal)

                // Visualizzatore Media (Foto, Carosello o Video)
                MediaPagingView(
                    mediaItems: post.mediaItems,
                    selectedIndex: $selectedMediaIndex
                )

                // Barra Strumenti Regram & Download
                HStack(spacing: 12) {
                    // Tasto Regram
                    Button(action: { showRegramSheet = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Regram")
                                .fontWeight(.bold)
                        }
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 10))
                    }

                    // Tasto Salva in Galleria
                    Button(action: downloadCurrentMedia) {
                        HStack(spacing: 6) {
                            if isDownloading {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.down.circle.fill")
                            }
                            Text("Salva")
                                .fontWeight(.semibold)
                        }
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                    }

                    // Tasto Copia Testo
                    Button(action: copyCaption) {
                        Image(systemName: "doc.on.doc")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                    }

                    Spacer()

                    // Indicatore Mi Piace
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                        Text("\(post.likesCount)")
                            .font(.footnote)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)

                // Didascalia
                if !post.caption.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .top) {
                            Text(post.author.username)
                                .fontWeight(.bold) +
                            Text(" ") +
                            Text(post.caption)
                        }
                        .font(.subheadline)
                        .lineLimit(isCaptionExpanded ? nil : 3)

                        if post.caption.count > 120 {
                            Button(action: { isCaptionExpanded.toggle() }) {
                                Text(isCaptionExpanded ? "Mostra meno" : "Altro...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Chiudi") { dismiss() }
            }
        }
        .sheet(isPresented: $showRegramSheet) {
            RegramSheetView(post: post, currentMediaItem: currentMediaItem)
        }
        .overlay(alignment: .top) {
            if let toast = toast {
                ToastView(message: toast)
                    .padding(.top, 12)
            }
        }
    }

    private func downloadCurrentMedia() {
        guard !isDownloading else { return }
        isDownloading = true

        Task {
            do {
                try await regramService.downloadAndSaveMedia(item: currentMediaItem)
                await MainActor.run {
                    self.isDownloading = false
                    self.toast = ToastMessage(
                        title: currentMediaItem.isVideo ? "Video salvato nelle Foto!" : "Immagine salvata nelle Foto!",
                        systemImage: "checkmark.circle.fill"
                    )
                }
            } catch {
                await MainActor.run {
                    self.isDownloading = false
                    self.toast = ToastMessage(title: error.localizedDescription, systemImage: "xmark.circle")
                }
            }
        }
    }

    private func copyCaption() {
        regramService.copyCaption(caption: post.caption)
        toast = ToastMessage(title: "Didascalia copiata negli appunti!", systemImage: "doc.on.doc.fill")
    }

    private func copyLink() {
        regramService.copyLink(url: post.shareURL)
        toast = ToastMessage(title: "Link post copiato!", systemImage: "link")
    }

    private func openInInstagram() {
        let url = URL(string: "instagram://media?id=\(post.id)") ?? post.shareURL
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            UIApplication.shared.open(post.shareURL)
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
