import SwiftUI

public struct ProfileHeaderView: View {
    let user: InstagramUser
    let onAvatarTap: () -> Void

    public init(user: InstagramUser, onAvatarTap: @escaping () -> Void) {
        self.user = user
        self.onAvatarTap = onAvatarTap
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Riga Avatar e Statistiche
            HStack(spacing: 24) {
                Button(action: onAvatarTap) {
                    ZStack(alignment: .bottomTrailing) {
                        RemoteImageView(url: user.profilePicURLHD ?? user.profilePicURL)
                            .frame(width: 84, height: 84)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color(.separator), lineWidth: 1))

                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(5)
                            .background(Color.black.opacity(0.65), in: Circle())
                    }
                }
                .buttonStyle(.plain)

                HStack(spacing: 20) {
                    statColumn(title: "Post", value: formatCount(user.postsCount))
                    statColumn(title: "Follower", value: formatCount(user.followersCount))
                    statColumn(title: "Seguiti", value: formatCount(user.followingCount))
                }
                .frame(maxWidth: .infinity)
            }

            // Info Utente
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(user.fullName.isEmpty ? user.username : user.fullName)
                        .font(.headline)
                        .fontWeight(.bold)

                    if user.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }

                    if user.isPrivate {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if !user.biography.isEmpty {
                    Text(user.biography)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }

                if let extURL = user.externalURL {
                    Link(destination: extURL) {
                        HStack(spacing: 4) {
                            Image(systemName: "link")
                            Text(extURL.host ?? extURL.absoluteString)
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.accentColor)
                    }
                    .padding(.top, 2)
                }
            }

            // Tasti Azione Rapida
            HStack(spacing: 12) {
                Button(action: openInInstagram) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.right.square")
                        Text("Apri su Instagram")
                    }
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                }

                Button(action: onAvatarTap) {
                    HStack(spacing: 6) {
                        Image(systemName: "person.crop.circle")
                        Text("Foto Profilo HD")
                    }
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    private func statColumn(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 50)
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000.0)
        } else if count >= 10_000 {
            return String(format: "%.1fK", Double(count) / 1_000.0)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000.0)
        }
        return "\(count)"
    }

    private func openInInstagram() {
        if let appURL = URL(string: "instagram://user?username=\(user.username)"),
           UIApplication.shared.canOpenURL(appURL) {
            UIApplication.shared.open(appURL)
        } else if let webURL = URL(string: "https://www.instagram.com/\(user.username)/") {
            UIApplication.shared.open(webURL)
        }
    }
}
