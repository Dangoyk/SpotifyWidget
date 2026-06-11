import Foundation

final class PlaylistManager {
    private let tokenProvider: SpotifyTokenProviding
    private let apiService: SpotifyAPIService
    private let storage: SharedStorage
    private let isWidgetContext: Bool

    init(
        tokenProvider: SpotifyTokenProviding,
        apiService: SpotifyAPIService,
        storage: SharedStorage = .shared,
        isWidgetContext: Bool = false
    ) {
        self.tokenProvider = tokenProvider
        self.apiService = apiService
        self.storage = storage
        self.isWidgetContext = isWidgetContext
    }

    func addCurrentTrackToSelectedPlaylist() async -> Result<AddedTrackResult, AppError> {
        guard let selectedPlaylist = storage.selectedPlaylist else {
            return .failure(.noPlaylistSelected)
        }
        return await addCurrentTrack(to: selectedPlaylist)
    }

    func addCurrentTrack(to playlist: SelectedPlaylist) async -> Result<AddedTrackResult, AppError> {
        tokenProvider.refreshLoginState()

        guard tokenProvider.isLoggedIn else {
            return .failure(isWidgetContext ? .widgetLoginRequired : .loginRequired)
        }

        do {
            let track = try await apiService.fetchCurrentlyPlaying()

            guard let trackURI = track.uri else {
                return .failure(.unsupportedContent)
            }

            let alreadyExists = try await apiService.playlistContainsTrack(
                playlistId: playlist.id,
                trackURI: trackURI
            )

            if alreadyExists {
                let trackName = track.name ?? "Track"
                if isWidgetContext {
                    return .success(
                        AddedTrackResult(
                            message: "Already in playlist",
                            trackName: trackName,
                            artistName: track.primaryArtist,
                            artworkURL: track.artworkURL,
                            trackURI: trackURI
                        )
                    )
                }
                return .failure(.alreadyInPlaylist)
            }

            try await apiService.addTrackToPlaylist(
                playlistId: playlist.id,
                trackURI: trackURI
            )

            let trackName = track.name ?? "Track"
            let message = isWidgetContext
                ? "Added: \(trackName)"
                : "Added \"\(trackName)\" to \"\(playlist.name)\"."
            return .success(
                AddedTrackResult(
                    message: message,
                    trackName: trackName,
                    artistName: track.primaryArtist,
                    artworkURL: track.artworkURL,
                    trackURI: trackURI
                )
            )
        } catch let error as AppError {
            return .failure(mapErrorForContext(error))
        } catch {
            return .failure(.networkFailure(error.localizedDescription))
        }
    }

    private func mapErrorForContext(_ error: AppError) -> AppError {
        if isWidgetContext, error == .loginRequired {
            return .widgetLoginRequired
        }
        return error
    }
}
