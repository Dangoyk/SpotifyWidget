import Foundation

enum PlaylistCatalog {
    static func allEntities() async -> [PlaylistEntity] {
        let cached = SharedStorage.shared.cachedPlaylists()
        if !cached.isEmpty {
            return map(cached)
        }

        let fetched = await fetchFromSpotify()
        if !fetched.isEmpty {
            return fetched
        }

        return map(SharedStorage.shared.cachedPlaylists())
    }

    static func fetchFromSpotify() async -> [PlaylistEntity] {
        let tokenProvider = SpotifyTokenProvider()
        tokenProvider.refreshLoginState()
        guard tokenProvider.isLoggedIn else { return [] }

        let apiService = SpotifyAPIService(tokenProvider: tokenProvider)
        do {
            let playlists = try await apiService.fetchEditablePlaylists()
            guard !playlists.isEmpty else { return [] }
            SharedStorage.shared.cachePlaylists(playlists)
            return playlists.map { PlaylistEntity(id: $0.id, name: $0.name) }
        } catch {
            return []
        }
    }

    private static func map(_ playlists: [CachedPlaylist]) -> [PlaylistEntity] {
        playlists.map { PlaylistEntity(id: $0.id, name: $0.name) }
    }
}
