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

struct SpotifyImage: Decodable {
    let url: String
    let height: Int?
    let width: Int?
}

struct SpotifyAlbum: Decodable {
    let name: String?
    let images: [SpotifyImage]?
}

struct SpotifyArtist: Decodable {
    let name: String?
}

struct SpotifyPlayableItem: Decodable {
    let id: String?
    let uri: String?
    let name: String?
    let type: String?
    let isLocal: Bool?
    let album: SpotifyAlbum?
    let artists: [SpotifyArtist]?

    enum CodingKeys: String, CodingKey {
        case id, uri, name, type, album, artists
        case isLocal = "is_local"
    }

    var isSupportedTrack: Bool {
        guard type == "track" else { return false }
        guard isLocal != true else { return false }
        guard let uri, uri.hasPrefix("spotify:track:") else { return false }
        return true
    }

    var primaryArtist: String? {
        artists?.first?.name
    }

    var artworkURL: URL? {
        guard let images = album?.images, !images.isEmpty else { return nil }

        let targetSize = 150
        let sorted = images.sorted { ($0.height ?? 0) < ($1.height ?? 0) }
        let closest = sorted.min {
            abs(($0.height ?? targetSize) - targetSize) < abs(($1.height ?? targetSize) - targetSize)
        }

        return closest.flatMap { URL(string: $0.url) }
            ?? sorted.last.flatMap { URL(string: $0.url) }
    }
}

struct AddedTrackResult: Equatable {
    let message: String
    let trackName: String
    let artistName: String?
    let artworkURL: URL?
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
