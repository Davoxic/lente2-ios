import Foundation

public enum InstagramAPIError: LocalizedError {
    case invalidURL
    case notLoggedIn
    case networkError(String)
    case invalidResponse(Int)
    case userNotFound
    case privateAccount
    case decodingError(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL richiesta non valido."
        case .notLoggedIn:
            return "È necessario effettuare il login con Instagram per visualizzare questo contenuto."
        case .networkError(let msg):
            return "Errore di connessione: \(msg)"
        case .invalidResponse(let code):
            if code == 401 || code == 403 {
                return "Sessione Instagram scaduta o non autorizzata (Codice \(code)). Prova a rieseguire il login."
            } else if code == 429 {
                return "Instagram sta limitando temporaneamente le richieste (Rate Limit 429). Attendi qualche secondo."
            }
            return "Risposta non valida dal server Instagram (Codice \(code))."
        case .userNotFound:
            return "Utente non trovato o inesistente."
        case .privateAccount:
            return "Questo profilo è privato. Solo i follower approvati possono visualizzarne i post."
        case .decodingError(let msg):
            return "Impossibile elaborare i dati di Instagram: \(msg)"
        }
    }
}

public final class InstagramAPI {
    public static let shared = InstagramAPI()

    private let defaultUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1"
    private let igAppID = "936619743392459"
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    private func makeRequest(url: URL, cookieHeader: String) -> URLRequest {
        var req = URLRequest(url: url)
        req.setValue(defaultUserAgent, forHTTPHeaderField: "User-Agent")
        req.setValue(igAppID, forHTTPHeaderField: "X-IG-App-ID")
        req.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        req.setValue("https://www.instagram.com/", forHTTPHeaderField: "Referer")
        req.setValue("https://www.instagram.com", forHTTPHeaderField: "Origin")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if !cookieHeader.isEmpty {
            req.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        }
        return req
    }

    // MARK: - Search
    public func searchUsers(query: String, cookieHeader: String) async throws -> [InstagramUserMini] {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://www.instagram.com/api/v1/web/search/topsearch/?query=\(encoded)") else {
            throw InstagramAPIError.invalidURL
        }

