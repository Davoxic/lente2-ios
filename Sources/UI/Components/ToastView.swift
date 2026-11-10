import SwiftUI

public struct ToastMessage: Identifiable, Equatable {
    public let id = UUID()
    public let title: String
    public let systemImage: String?

    public init(title: String, systemImage: String? = nil) {
        self.title = title
        self.systemImage = systemImage
    }
}

public struct ToastView: View {
    let message: ToastMessage

    public var body: some View {
        HStack(spacing: 12) {
            if let icon = message.systemImage {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            Text(message.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.85))
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, 24)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
