import Foundation

public enum MediaType: String, Codable {
    case image
    case video
    case carousel
}

public struct MediaItem: Identifiable, Codable, Hashable {
    public let id: String
    public let displayURL: URL
    public let isVideo: Bool
    public let videoURL: URL?
    public let width: Int?
    public let height: Int?

    public init(
        id: String = UUID().uuidString,
        displayURL: URL,
        isVideo: Bool = false,
        videoURL: URL? = nil,
        width: Int? = nil,
        height: Int? = nil
    ) {
        self.id = id
        self.displayURL = displayURL
        self.isVideo = isVideo
        self.videoURL = videoURL
        self.width = width
        self.height = height
    }
}

public struct InstagramUserMini: Identifiable, Codable, Hashable {
    public let id: String
    public let username: String
    public let fullName: String
    public let profilePicURL: URL?
    public let isVerified: Bool
    public let isPrivate: Bool

    public init(
        id: String,
        username: String,
        fullName: String = "",
        profilePicURL: URL? = nil,
        isVerified: Bool = false,
        isPrivate: Bool = false
    ) {
        self.id = id
        self.username = username
        self.fullName = fullName
        self.profilePicURL = profilePicURL
        self.isVerified = isVerified
        self.isPrivate = isPrivate
    }
}

public struct InstagramUser: Identifiable, Codable, Hashable {
    public let id: String
    public let username: String
    public let fullName: String
    public let biography: String
    public let profilePicURL: URL?
    public let profilePicURLHD: URL?
    public let externalURL: URL?
    public let followersCount: Int
    public let followingCount: Int
    public let postsCount: Int
    public let isVerified: Bool
    public let isPrivate: Bool

    public init(
        id: String,
        username: String,
        fullName: String = "",
        biography: String = "",
        profilePicURL: URL? = nil,
        profilePicURLHD: URL? = nil,
        externalURL: URL? = nil,
        followersCount: Int = 0,
        followingCount: Int = 0,
        postsCount: Int = 0,
        isVerified: Bool = false,
        isPrivate: Bool = false
    ) {
        self.id = id
        self.username = username
        self.fullName = fullName
        self.biography = biography
        self.profilePicURL = profilePicURL
        self.profilePicURLHD = profilePicURLHD
        self.externalURL = externalURL
        self.followersCount = followersCount
        self.followingCount = followingCount
        self.postsCount = postsCount
        self.isVerified = isVerified
        self.isPrivate = isPrivate
    }

    public var mini: InstagramUserMini {
        InstagramUserMini(
            id: id,
            username: username,
            fullName: fullName,
            profilePicURL: profilePicURL,
            isVerified: isVerified,
            isPrivate: isPrivate
        )
    }
}

public struct InstagramPost: Identifiable, Codable, Hashable {
    public let id: String
    public let shortcode: String
    public let caption: String
    public let takenAt: Date?
    public let likesCount: Int
    public let commentsCount: Int
    public let mediaType: MediaType
    public let thumbnailURL: URL?
    public let mediaItems: [MediaItem]
    public let author: InstagramUserMini

    public init(
        id: String,
        shortcode: String,
        caption: String,
        takenAt: Date?,
        likesCount: Int,
        commentsCount: Int,
        mediaType: MediaType,
        thumbnailURL: URL?,
        mediaItems: [MediaItem],
        author: InstagramUserMini
    ) {
        self.id = id
        self.shortcode = shortcode
        self.caption = caption
        self.takenAt = takenAt
        self.likesCount = likesCount
        self.commentsCount = commentsCount
        self.mediaType = mediaType
        self.thumbnailURL = thumbnailURL
        self.mediaItems = mediaItems
        self.author = author
    }

    public var shareURL: URL {
        URL(string: "https://www.instagram.com/p/\(shortcode)/")!
    }
}

public struct SearchHistoryItem: Identifiable, Codable, Hashable {
    public var id: String { username.lowercased() }
    public let username: String
    public let fullName: String
    public let profilePicURL: URL?
    public let isVerified: Bool
    public let timestamp: Date

    public init(user: InstagramUserMini) {
        self.username = user.username
        self.fullName = user.fullName
        self.profilePicURL = user.profilePicURL
        self.isVerified = user.isVerified
        self.timestamp = Date()
    }
}
