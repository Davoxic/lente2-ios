import SwiftUI
import UIKit

public struct RegramSheetView: View {
    let post: InstagramPost
    let currentMediaItem: MediaItem

    @Environment(\.dismiss) private var dismiss
    @StateObject private var regramService = RegramService.shared

    @State private var watermarkPosition: WatermarkPosition = .bottomLeft
    @State private var includeCaption: Bool = true
    @State private var captionText: String = ""
    @State private var renderedImage: UIImage?
    @State private var originalLoadedImage: UIImage?
    @State private var isProcessing = false
    @State private var toast: ToastMessage?
    @State private var showShareSheet = false

    public init(post: InstagramPost, currentMediaItem: MediaItem) {
        self.post = post
        self.currentMediaItem = currentMediaItem
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Anteprima Immagine con Watermark
                    ZStack {
                        if let preview = renderedImage {
                            Image(uiImage: preview)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(color: .black.opacity(0.15), radius: 8)
                        } else if isProcessing {
                            ProgressView("Elaborazione Regram...")
                                .frame(height: 300)
                        } else {
                            RemoteImageView(url: currentMediaItem.displayURL, contentMode: .fit)
                                .frame(height: 300)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal)

                    // Selettore Posizione Watermark
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Posizione Badge Autore")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)

                        Picker("Posizione Watermark", selection: $watermarkPosition) {
                            ForEach(WatermarkPosition.allCases) { pos in
                                Text(pos.rawValue).tag(pos)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 12)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                    }
                    .padding(.horizontal)
                    .onChange(of: watermarkPosition) { _ in
                        updateRenderedImage()
                    }

                    // Sezione Didascalia
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Includi didascalia con attribuzione", isOn: $includeCaption)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .onChange(of: includeCaption) { enabled in
                                if enabled {
                                    captionText = regramService.formattedRegramCaption(
                                        originalCaption: post.caption,
                                        authorUsername: post.author.username
                                    )
                                } else {
                                    captionText = "Repost @\(post.author.username)"
                                }
                            }

                        TextEditor(text: $captionText)
                            .frame(height: 100)
                            .padding(8)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                            .font(.footnote)
                    }
                    .padding(.horizontal)

                    // Azioni Principali
                    VStack(spacing: 12) {
                        Button(action: shareRegram) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Condividi / Ripubblica")
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))
                        }

                        Button(action: saveToPhotos) {
                            HStack(spacing: 8) {
                                Image(systemName: "photo.badge.arrow.down")
                                Text("Salva nelle Foto")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                .padding(.vertical)
            }
            .navigationTitle("Regram Studio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                }
            }
            .task {
                captionText = regramService.formattedRegramCaption(
                    originalCaption: post.caption,
                    authorUsername: post.author.username
                )
                await loadOriginalImage()
            }
            .overlay(alignment: .top) {
                if let toast = toast {
                    ToastView(message: toast)
                        .padding(.top, 12)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let img = renderedImage {
                    ShareActivityView(activityItems: [img, captionText])
                }
            }
        }
    }

    private func loadOriginalImage() async {
        isProcessing = true
        defer { isProcessing = false }

        do {
            let (data, _) = try await URLSession.shared.data(from: currentMediaItem.displayURL)
            if let img = UIImage(data: data) {
                self.originalLoadedImage = img
                updateRenderedImage()
            }
        } catch {
            toast = ToastMessage(title: "Impossibile scaricare l'immagine originale", systemImage: "xmark.circle")
        }
    }

    private func updateRenderedImage() {
        guard let original = originalLoadedImage else { return }
        self.renderedImage = regramService.generateRegramImage(
            originalImage: original,
            authorUsername: post.author.username,
            position: watermarkPosition
        )
    }

    private func saveToPhotos() {
        guard let img = renderedImage else { return }
        Task {
            do {
                try await regramService.saveImageToPhotos(image: img)
                toast = ToastMessage(title: "Regram salvato nella galleria!", systemImage: "checkmark.circle.fill")
            } catch {
                toast = ToastMessage(title: error.localizedDescription, systemImage: "xmark.circle")
            }
        }
    }

    private func shareRegram() {
        guard renderedImage != nil else { return }
        // Copia anche il testo nella clipboard per comodità durante l'incolla su Instagram
        regramService.copyCaption(caption: captionText)
        showShareSheet = true
    }
}

// Wrapper UIKit UIActivityViewController
private struct ShareActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
