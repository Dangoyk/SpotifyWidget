import Foundation

final class PlaylistManager {
    private let authService: SpotifyAuthService
    private let apiService: SpotifyAPIService
    private let storage: SharedStorage

    init(
        authService: SpotifyAuthService,
        apiService: SpotifyAPIService,
        storage: SharedStorage = .shared
    ) {
        self.authService = authService
        self.apiService = apiService
        self.storage = storage
    }

    func addCurrentTrackToSelectedPlaylist() async -> Result<String, AppError> {
        guard authService.isLoggedIn else {
            return .failure(.loginRequired)
        }

        guard let selectedPlaylist = storage.selectedPlaylist else {
            return .failure(.noPlaylistSelected)
        }

        do {
            let track = try await apiService.fetchCurrentlyPlaying()

            guard let trackURI = track.uri else {
                return .failure(.unsupportedContent)
            }

            let alreadyExists = try await apiService.playlistContainsTrack(
                playlistId: selectedPlaylist.id,
                trackURI: trackURI
            )

            if alreadyExists {
                return .failure(.alreadyInPlaylist)
            }

            try await apiService.addTrackToPlaylist(
                playlistId: selectedPlaylist.id,
                trackURI: trackURI
            )

            let trackName = track.name ?? "Track"
            let message = "Added \"\(trackName)\" to \"\(selectedPlaylist.name)\"."
            return .success(message)
        } catch let error as AppError {
            return .failure(error)
        } catch {
            return .failure(.networkFailure(error.localizedDescription))
        }
    }
}
