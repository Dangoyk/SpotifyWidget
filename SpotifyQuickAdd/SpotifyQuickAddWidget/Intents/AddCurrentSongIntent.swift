import AppIntents
import WidgetKit

struct AddCurrentSongIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Current Song"
    static var description = IntentDescription("Adds the currently playing Spotify song to this widget's playlist.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Playlist")
    var playlist: PlaylistEntity?

    init() {}

    init(playlist: PlaylistEntity?) {
        self.playlist = playlist
    }

    func perform() async throws -> some IntentResult {
        guard let playlist else {
            let outcome = WidgetAddSongService.formattedFailure(.playlistNotConfigured)
            await WidgetAddSongService.persistOutcome(outcome, for: SharedStorage.unconfiguredWidgetStatusKey)
            WidgetCenter.shared.reloadTimelines(ofKind: SpotifyConfig.widgetKind)
            return .result()
        }

        let outcome = await WidgetAddSongLock.shared.perform(
            playlistID: playlist.id,
            ifBusy: {
                WidgetAddSongService.formattedFailure(
                    .unknown("Already adding a song. Please wait a moment.")
                )
            },
            operation: {
                await WidgetAddSongService.addCurrentSong(to: playlist)
            }
        )

        await WidgetAddSongService.persistOutcome(outcome, for: playlist.id)
        WidgetCenter.shared.reloadTimelines(ofKind: SpotifyConfig.widgetKind)
        return .result()
    }
}

struct WidgetAddSongOutcome {
    let message: String
    let isError: Bool
    let isSuccess: Bool
    let trackName: String?
    let artistName: String?
    let artworkURL: URL?
}

enum WidgetAddSongService {
    static func addCurrentSong(to playlistEntity: PlaylistEntity) async -> WidgetAddSongOutcome {
        let tokenProvider = SpotifyTokenProvider()
        tokenProvider.refreshLoginState()

        let apiService = SpotifyAPIService(tokenProvider: tokenProvider)
        let manager = PlaylistManager(
            tokenProvider: tokenProvider,
            apiService: apiService,
            isWidgetContext: true
        )

        let playlist = SelectedPlaylist(id: playlistEntity.id, name: playlistEntity.name)
        let result = await manager.addCurrentTrack(to: playlist)

        switch result {
        case .success(let added):
            return WidgetAddSongOutcome(
                message: "✅ \(added.message)",
                isError: false,
                isSuccess: true,
                trackName: added.trackName,
                artistName: added.artistName,
                artworkURL: added.artworkURL
            )
        case .failure(let error):
            return formattedFailure(error)
        }
    }

    static func formattedFailure(_ error: AppError) -> WidgetAddSongOutcome {
        let text = error.errorDescription ?? "Something went wrong."
        return WidgetAddSongOutcome(
            message: "❌ \(text)",
            isError: true,
            isSuccess: false,
            trackName: nil,
            artistName: nil,
            artworkURL: nil
        )
    }

    static func persistOutcome(_ outcome: WidgetAddSongOutcome, for playlistID: String) async {
        var artworkData: Data?
        if outcome.isSuccess, let artworkURL = outcome.artworkURL {
            artworkData = try? await URLSession.shared.data(from: artworkURL).0
        }

        SharedStorage.shared.setWidgetStatus(
            for: playlistID,
            message: outcome.message,
            isError: outcome.isError,
            isSuccess: outcome.isSuccess,
            trackName: outcome.trackName,
            artistName: outcome.artistName,
            artworkData: artworkData
        )
    }
}
