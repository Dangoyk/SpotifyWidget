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
            SharedStorage.shared.setWidgetStatus(
                for: SharedStorage.unconfiguredWidgetStatusKey,
                message: outcome.message,
                isError: outcome.isError,
                isSuccess: outcome.isSuccess
            )
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

        SharedStorage.shared.setWidgetStatus(
            for: playlist.id,
            message: outcome.message,
            isError: outcome.isError,
            isSuccess: outcome.isSuccess
        )

        WidgetCenter.shared.reloadTimelines(ofKind: SpotifyConfig.widgetKind)
        return .result()
    }
}

enum WidgetAddSongService {
    static func addCurrentSong(to playlistEntity: PlaylistEntity) async -> (message: String, isError: Bool, isSuccess: Bool) {
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
        case .success(let message):
            return ("✅ \(message)", false, true)
        case .failure(let error):
            return formattedFailure(error)
        }
    }

    static func formattedFailure(_ error: AppError) -> (message: String, isError: Bool, isSuccess: Bool) {
        let text = error.errorDescription ?? "Something went wrong."
        return ("❌ \(text)", true, false)
    }
}
