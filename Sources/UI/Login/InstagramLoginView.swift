import SwiftUI
import WebKit

public struct InstagramLoginView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var sessionManager = SessionManager.shared

    @State private var isLoading = true
    @State private var webView = WKWebView()
    @State private var statusMessage: String = "Accedi al tuo account Instagram"

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Barra di stato
                HStack {
                    Image(systemName: "shield.lefthalf.filled")
                        .foregroundColor(.accentColor)
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))

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
                        ProgressView("Caricamento Instagram...")
                            .padding()
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }

                // Pulsante di conferma manuale
                VStack(spacing: 6) {
                    Button(action: manualCheckLogin) {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                            Text("Ho effettuato l'accesso (Conferma)")
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 10))
                    }
                    Text("Premi qui una volta effettuato il login se la finestra non si chiude da sola.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemBackground))
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

    private func manualCheckLogin() {
        let store = webView.configuration.websiteDataStore.httpCookieStore
        store.getAllCookies { cookies in
            let sessionCookie = cookies.first { $0.name == "sessionid" && !$0.value.isEmpty }
            if let session = sessionCookie {
                self.webView.evaluateJavaScript("window._sharedData?.config?.viewer?.username || ''") { result, _ in
                    let username = (result as? String)?.isEmpty == false ? (result as? String) : nil
                    DispatchQueue.main.async {
                        self.sessionManager.updateSession(cookies: cookies, username: username)
                        self.dismiss()
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.statusMessage = "Sessione non ancora rilevata. Completa il login nella pagina sottostante."
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
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"

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
            checkTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
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

                if hasSession {
                    self.checkTimer?.invalidate()
                    self.checkTimer = nil

                    self.parent.webView.evaluateJavaScript("window._sharedData?.config?.viewer?.username || ''") { result, _ in
                        let detectedUsername = (result as? String)?.isEmpty == false ? (result as? String) : nil
                        DispatchQueue.main.async {
                            self.parent.onLoginSuccess(cookies, detectedUsername)
                        }
                    }
                }
            }
        }
    }
}
