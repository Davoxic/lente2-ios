import SwiftUI
import WebKit

public struct InstagramLoginView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var sessionManager = SessionManager.shared

    @State private var isLoading = true
    @State private var webView = WKWebView()

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                WebViewRepresentable(
                    webView: webView,
                    isLoading: $isLoading,
                    onLoginSuccess: { cookies, username in
                        sessionManager.updateSession(cookies: cookies, username: username)
                        dismiss()
                    }
                )

                if isLoading {
                    ProgressView("Caricamento pagina di login...")
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .navigationTitle("Accesso Instagram")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        webView.reload()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }
}

private struct WebViewRepresentable: UIViewRepresentable {
    let webView: WKWebView
    @Binding var isLoading: Bool
    let onLoginSuccess: ([HTTPCookie], String?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1"

        if let url = URL(string: "https://www.instagram.com/accounts/login/") {
            let request = URLRequest(url: url)
            webView.load(request)
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebViewRepresentable
        var checkTimer: Timer?

        init(_ parent: WebViewRepresentable) {
            self.parent = parent
            super.init()
            startCookiePolling()
        }

        deinit {
            checkTimer?.invalidate()
        }

        private func startCookiePolling() {
            checkTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
                self?.inspectCookies()
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = true
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
            inspectCookies()
        }

        private func inspectCookies() {
            let store = parent.webView.configuration.websiteDataStore.httpCookieStore
            store.getAllCookies { [weak self] cookies in
                guard let self = self else { return }
                let hasSession = cookies.contains { $0.name == "sessionid" && !$0.value.isEmpty }
                let hasUserID = cookies.contains { $0.name == "ds_user_id" && !$0.value.isEmpty }

                if hasSession && hasUserID {
                    self.checkTimer?.invalidate()
                    self.checkTimer = nil

                    // Prova a recuperare lo username da un cookie o via JS
                    self.parent.webView.evaluateJavaScript("window._sharedData?.config?.viewer?.username || document.cookie") { result, _ in
                        var detectedUsername: String? = nil
                        if let resStr = result as? String, !resStr.contains("=") {
                            detectedUsername = resStr
                        }
                        DispatchQueue.main.async {
                            self.parent.onLoginSuccess(cookies, detectedUsername)
                        }
                    }
                }
            }
        }
    }
}
