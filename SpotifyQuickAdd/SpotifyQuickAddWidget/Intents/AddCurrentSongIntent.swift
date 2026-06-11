import AppIntents
import UIKit
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
    let trackURI: String?
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
            let isDuplicate = added.message == "Already in playlist"
            return WidgetAddSongOutcome(
                message: isDuplicate ? "⚠️ \(added.message)" : "✅ \(added.message)",
                isError: isDuplicate,
                isSuccess: true,
                trackName: added.trackName,
                artistName: added.artistName,
                artworkURL: added.artworkURL,
                trackURI: added.trackURI
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
            artworkURL: nil,
            trackURI: nil
        )
    }

    static func persistOutcome(_ outcome: WidgetAddSongOutcome, for playlistID: String) async {
        var artworkData: Data?
        if outcome.isSuccess, let artworkURL = outcome.artworkURL {
            artworkData = await downloadArtwork(from: artworkURL)
        }

        if outcome.isSuccess,
           outcome.isError,
           let trackURI = outcome.trackURI {
            SharedStorage.shared.setDuplicateWarning(trackURI: trackURI, for: playlistID)
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

    static func downloadArtwork(from url: URL) async -> Data? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode),
                  !data.isEmpty else {
                return nil
            }
            return WidgetArtworkProcessor.normalizedJPEGData(from: data)
        } catch {
            return nil
        }
    }
}

enum WidgetArtworkProcessor {
    static func normalizedJPEGData(from data: Data, maxDimension: CGFloat = 300) -> Data? {
        guard let image = UIImage(data: data) else { return nil }

        let largestSide = max(image.size.width, image.size.height)
        let scale = min(maxDimension / largestSide, 1)
        let targetSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        return resized.jpegData(compressionQuality: 0.85)
    }
}

