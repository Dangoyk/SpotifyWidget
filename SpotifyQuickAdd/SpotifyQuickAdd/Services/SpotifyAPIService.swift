import Foundation

final class SpotifyAPIService {
    private let authService: SpotifyAuthService
    private let session: URLSession

    init(authService: SpotifyAuthService, session: URLSession = .shared) {
        self.authService = authService
        self.session = session
    }

    func fetchCurrentlyPlaying() async throws -> SpotifyPlayableItem {
        let url = SpotifyConfig.apiBaseURL.appendingPathComponent("me/player/currently-playing")
        let (data, response) = try await authorizedRequest(url: url, method: "GET")

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.networkFailure("Could not read currently playing track.")
        }

        if httpResponse.statusCode == 204 {
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

        return item
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
            .appendingPathComponent("tracks")

        var isFirstPage = true

        while let url = nextURL {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            if isFirstPage {
                components?.queryItems = [
                    URLQueryItem(name: "limit", value: "100"),
                    URLQueryItem(name: "fields", value: "items(track(uri,id,type,is_local)),next")
                ]
                isFirstPage = false
            }

            guard let requestURL = components?.url ?? url as URL? else {
                break
            }

            let (data, response) = try await authorizedRequest(url: requestURL, method: "GET")

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AppError.networkFailure("Could not read playlist tracks.")
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw mapHTTPError(statusCode: httpResponse.statusCode, data: data, defaultMessage: "Could not read playlist tracks.")
            }

            let page: PlaylistTracksResponse
            do {
                page = try JSONDecoder().decode(PlaylistTracksResponse.self, from: data)
            } catch {
                throw AppError.networkFailure("Could not parse playlist tracks response.")
            }

            for item in page.items {
                if let uri = item.track?.uri, uri == trackURI {
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
            .appendingPathComponent("tracks")

        let body = AddTracksRequest(uris: [trackURI])
        let encodedBody = try JSONEncoder().encode(body)

        let (data, response) = try await authorizedRequest(url: url, method: "POST", body: encodedBody)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.networkFailure("Could not add track to playlist.")
        }

        if httpResponse.statusCode == 403 {
            throw AppError.permissionDenied
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw mapHTTPError(statusCode: httpResponse.statusCode, data: data, defaultMessage: "Could not add track to playlist.")
        }
    }

    private func authorizedRequest(url: URL, method: String, body: Data? = nil) async throws -> (Data, URLResponse) {
        let accessToken = try await authService.validAccessToken()

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

        if let message = Self.spotifyErrorMessage(from: data) {
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
