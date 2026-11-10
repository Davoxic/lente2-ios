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

    public func onSearchTextChanged(to query: String) {
        searchTask?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000) // Debounce 350ms
            if Task.isCancelled { return }

            isSearching = true
            errorMessage = nil

            do {
                let cookies = SessionManager.shared.cookieHeader
                let users = try await InstagramAPI.shared.searchUsers(query: trimmed, cookieHeader: cookies)
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
            Group {
                if !sessionManager.isLoggedIn && viewModel.searchResults.isEmpty && viewModel.recentSearches.isEmpty && viewModel.searchText.isEmpty {
                    notLoggedInHero
                } else if viewModel.isSearching && viewModel.searchResults.isEmpty {
                    ProgressView("Ricerca in corso...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !viewModel.searchResults.isEmpty {
                    searchResultsList
                } else if !viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    emptySearchResults
                } else {
                    recentsView
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
                        .fontWeight(.semibold)
                    }
                }
            }
            .sheet(isPresented: $showLoginSheet) {
                InstagramLoginView()
            }
        }
    }

    private var notLoggedInHero: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)

            Text("Ricerca Diretta Instagram")
                .font(.title2)
                .fontWeight(.bold)

            Text("Cerca qualsiasi profilo, visualizza i contenuti in alta definizione e salva o fai il regram dei post senza doomscrolling.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button(action: { showLoginSheet = true }) {
                HStack {
                    Image(systemName: "person.crop.circle.badge.plus")
                    Text("Accedi con Instagram")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 32)
            }

            Text("L'accesso avviene tramite WebView sicuro. Nessun dato lascia il tuo iPhone.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var searchResultsList: some View {
        List {
            ForEach(viewModel.searchResults) { user in
                NavigationLink(destination: ProfileView(username: user.username)) {
                    UserRowView(user: user)
                }
                .simultaneousGesture(TapGesture().onEnded {
                    viewModel.addToRecents(user: user)
                })
            }
        }
        .listStyle(.insetGrouped)
    }

    private var emptySearchResults: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.slash")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text("Nessun profilo trovato")
                .font(.headline)

            Text("Prova a verificare l'esatta ortografia dello username.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

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
                        Text("Recenti")
                        Spacer()
                        Button("Cancella tutto") {
                            viewModel.clearRecents()
                        }
                        .font(.caption)
                        .textCase(.none)
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)

                    Text("Cerca un profilo")
                        .font(.headline)

                    Text("Digita uno username nella barra in alto per esplorare profili e media.")
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
