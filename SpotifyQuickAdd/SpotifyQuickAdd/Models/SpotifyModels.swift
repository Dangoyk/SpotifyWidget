import Foundation

struct TokenResponse: Decodable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let refreshToken: String?
    let scope: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
    }
}

struct CurrentlyPlayingResponse: Decodable {
    let item: SpotifyPlayableItem?
    let currentlyPlayingType: String?

    enum CodingKeys: String, CodingKey {
        case item
        case currentlyPlayingType = "currently_playing_type"
    }
}

struct SpotifyPlayableItem: Decodable {
    let id: String?
    let uri: String?
    let name: String?
    let type: String?
    let isLocal: Bool?

    enum CodingKeys: String, CodingKey {
        case id, uri, name, type
        case isLocal = "is_local"
    }

    var isSupportedTrack: Bool {
        guard type == "track" else { return false }
        guard isLocal != true else { return false }
        guard let uri, uri.hasPrefix("spotify:track:") else { return false }
        return true
    }
}

struct PlaylistsResponse: Decodable {
    let items: [SpotifyPlaylist]
    let next: String?
}

struct SpotifyPlaylist: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let uri: String
    let `public`: Bool?
    let collaborative: Bool?
    let owner: SpotifyPlaylistOwner?

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: SpotifyPlaylist, rhs: SpotifyPlaylist) -> Bool {
        lhs.id == rhs.id
    }
}

struct SpotifyPlaylistOwner: Decodable {
    let id: String?
    let displayName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
    }
}

struct SpotifyUser: Decodable {
    let id: String
    let displayName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
    }
}

struct PlaylistItemsResponse: Decodable {
    let items: [PlaylistContentItem]
    let next: String?
}

struct PlaylistContentItem: Decodable {
    let item: SpotifyPlayableItem?

    enum CodingKeys: String, CodingKey {
        case item
        case track
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        item = try container.decodeIfPresent(SpotifyPlayableItem.self, forKey: .item)
            ?? container.decodeIfPresent(SpotifyPlayableItem.self, forKey: .track)
    }
}

struct AddTracksRequest: Encodable {
    let uris: [String]
}

struct SpotifyAPIErrorResponse: Decodable {
    let error: SpotifyAPIErrorDetail?
}

struct SpotifyAPIErrorDetail: Decodable {
    let message: String?
    let status: Int?
}
