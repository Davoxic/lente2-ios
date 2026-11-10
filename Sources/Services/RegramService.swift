import Foundation
import UIKit
import Photos

public enum WatermarkPosition: String, CaseIterable, Identifiable {
    case bottomLeft = "In basso a sinistra"
    case bottomRight = "In basso a destra"
    case topLeft = "In alto a sinistra"
    case topRight = "In alto a destra"
    case none = "Nessun watermark"

    public var id: String { rawValue }
}

public enum RegramError: LocalizedError {
    case photoLibraryPermissionDenied
    case mediaDownloadFailed
    case videoSaveFailed
    case imageRenderFailed

    public var errorDescription: String? {
        switch self {
        case .photoLibraryPermissionDenied:
            return "Permesso negato: abilita l'accesso alla Libreria Foto nelle Impostazioni di iOS per salvare i media."
        case .mediaDownloadFailed:
            return "Impossibile scaricare il media dall'URL fornito."
        case .videoSaveFailed:
            return "Impossibile salvare il video nella galleria."
        case .imageRenderFailed:
            return "Impossibile generare l'immagine con il banner di repost."
        }
    }
}

@MainActor
public final class RegramService: ObservableObject {
    public static let shared = RegramService()

    @Published public var defaultWatermarkPosition: WatermarkPosition = .bottomLeft
    @Published public var includeCaptionInRegram: Bool = true
    @Published public var autoSaveOnRegram: Bool = false

    private init() {}

    // MARK: - Photo Library Permission
    public func requestPhotoAccess() async -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch status {
        case .authorized, .limited:
            return true
        case .notDetermined:
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            return newStatus == .authorized || newStatus == .limited
        default:
            return false
        }
    }

    // MARK: - Download & Save to Camera Roll
    public func saveImageToPhotos(image: UIImage) async throws {
        guard await requestPhotoAccess() else {
            throw RegramError.photoLibraryPermissionDenied
        }

        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }
    }

    public func downloadAndSaveMedia(item: MediaItem) async throws {
        guard await requestPhotoAccess() else {
            throw RegramError.photoLibraryPermissionDenied
        }

        if item.isVideo, let videoURL = item.videoURL {
            let (tempURL, _) = try await URLSession.shared.download(from: videoURL)
            let destinationURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
            try? FileManager.default.removeItem(at: destinationURL)
            try FileManager.default.moveItem(at: tempURL, to: destinationURL)

            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: destinationURL)
            }
            try? FileManager.default.removeItem(at: destinationURL)
        } else {
            let (data, _) = try await URLSession.shared.data(from: item.displayURL)
            guard let image = UIImage(data: data) else {
                throw RegramError.mediaDownloadFailed
            }
            try await saveImageToPhotos(image: image)
        }
    }

    // MARK: - Regram Watermark Generation
    public func generateRegramImage(
        originalImage: UIImage,
        authorUsername: String,
        position: WatermarkPosition = .bottomLeft
    ) -> UIImage {
        if position == .none {
            return originalImage
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = originalImage.scale
        let renderer = UIGraphicsImageRenderer(size: originalImage.size, format: format)

        return renderer.image { context in
            // Disegna l'immagine originale
            originalImage.draw(in: CGRect(origin: .zero, size: originalImage.size))

            // Configurazione Badge Repost
            let scaleFactor = max(originalImage.size.width / 1080.0, 1.0)
            let badgeFontSize = 24.0 * scaleFactor
            let font = UIFont.systemFont(ofSize: badgeFontSize, weight: .semibold)
            let text = "⟲ @\(authorUsername)"

            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.white
            ]
            let textSize = (text as NSString).size(withAttributes: attributes)

            let hPadding = 18.0 * scaleFactor
            let vPadding = 10.0 * scaleFactor
            let badgeWidth = textSize.width + (hPadding * 2)
            let badgeHeight = textSize.height + (vPadding * 2)
            let margin = 24.0 * scaleFactor

            var originX: CGFloat = margin
            var originY: CGFloat = margin

            switch position {
            case .bottomLeft:
                originX = margin
                originY = originalImage.size.height - badgeHeight - margin
            case .bottomRight:
                originX = originalImage.size.width - badgeWidth - margin
                originY = originalImage.size.height - badgeHeight - margin
            case .topLeft:
                originX = margin
                originY = margin
            case .topRight:
                originX = originalImage.size.width - badgeWidth - margin
                originY = margin
            case .none:
                break
            }

            let badgeRect = CGRect(x: originX, y: originY, width: badgeWidth, height: badgeHeight)
            let path = UIBezierPath(roundedRect: badgeRect, cornerRadius: 10.0 * scaleFactor)

            // Sfondo badge nero semitrasparente elegante
            UIColor(white: 0.0, alpha: 0.75).setFill()
            path.fill()

            // Disegna testo
            let textRect = CGRect(
                x: originX + hPadding,
                y: originY + vPadding,
                width: textSize.width,
                height: textSize.height
            )
            (text as NSString).draw(in: textRect, withAttributes: attributes)
        }
    }

    // MARK: - Regram Caption Generator
    public func formattedRegramCaption(originalCaption: String, authorUsername: String) -> String {
        var result = "Repost @\(authorUsername)"
        if !originalCaption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            result += "\n───\n\(originalCaption)"
        }
        result += "\n\n#regram #lente"
        return result
    }

    // MARK: - Clipboard Helpers
    public func copyCaption(caption: String) {
        UIPasteboard.general.string = caption
    }

    public func copyLink(url: URL) {
        UIPasteboard.general.url = url
    }
}
