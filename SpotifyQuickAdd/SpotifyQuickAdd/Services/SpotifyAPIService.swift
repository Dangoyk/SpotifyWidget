import Foundation

final class SpotifyAPIService {
    private let tokenProvider: SpotifyTokenProviding
    private let session: URLSession

    init(tokenProvider: SpotifyTokenProviding, session: URLSession = .shared) {
        self.tokenProvider = tokenProvider
        self.session = session
    }

    func fetchCurrentlyPlaying() async throws -> SpotifyPlayableItem {
        let url = SpotifyConfig.apiBaseURL.appendingPathComponent("me/player/currently-playing")
        let (data, response) = try await authorizedRequest(url: url, method: "GET")

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.networkFailure("Could not read currently playing track.")
        }

        if httpResponse.statusCode == 204 || data.isEmpty {
            throw AppError.nothingPlaying
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw mapHTTPError(statusCode: httpResponse.statusCode, data: data, defaultMessage: "Could not fetch currently playing track.")
        }

        let decoded: CurrentlyPlayingResponse
        do {
            decoded = try JSONDecoder().decode(CurrentlyPlayingResponse.self, from: data)
        } catch {
            throw AppError.networkFailure("Could not parse currently playing response.")
        }

        guard let item = decoded.item else {
            throw AppError.nothingPlaying
        }

        if decoded.currentlyPlayingType == "ad" {
            throw AppError.unsupportedContent
        }

        guard item.isSupportedTrack else {
            throw AppError.unsupportedContent
        }

