import SwiftUI

public struct RootView: View {
    @State private var selectedTab = 0

    public init() {}

    public var body: some View {
        TabView(selection: $selectedTab) {
            SearchView()
                .tabItem {
                    Label("Cerca", systemImage: "magnifyingglass")
                }
                .tag(0)

            SettingsView()
                .tabItem {
                    Label("Impostazioni", systemImage: "gearshape")
                }
                .tag(1)
        }
        .tint(.accentColor)
    }
}