        let req = makeRequest(url: url, cookieHeader: cookieHeader)
        let (data, response) = try await session.data(for: req)

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw InstagramAPIError.invalidResponse(http.statusCode)
        }

        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let usersArray = json["users"] as? [[String: Any]] else {
                return []
            }

            var results: [InstagramUserMini] = []
            for item in usersArray {
                guard let u = item["user"] as? [String: Any],
                      let username = u["username"] as? String else { continue }
                
                let pk = "\(u["pk"] ?? u["id"] ?? UUID().uuidString)"
                let fullName = u["full_name"] as? String ?? ""
                let picStr = u["profile_pic_url"] as? String
                let picURL = picStr.flatMap { URL(string: $0) }
                let isVerified = u["is_verified"] as? Bool ?? false
                let isPrivate = u["is_private"] as? Bool ?? false

                results.append(InstagramUserMini(
                    id: pk,
                    username: username,
                    fullName: fullName,
                    profilePicURL: picURL,
                    isVerified: isVerified,
                    isPrivate: isPrivate
                ))
            }
            return results
        } catch {
            throw InstagramAPIError.decodingError(error.localizedDescription)
        }
    }

    // MARK: - Profile & Posts
    public func fetchProfile(username: String, cookieHeader: String) async throws -> (user: InstagramUser, posts: [InstagramPost]) {
        guard let encoded = username.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://www.instagram.com/api/v1/users/web_profile_info/?username=\(encoded)") else {
            throw InstagramAPIError.invalidURL
        }

        let req = makeRequest(url: url, cookieHeader: cookieHeader)
        let (data, response) = try await session.data(for: req)

        if let http = response as? HTTPURLResponse {
            if http.statusCode == 404 {
                throw InstagramAPIError.userNotFound
            } else if http.statusCode != 200 {
                throw InstagramAPIError.invalidResponse(http.statusCode)
            }
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = json["data"] as? [String: Any],
              let userDict = dataObj["user"] as? [String: Any] else {
            throw InstagramAPIError.userNotFound
        }

        let id = "\(userDict["id"] ?? "")"
        let uname = userDict["username"] as? String ?? username
        let fullName = userDict["full_name"] as? String ?? ""
        let bio = userDict["biography"] as? String ?? ""
        let isVerified = userDict["is_verified"] as? Bool ?? false
        let isPrivate = userDict["is_private"] as? Bool ?? false
        
        let picURL = (userDict["profile_pic_url"] as? String).flatMap { URL(string: $0) }
        let picURLHD = (userDict["profile_pic_url_hd"] as? String).flatMap { URL(string: $0) }
        let extURL = (userDict["external_url"] as? String).flatMap { URL(string: $0) }

        let followersCount = (userDict["edge_followed_by"] as? [String: Any])?["count"] as? Int ?? 0
        let followingCount = (userDict["edge_follow"] as? [String: Any])?["count"] as? Int ?? 0
        
        let timelineMedia = userDict["edge_owner_to_timeline_media"] as? [String: Any]
        let postsCount = timelineMedia?["count"] as? Int ?? 0

        let userModel = InstagramUser(
            id: id,
            username: uname,
            fullName: fullName,
            biography: bio,
            profilePicURL: picURL,
            profilePicURLHD: picURLHD,
            externalURL: extURL,
            followersCount: followersCount,
            followingCount: followingCount,
            postsCount: postsCount,
            isVerified: isVerified,
            isPrivate: isPrivate
        )

        var posts: [InstagramPost] = []
        if let edges = timelineMedia?["edges"] as? [[String: Any]] {
            for edge in edges {
                guard let node = edge["node"] as? [String: Any] else { continue }
                if let post = parsePostNode(node, author: userModel.mini) {
                    posts.append(post)
                }
            }
        }

        return (user: userModel, posts: posts)
    }

    private func parsePostNode(_ node: [String: Any], author: InstagramUserMini) -> InstagramPost? {
        guard let id = node["id"] as? String,
              let shortcode = node["shortcode"] as? String else { return nil }

        let isVideo = node["is_video"] as? Bool ?? false
        let displayURLStr = node["display_url"] as? String
        let displayURL = displayURLStr.flatMap { URL(string: $0) } ?? URL(string: "about:blank")!
        let videoURLStr = node["video_url"] as? String
        let videoURL = videoURLStr.flatMap { URL(string: $0) }

        var caption = ""
        if let captionEdge = node["edge_media_to_caption"] as? [String: Any],
           let edges = captionEdge["edges"] as? [[String: Any]],
           let firstNode = edges.first?["node"] as? [String: Any],
           let text = firstNode["text"] as? String {
            caption = text
        }

        let likes = (node["edge_liked_by"] as? [String: Any])?["count"] as? Int
            ?? (node["edge_media_preview_like"] as? [String: Any])?["count"] as? Int ?? 0
        let comments = (node["edge_media_to_comment"] as? [String: Any])?["count"] as? Int ?? 0

        var takenDate: Date? = nil
        if let timestamp = node["taken_at_timestamp"] as? TimeInterval {
            takenDate = Date(timeIntervalSince1970: timestamp)
        }

        var mediaItems: [MediaItem] = []
        var mediaType: MediaType = isVideo ? .video : .image

        // Carosello multi-media
        if let sidecar = node["edge_sidecar_to_children"] as? [String: Any],
           let children = sidecar["edges"] as? [[String: Any]], !children.isEmpty {
            mediaType = .carousel
            for c in children {
                guard let cNode = c["node"] as? [String: Any] else { continue }
                let cID = cNode["id"] as? String ?? UUID().uuidString
                let cIsVideo = cNode["is_video"] as? Bool ?? false
                let cURLStr = cNode["display_url"] as? String
                guard let cURL = cURLStr.flatMap({ URL(string: $0) }) else { continue }
                let cVidStr = cNode["video_url"] as? String
                let cVidURL = cVidStr.flatMap { URL(string: $0) }

                mediaItems.append(MediaItem(
                    id: cID,
                    displayURL: cURL,
                    isVideo: cIsVideo,
                    videoURL: cVidURL
                ))
            }
        }

        if mediaItems.isEmpty {
            mediaItems.append(MediaItem(
                id: id,
                displayURL: displayURL,
                isVideo: isVideo,
                videoURL: videoURL
            ))
        }

        return InstagramPost(
            id: id,
            shortcode: shortcode,
            caption: caption,
            takenAt: takenDate,
            likesCount: likes,
            commentsCount: comments,
            mediaType: mediaType,
            thumbnailURL: displayURL,
            mediaItems: mediaItems,
            author: author
        )
    }
}
