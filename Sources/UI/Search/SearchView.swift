import SwiftUI

@MainActor
public final class SearchViewModel: ObservableObject {
    @Published public var searchText: String = ""
    @Published public var searchResults: [InstagramUserMini] = []
    @Published public var recentSearches: [SearchHistoryItem] = []
    @Published public var isSearching: Bool = false
    @Published public var errorMessage: String?

    private var searchTask: Task<Void, Never>?
    private let recentKey = "com.lente.recentSearches"

    public init() {
        loadRecents()
    }

    public var cleanQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "@"))
    }

    public func onSearchTextChanged(to query: String) {
        searchTask?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "@"))

        guard !trimmed.isEmpty else {
            searchResults = []
            isSearching = false
            errorMessage = nil
            return
        }

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000) // Debounce 350ms
            if Task.isCancelled { return }

            isSearching = true
            errorMessage = nil

            do {
                let cookies = SessionManager.shared.cookieHeader
                let csrf = SessionManager.shared.csrfToken
                let users = try await InstagramAPI.shared.searchUsers(query: trimmed, cookieHeader: cookies, csrfToken: csrf)
                if !Task.isCancelled {
                    self.searchResults = users
                    self.isSearching = false
                }
            } catch {
                if !Task.isCancelled {
                    self.isSearching = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    public func addToRecents(user: InstagramUserMini) {
        recentSearches.removeAll { $0.username.lowercased() == user.username.lowercased() }
        recentSearches.insert(SearchHistoryItem(user: user), at: 0)
        if recentSearches.count > 20 {
            recentSearches = Array(recentSearches.prefix(20))
        }
        saveRecents()
    }

    public func removeRecent(item: SearchHistoryItem) {
        recentSearches.removeAll { $0.id == item.id }
        saveRecents()
    }

    public func clearRecents() {
        recentSearches.removeAll()
        saveRecents()
    }

    private func saveRecents() {
        if let data = try? JSONEncoder().encode(recentSearches) {
            UserDefaults.standard.set(data, forKey: recentKey)
        }
    }

    private func loadRecents() {
        if let data = UserDefaults.standard.data(forKey: recentKey),
           let items = try? JSONDecoder().decode([SearchHistoryItem].self, from: data) {
            self.recentSearches = items
        }
    }
}

public struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @ObservedObject private var sessionManager = SessionManager.shared
    @State private var showLoginSheet = false

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Barra di avviso se non loggato
                if !sessionManager.isLoggedIn {
                    notLoggedInBanner
                }

                Group {
                    if viewModel.isSearching && viewModel.searchResults.isEmpty {
                        ProgressView("Ricerca in corso...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if !viewModel.cleanQuery.isEmpty {
                        queryResultsView
                    } else {
                        recentsView
                    }
                }
            }
            .navigationTitle("Cerca")
            .searchable(
                text: $viewModel.searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Cerca profilo (@username o nome)"
            )
            .onChange(of: viewModel.searchText) { newValue in
                viewModel.onSearchTextChanged(to: newValue)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if !sessionManager.isLoggedIn {
                        Button("Accedi") {
                            showLoginSheet = true
                        }
                        .fontWeight(.bold)
                    }
                }
            }
            .sheet(isPresented: $showLoginSheet) {
                InstagramLoginView()
            }
        }
    }

    // MARK: - Banner Non Connesso
    private var notLoggedInBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text("Accesso Instagram richiesto")
                    .font(.footnote)
                    .fontWeight(.bold)
                Text("Per cercare e visualizzare i profili, esegui il login.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Accedi") {
                showLoginSheet = true
            }
            .font(.footnote)
            .fontWeight(.semibold)
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - Risultati Query
    private var queryResultsView: some View {
        List {
            // Tasto rapido sempre visibile: Apri direttamente il profilo digitato
            Section {
                NavigationLink(destination: ProfileView(username: viewModel.cleanQuery)) {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title3)
                            .foregroundColor(.accentColor)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Apri profilo @\(viewModel.cleanQuery)")
                                .font(.body)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)

                            Text("Visualizza direttamente post, foto e regram")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("Accesso Diretto")
            }

            // Mostra eventuale errore di rete/sessione
            if let error = viewModel.errorMessage {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.orange)
                            Text("Stato ricerca")
                                .font(.footnote)
                                .fontWeight(.bold)
                        }
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if !sessionManager.isLoggedIn {
                            Button("Esegui il Login con Instagram") {
                                showLoginSheet = true
                            }
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.top, 4)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }

            // Risultati Suggeriti
            if !viewModel.searchResults.isEmpty {
                Section(header: Text("Profili Trovati")) {
                    ForEach(viewModel.searchResults) { user in
                        NavigationLink(destination: ProfileView(username: user.username)) {
                            UserRowView(user: user)
                        }
                        .simultaneousGesture(TapGesture().onEnded {
                            viewModel.addToRecents(user: user)
                        })
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Recenti & Schermata Iniziale
    private var recentsView: some View {
        List {
            if !viewModel.recentSearches.isEmpty {
                Section {
                    ForEach(viewModel.recentSearches) { item in
                        NavigationLink(destination: ProfileView(username: item.username)) {
                            UserRowView(user: InstagramUserMini(
                                id: item.id,
                                username: item.username,
                                fullName: item.fullName,
                                profilePicURL: item.profilePicURL,
                                isVerified: item.isVerified
                            ))
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                viewModel.removeRecent(item: item)
                            } label: {
                                Label("Elimina", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Ricerche Recenti")
                        Spacer()
                        Button("Cancella tutto") {
                            viewModel.clearRecents()
                        }
                        .font(.caption)
                        .textCase(.none)
                    }
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 44))
                        .foregroundColor(.secondary)

                    Text("Cerca un profilo")
                        .font(.headline)

                    Text("Digita qualsiasi @username nella barra in alto per cercare profili o aprirli direttamente.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
    }
}