        return try await itemWithArtwork(item)
    }

    func fetchTrack(id: String) async throws -> SpotifyPlayableItem {
        let url = SpotifyConfig.apiBaseURL
            .appendingPathComponent("tracks")
            .appendingPathComponent(id)
        let (data, response) = try await authorizedRequest(url: url, method: "GET")

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.networkFailure("Could not fetch track details.")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw mapHTTPError(statusCode: httpResponse.statusCode, data: data, defaultMessage: "Could not fetch track details.")
        }

        do {
            return try JSONDecoder().decode(SpotifyPlayableItem.self, from: data)
        } catch {
            throw AppError.networkFailure("Could not parse track details.")
        }
    }

    private func itemWithArtwork(_ item: SpotifyPlayableItem) async throws -> SpotifyPlayableItem {
        guard item.artworkURL == nil, let id = item.id else {
            return item
        }

        guard let detailed = try? await fetchTrack(id: id),
              detailed.artworkURL != nil else {
            return item
        }

        return detailed
    }

    func fetchCurrentUser() async throws -> SpotifyUser {
        let url = SpotifyConfig.apiBaseURL.appendingPathComponent("me")
        let (data, response) = try await authorizedRequest(url: url, method: "GET")

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.networkFailure("Could not fetch Spotify profile.")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw mapHTTPError(statusCode: httpResponse.statusCode, data: data, defaultMessage: "Could not fetch Spotify profile.")
        }

        do {
            return try JSONDecoder().decode(SpotifyUser.self, from: data)
        } catch {
            throw AppError.networkFailure("Could not parse Spotify profile response.")
        }
    }

    func fetchEditablePlaylists() async throws -> [SpotifyPlaylist] {
        let currentUser = try await fetchCurrentUser()
        let allPlaylists = try await fetchUserPlaylists()

        return allPlaylists.filter { playlist in
            playlist.owner?.id == currentUser.id
        }
    }

    func fetchUserPlaylists() async throws -> [SpotifyPlaylist] {
        var allPlaylists: [SpotifyPlaylist] = []
        var nextURL: URL? = SpotifyConfig.apiBaseURL.appendingPathComponent("me/playlists")
        var isFirstPage = true

        while let url = nextURL {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            if isFirstPage {
                components?.queryItems = [URLQueryItem(name: "limit", value: "50")]
                isFirstPage = false
            }

            guard let requestURL = components?.url ?? url as URL? else {
                break
            }

            let (data, response) = try await authorizedRequest(url: requestURL, method: "GET")

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AppError.networkFailure("Could not fetch playlists.")
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw mapHTTPError(statusCode: httpResponse.statusCode, data: data, defaultMessage: "Could not fetch playlists.")
            }

            let page: PlaylistsResponse
            do {
                page = try JSONDecoder().decode(PlaylistsResponse.self, from: data)
            } catch {
                throw AppError.networkFailure("Could not parse playlists response.")
            }

            allPlaylists.append(contentsOf: page.items)

            if let next = page.next {
                nextURL = URL(string: next)
            } else {
                nextURL = nil
            }
        }

        return allPlaylists
    }

    func playlistContainsTrack(playlistId: String, trackURI: String) async throws -> Bool {
        var nextURL: URL? = SpotifyConfig.apiBaseURL
            .appendingPathComponent("playlists")
            .appendingPathComponent(playlistId)
            .appendingPathComponent("items")

        var isFirstPage = true

        while let url = nextURL {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            if isFirstPage {
                components?.queryItems = [
                    URLQueryItem(name: "limit", value: "100"),
                    URLQueryItem(name: "fields", value: "items(item(uri,id,type,is_local)),next")
                ]
                isFirstPage = false
            }

            guard let requestURL = components?.url ?? url as URL? else {
                break
            }

            let (data, response) = try await authorizedRequest(url: requestURL, method: "GET")

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AppError.networkFailure("Could not read playlist items.")
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw mapHTTPError(statusCode: httpResponse.statusCode, data: data, defaultMessage: "Could not read playlist items.")
            }

            let page: PlaylistItemsResponse
            do {
                page = try JSONDecoder().decode(PlaylistItemsResponse.self, from: data)
            } catch {
                throw AppError.networkFailure("Could not parse playlist items response.")
            }

            for playlistItem in page.items {
                if let uri = playlistItem.item?.uri, uri == trackURI {
                    return true
                }
            }

            if let next = page.next {
                nextURL = URL(string: next)
            } else {
                nextURL = nil
            }
        }

        return false
    }

    func addTrackToPlaylist(playlistId: String, trackURI: String) async throws {
        let url = SpotifyConfig.apiBaseURL
            .appendingPathComponent("playlists")
            .appendingPathComponent(playlistId)
            .appendingPathComponent("items")

        let body = AddTracksRequest(uris: [trackURI])
        let encodedBody = try JSONEncoder().encode(body)

        let (data, response) = try await authorizedRequest(url: url, method: "POST", body: encodedBody)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.networkFailure("Could not add track to playlist.")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw mapHTTPError(statusCode: httpResponse.statusCode, data: data, defaultMessage: "Could not add track to playlist.")
        }
    }

    private func authorizedRequest(url: URL, method: String, body: Data? = nil) async throws -> (Data, URLResponse) {
        let accessToken = try await tokenProvider.validAccessToken()
        let firstAttempt = try await performAuthorizedRequest(
            url: url,
            method: method,
            body: body,
            accessToken: accessToken
        )

        if let httpResponse = firstAttempt.1 as? HTTPURLResponse,
           httpResponse.statusCode == 401 {
            let refreshedToken = try await tokenProvider.forceRefreshAccessToken()
            return try await performAuthorizedRequest(
                url: url,
                method: method,
                body: body,
                accessToken: refreshedToken
            )
        }

        return firstAttempt
    }

    private func performAuthorizedRequest(
        url: URL,
        method: String,
        body: Data?,
        accessToken: String
    ) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        do {
            return try await session.data(for: request)
        } catch {
            throw AppError.networkFailure(error.localizedDescription)
        }
    }

    private func mapHTTPError(statusCode: Int, data: Data, defaultMessage: String) -> AppError {
        if statusCode == 401 {
            return .loginRequired
        }

        if statusCode == 403 {
            return .permissionDenied
        }

        if let message = Self.spotifyErrorMessage(from: data), !message.isEmpty {
            return .networkFailure(message)
        }

        return .networkFailure("\(defaultMessage) (HTTP \(statusCode)).")
    }

    private static func spotifyErrorMessage(from data: Data) -> String? {
        guard let decoded = try? JSONDecoder().decode(SpotifyAPIErrorResponse.self, from: data) else {
            return String(data: data, encoding: .utf8)
        }
        return decoded.error?.message
    }
}
