import SwiftUI

@MainActor
public final class ProfileViewModel: ObservableObject {
    public let username: String

    @Published public var user: InstagramUser?
    @Published public var posts: [InstagramPost] = []
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?
    @Published public var selectedPost: InstagramPost?
    @Published public var showHDAvatarSheet: Bool = false

    public init(username: String) {
        self.username = username
    }

    public func loadProfile() async {
        isLoading = true
        errorMessage = nil

        do {
            let cookies = SessionManager.shared.cookieHeader
            let csrf = SessionManager.shared.csrfToken
            let result = try await InstagramAPI.shared.fetchProfile(username: username, cookieHeader: cookies, csrfToken: csrf)
            self.user = result.user
            self.posts = result.posts
            self.isLoading = false
        } catch {
            self.isLoading = false
            self.errorMessage = error.localizedDescription
        }
    }
}

public struct ProfileView: View {
    @StateObject private var viewModel: ProfileViewModel

    public init(username: String) {
        _viewModel = StateObject(wrappedValue: ProfileViewModel(username: username))
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if let user = viewModel.user {
                    ProfileHeaderView(
                        user: user,
                        onAvatarTap: { viewModel.showHDAvatarSheet = true }
                    )

                    Divider()
                        .padding(.vertical, 8)

                    if user.isPrivate && viewModel.posts.isEmpty {
                        privateAccountPlaceholder
                    } else if viewModel.posts.isEmpty {
                        emptyPostsPlaceholder
                    } else {
                        PostGridView(posts: viewModel.posts) { post in
                            viewModel.selectedPost = post
                        }
                    }
                } else if viewModel.isLoading {
                    ProgressView("Caricamento profilo...")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                } else if let error = viewModel.errorMessage {
                    errorPlaceholder(message: error)
                }
            }
        }
        .navigationTitle(viewModel.username)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await viewModel.loadProfile()
        }
        .task {
            if viewModel.user == nil {
                await viewModel.loadProfile()
            }
        }
        .sheet(item: $viewModel.selectedPost) { post in
            NavigationStack {
                PostDetailView(post: post)
            }
        }
        .sheet(isPresented: $viewModel.showHDAvatarSheet) {
            if let user = viewModel.user {
                HDAvatarView(user: user)
            }
        }
    }

    private var privateAccountPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.circle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("Questo account è privato")
                .font(.headline)

            Text("Segui questo profilo su Instagram per visualizzarne i post e le storie.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.vertical, 60)
    }

    private var emptyPostsPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera")
                .font(.system(size: 44))
                .foregroundColor(.secondary)

            Text("Ancora nessun post")
                .font(.headline)

            Text("Quando questo utente condividerà foto o video, appariranno qui.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 60)
    }

    private func errorPlaceholder(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.orange)

            Text("Impossibile caricare il profilo")
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button("Riprova") {
                Task {
                    await viewModel.loadProfile()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.top, 60)
    }
}

// MARK: - HD Avatar Modal View
private struct HDAvatarView: View {
    let user: InstagramUser
    @Environment(\.dismiss) private var dismiss
    @State private var toast: ToastMessage?
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer()

                    RemoteImageView(url: user.profilePicURLHD ?? user.profilePicURL, contentMode: .fit)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 2))
                        .padding(24)
                        .shadow(radius: 12)

                    Text("@\(user.username)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Spacer()

                    Button(action: saveAvatar) {
                        HStack(spacing: 8) {
                            if isSaving {
                                ProgressView()
                                    .tint(.black)
                            } else {
                                Image(systemName: "square.and.arrow.down")
                            }
                            Text("Salva Foto Profilo HD")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 32)
                    }
                    .padding(.bottom, 24)
                }

                if let toast = toast {
                    VStack {
                        ToastView(message: toast)
                            .padding(.top, 16)
                        Spacer()
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
    }

    private func saveAvatar() {
        guard let url = user.profilePicURLHD ?? user.profilePicURL else { return }
        isSaving = true

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let image = UIImage(data: data) else { return }
                try await RegramService.shared.saveImageToPhotos(image: image)
                await MainActor.run {
                    self.isSaving = false
                    self.toast = ToastMessage(title: "Foto profilo salvata nella galleria!", systemImage: "checkmark.circle.fill")
                }
            } catch {
                await MainActor.run {
                    self.isSaving = false
                    self.toast = ToastMessage(title: error.localizedDescription, systemImage: "xmark.circle")
                }
            }
        }
    }
}
