import Foundation
import WebKit

@MainActor
public final class SessionManager: ObservableObject {
    public static let shared = SessionManager()

    private let defaults = UserDefaults.standard
    private let cookiesKey = "com.lente.savedCookies"
    private let usernameKey = "com.lente.savedUsername"
    private let userIDKey = "com.lente.savedUserID"

    @Published public private(set) var isLoggedIn: Bool = false
    @Published public private(set) var currentUsername: String?
    @Published public private(set) var currentUserID: String?
    @Published public private(set) var cookieHeader: String = ""

    private init() {
        loadSession()
    }

    public func loadSession() {
        if let cookies = defaults.dictionary(forKey: cookiesKey) as? [String: String],
           let sessionID = cookies["sessionid"], !sessionID.isEmpty {
            self.cookieHeader = cookies.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
            self.currentUsername = defaults.string(forKey: usernameKey)
            self.currentUserID = defaults.string(forKey: userIDKey) ?? cookies["ds_user_id"]
            self.isLoggedIn = true
        } else {
            self.isLoggedIn = false
            self.cookieHeader = ""
            self.currentUsername = nil
            self.currentUserID = nil
        }
    }

    public func updateSession(cookies: [HTTPCookie], username: String? = nil) {
        var dict: [String: String] = [:]
        for c in cookies {
            if ["sessionid", "ds_user_id", "csrftoken", "mid", "rur", "ig_did"].contains(c.name) {
                dict[c.name] = c.value
            }
        }

        if let sessionID = dict["sessionid"], !sessionID.isEmpty {
            defaults.set(dict, forKey: cookiesKey)
            if let uname = username, !uname.isEmpty {
                defaults.set(uname, forKey: usernameKey)
                self.currentUsername = uname
            }
            if let uid = dict["ds_user_id"] {
                defaults.set(uid, forKey: userIDKey)
                self.currentUserID = uid
            }
            self.cookieHeader = dict.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
            self.isLoggedIn = true
        }
    }

    public func logout() {
        defaults.removeObject(forKey: cookiesKey)
        defaults.removeObject(forKey: usernameKey)
        defaults.removeObject(forKey: userIDKey)

        // Pulisce anche i cookie di WebKit
        WKWebsiteDataStore.default().fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
            let instagramRecords = records.filter { $0.displayName.contains("instagram") || $0.displayName.contains("facebook") }
            WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), for: instagramRecords) {}
        }

        self.cookieHeader = ""
        self.currentUsername = nil
        self.currentUserID = nil
        self.isLoggedIn = false
    }
}
