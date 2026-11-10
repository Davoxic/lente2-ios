import SwiftUI

public struct UserRowView: View {
    let user: InstagramUserMini

    public init(user: InstagramUserMini) {
        self.user = user
    }

    public var body: some View {
        HStack(spacing: 12) {
            RemoteImageView(url: user.profilePicURL)
                .frame(width: 48, height: 48)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color(.separator), lineWidth: 0.5))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(user.username)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    if user.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }

                    if user.isPrivate {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                if !user.fullName.isEmpty {
                    Text(user.fullName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote)
                .foregroundColor(Color(.tertiaryLabel))
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
