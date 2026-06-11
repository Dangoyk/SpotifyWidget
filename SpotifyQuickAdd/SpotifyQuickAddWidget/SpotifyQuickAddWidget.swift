import AppIntents
import SwiftUI
import UIKit
import WidgetKit

struct PlaylistWidgetEntry: TimelineEntry {
    let date: Date
    let playlistEntity: PlaylistEntity?
    let playlistName: String
    let statusMessage: String?
    let statusIsError: Bool
    let statusIsSuccess: Bool
    let trackName: String?
    let artistName: String?
    let artworkData: Data?
    let nowPlayingTrackName: String?
    let nowPlayingArtistName: String?
    let nowPlayingArtworkData: Data?
    let nowPlayingTrackURI: String?
    let showInPlaylistWarning: Bool
    let statusUpdatedAt: Date?
}

private enum LockScreenFeedback {
    case added
    case failed
    case alreadyInPlaylist
}

struct AddCurrentSongWidgetView: View {
    @Environment(\.widgetFamily) private var widgetFamily
    let entry: PlaylistWidgetEntry

    var body: some View {
        switch widgetFamily {
        case .accessoryInline:
            LockScreenInlineWidgetView(entry: entry)
        case .accessoryCircular:
            LockScreenCircularWidgetView(entry: entry)
        case .accessoryRectangular:
            LockScreenRectangularWidgetView(entry: entry)
        default:
            HomeScreenWidgetView(entry: entry)
        }
    }
}

struct WidgetArtworkImage: View {
    let artworkData: Data?
    var size: CGFloat = 56
    var cornerRadius: CGFloat = 8

    var body: some View {
        Group {
            if let artworkData, let uiImage = UIImage(data: artworkData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Color.white.opacity(0.12)
                    Image(systemName: "music.note")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

struct HomeScreenWidgetView: View {
    @Environment(\.widgetFamily) private var widgetFamily
    let entry: PlaylistWidgetEntry

    private var artworkSize: CGFloat {
        widgetFamily == .systemMedium ? 64 : 52
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.playlistName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if entry.hasHomeNowPlaying {
                HStack(alignment: .top, spacing: 8) {
                    WidgetArtworkImage(
                        artworkData: entry.homeArtworkData,
                        size: artworkSize,
                        cornerRadius: 8
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.homeTrackName ?? "")
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                        if let artistName = entry.homeArtistName {
                            Text(artistName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)
                        }
                        if entry.showInPlaylistWarning {
                            Text("Already in playlist")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                                .lineLimit(1)
                        }
                    }
                }
            } else if entry.homeShowsActionStatus {
                Text(entry.cleanStatusMessage)
                    .font(.caption2)
                    .foregroundStyle(entry.statusTextColor)
                    .lineLimit(3)
            } else {
                Text("Nothing playing")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if let playlist = entry.playlistEntity {
                Button(intent: AddCurrentSongIntent(playlist: playlist)) {
                    Label("Add Current Song", systemImage: "plus.circle.fill")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(Color(red: 0.11, green: 0.73, blue: 0.33))
            } else {
                Text("Open the app and select a playlist.")
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
        .containerBackground(for: .widget) {
            Color(red: 0.08, green: 0.08, blue: 0.10)
        }
    }
}

struct LockScreenInlineWidgetView: View {
    let entry: PlaylistWidgetEntry

    var body: some View {
        Group {
            if let playlist = entry.playlistEntity {
                Button(intent: AddCurrentSongIntent(playlist: playlist)) {
                    Label {
                        Text(entry.inlineActionText)
                            .lineLimit(2)
                    } icon: {
                        Image(systemName: entry.lockScreenIconName)
                    }
                }
                .buttonStyle(.plain)
            } else {
                Label("Choose playlist in app", systemImage: "exclamationmark.triangle")
            }
        }
        .opacity(entry.lockScreenIsDimmed ? 0.4 : 1)
        .containerBackground(.clear, for: .widget)
    }
}

struct LockScreenCircularWidgetView: View {
    let entry: PlaylistWidgetEntry

    var body: some View {
        Group {
            if let playlist = entry.playlistEntity {
                Button(intent: AddCurrentSongIntent(playlist: playlist)) {
                    Image(systemName: entry.lockScreenCircularIconName)
                        .font(.title2.weight(.semibold))
                }
                .buttonStyle(.plain)
            } else {
                Image(systemName: "exclamationmark")
                    .font(.title3.weight(.semibold))
            }
        }
        .opacity(entry.lockScreenIsDimmed ? 0.35 : 1)
        .containerBackground(for: .widget) {
            if entry.lockScreenShowsResultArtwork,
               let data = entry.artworkData,
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                AccessoryWidgetBackground()
            }
        }
    }
}

struct LockScreenRectangularWidgetView: View {
    let entry: PlaylistWidgetEntry

    var body: some View {
        Group {
            if let playlist = entry.playlistEntity {
                Button(intent: AddCurrentSongIntent(playlist: playlist)) {
                    HStack(alignment: .top, spacing: 8) {
                        if entry.lockScreenShowsResultArtwork {
                            WidgetArtworkImage(
                                artworkData: entry.artworkData,
                                size: 44,
                                cornerRadius: 6
                            )
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.playlistName)
                                .font(.headline)
                                .lineLimit(1)

                            switch entry.lockScreenFeedback {
                            case .added:
                                Text("Added to playlist")
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                                if let trackName = entry.trackName {
                                    Text(trackName)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            case .failed:
                                Text(entry.shortLockScreenError)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            case .alreadyInPlaylist:
                                Text("Already in playlist")
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                                if let trackName = entry.trackName {
                                    Text(trackName)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            case nil:
                                Text(entry.lockScreenSubtitle)
                                    .font(.caption)
                                    .lineLimit(2)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .buttonStyle(.plain)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Spotify Quick Add")
                        .font(.headline)
                    Text("Choose playlist in app")
                        .font(.caption)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .opacity(entry.lockScreenIsDimmed ? 0.35 : 1)
        .containerBackground(for: .widget) {
            AccessoryWidgetBackground()
        }
    }
}

private extension PlaylistWidgetEntry {
    var hasTrackResult: Bool {
        statusIsSuccess && trackName != nil
    }

    var hasHomeNowPlaying: Bool {
        homeTrackName != nil
    }

    var homeTrackName: String? {
        nowPlayingTrackName ?? trackName
    }

    var homeArtistName: String? {
        nowPlayingArtistName ?? artistName
    }

    var homeArtworkData: Data? {
        nowPlayingArtworkData ?? artworkData
    }

    var homeShowsActionStatus: Bool {
        guard let statusMessage else { return false }
        if statusIsError { return true }
        if cleanStatusMessage.localizedCaseInsensitiveContains("already in playlist") {
            return false
        }
        return !statusMessage.isEmpty
    }

    var showsArtwork: Bool {
        hasTrackResult && artworkData != nil
    }

    var lockScreenShowsResultArtwork: Bool {
        lockScreenFeedback == .added && artworkData != nil
    }

    var lockScreenFeedback: LockScreenFeedback? {
        guard statusMessage != nil,
              let statusUpdatedAt,
              date.timeIntervalSince(statusUpdatedAt) < SharedStorage.lockScreenFeedbackDuration else {
            return nil
        }

        if statusIsSuccess && statusIsError {
            return .alreadyInPlaylist
        }
        if statusIsError {
            return .failed
        }
        if statusIsSuccess {
            return .added
        }
        return nil
    }

    var lockScreenIsDimmed: Bool {
        lockScreenFeedback == .failed
    }

    var lockScreenIconName: String {
        switch lockScreenFeedback {
        case .added:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.circle"
        case .alreadyInPlaylist:
            return "exclamationmark.circle"
        case nil:
            return "music.note.list"
        }
    }

    var lockScreenCircularIconName: String {
        switch lockScreenFeedback {
        case .added:
            return "checkmark"
        case .failed:
            return "xmark"
        case .alreadyInPlaylist:
            return "exclamationmark"
        case nil:
            return "plus"
        }
    }

    var shortLockScreenError: String {
        let message = cleanStatusMessage
        if message.count > 32 {
            return String(message.prefix(29)) + "..."
        }
        return message
    }

    var statusTextColor: Color {
        if cleanStatusMessage.localizedCaseInsensitiveContains("already in playlist") {
            return .orange
        }
        if statusIsError {
            return .red
        }
        return .green
    }

    var cleanStatusMessage: String {
        guard let statusMessage else { return "" }
        return statusMessage
            .replacingOccurrences(of: "✅ ", with: "")
            .replacingOccurrences(of: "❌ ", with: "")
    }

    var inlineActionText: String {
        switch lockScreenFeedback {
        case .added:
            if let trackName {
                return "Added · \(trackName)"
            }
            return "Added to playlist"
        case .failed:
            return shortLockScreenError
        case .alreadyInPlaylist:
            return "Already in playlist"
        case nil:
            return "Add to \(shortPlaylistName)"
        }
    }

    var shortPlaylistName: String {
        guard playlistName.count > 18 else { return playlistName }
        return String(playlistName.prefix(15)) + "..."
    }

    var lockScreenSubtitle: String {
        guard let statusMessage else {
            return "Tap to add current song"
        }
        return cleanStatusMessage
    }
}

struct SpotifyQuickAddWidget: Widget {
    let kind = SpotifyConfig.widgetKind

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ConfigurePlaylistWidgetIntent.self,
            provider: PlaylistWidgetProvider()
        ) { entry in
            AddCurrentSongWidgetView(entry: entry)
        }
        .configurationDisplayName("Spotify Quick Add")
        .description("Add your currently playing song to a configured playlist.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryInline,
            .accessoryCircular,
            .accessoryRectangular
        ])
    }
}

struct PlaylistWidgetProvider: AppIntentTimelineProvider {
    typealias Intent = ConfigurePlaylistWidgetIntent
    typealias Entry = PlaylistWidgetEntry

    func placeholder(in context: Context) -> PlaylistWidgetEntry {
        PlaylistWidgetEntry(
            date: Date(),
            playlistEntity: PlaylistEntity(id: "placeholder", name: "My Playlist"),
            playlistName: "My Playlist",
            statusMessage: nil,
            statusIsError: false,
            statusIsSuccess: false,
            trackName: nil,
            artistName: nil,
            artworkData: nil,
            nowPlayingTrackName: "Current Song",
            nowPlayingArtistName: "Artist",
            nowPlayingArtworkData: nil,
            nowPlayingTrackURI: nil,
            showInPlaylistWarning: false,
            statusUpdatedAt: nil
        )
    }

    func snapshot(for configuration: ConfigurePlaylistWidgetIntent, in context: Context) async -> PlaylistWidgetEntry {
        makeCachedEntry(for: configuration)
    }

    func timeline(for configuration: ConfigurePlaylistWidgetIntent, in context: Context) async -> Timeline<PlaylistWidgetEntry> {
        let now = Date()
        let playlist = WidgetPlaylistResolver.effectivePlaylist(widgetPlaylist: configuration.playlist)
        let playlistID = playlist?.id ?? SharedStorage.unconfiguredWidgetStatusKey
        let nowPlaying = await WidgetNowPlayingFetcher.fetch(for: playlist)
        let showWarning = SharedStorage.shared.shouldShowDuplicateWarning(
            trackURI: nowPlaying?.trackURI,
            for: playlistID,
            at: now
        )

        var entries = [
            makeEntry(
                for: configuration,
                nowPlaying: nowPlaying,
                showInPlaylistWarning: showWarning,
                date: now
            )
        ]

        if showWarning,
           let warning = SharedStorage.shared.duplicateWarning(for: playlistID) {
            let warningEnd = warning.shownAt.addingTimeInterval(SharedStorage.duplicateWarningDuration)
            if warningEnd > now {
                entries.append(
                    makeEntry(
                        for: configuration,
                        nowPlaying: nowPlaying,
                        showInPlaylistWarning: false,
                        date: warningEnd
                    )
                )
            }
        }

        if let status = widgetStatus(for: playlist) {
            let feedbackEnd = status.updatedAt.addingTimeInterval(SharedStorage.lockScreenFeedbackDuration)
            if feedbackEnd > now {
                entries.append(
                    makeEntry(
                        for: configuration,
                        nowPlaying: nowPlaying,
                        showInPlaylistWarning: showWarning,
                        date: feedbackEnd
                    )
                )
            }
        }

        entries.sort { $0.date < $1.date }

        let refreshDate = now.addingTimeInterval(SharedStorage.nowPlayingRefreshInterval)
        return Timeline(entries: entries, policy: .after(refreshDate))
    }

    private func makeCachedEntry(for configuration: ConfigurePlaylistWidgetIntent) -> PlaylistWidgetEntry {
        let playlist = WidgetPlaylistResolver.effectivePlaylist(widgetPlaylist: configuration.playlist)
        let playlistID = playlist?.id ?? SharedStorage.unconfiguredWidgetStatusKey
        let nowPlaying = WidgetNowPlayingFetcher.cached(for: playlistID)
        let showWarning = SharedStorage.shared.shouldShowDuplicateWarning(
            trackURI: nowPlaying?.trackURI,
            for: playlistID
        )

        return makeEntry(
            for: configuration,
            nowPlaying: nowPlaying,
            showInPlaylistWarning: showWarning,
            date: Date()
        )
    }

    private func makeEntry(
        for configuration: ConfigurePlaylistWidgetIntent,
        nowPlaying: WidgetNowPlayingInfo?,
        showInPlaylistWarning: Bool,
        date: Date
    ) -> PlaylistWidgetEntry {
        let playlist = WidgetPlaylistResolver.effectivePlaylist(widgetPlaylist: configuration.playlist)
        let playlistName = resolvedPlaylistName(for: playlist)
        let status = widgetStatus(for: playlist)
        let playlistID = playlist?.id ?? SharedStorage.unconfiguredWidgetStatusKey

        return PlaylistWidgetEntry(
            date: date,
            playlistEntity: playlist,
            playlistName: playlistName,
            statusMessage: status?.message,
            statusIsError: status?.isError ?? false,
            statusIsSuccess: status?.isSuccess ?? false,
            trackName: status?.trackName,
            artistName: status?.artistName,
            artworkData: SharedStorage.shared.widgetArtworkData(for: playlistID),
            nowPlayingTrackName: nowPlaying?.trackName,
            nowPlayingArtistName: nowPlaying?.artistName,
            nowPlayingArtworkData: nowPlaying?.artworkData,
            nowPlayingTrackURI: nowPlaying?.trackURI,
            showInPlaylistWarning: showInPlaylistWarning,
            statusUpdatedAt: status?.updatedAt
        )
    }

    private func resolvedPlaylistName(for playlist: PlaylistEntity?) -> String {
        guard let playlist else { return "Choose playlist in app" }
        let cachedName = SharedStorage.shared.cachedPlaylists()
            .first(where: { $0.id == playlist.id })?
            .name
        return cachedName ?? playlist.name
    }

    private func widgetStatus(for playlist: PlaylistEntity?) -> WidgetStatus? {
        if let playlist {
            return SharedStorage.shared.widgetStatus(for: playlist.id)
        }
        return SharedStorage.shared.widgetStatus(for: SharedStorage.unconfiguredWidgetStatusKey)
    }
}

struct WidgetNowPlayingInfo {
    let trackURI: String
    let trackName: String
    let artistName: String?
    let artworkData: Data?
}

enum WidgetNowPlayingFetcher {
    static func fetch(for playlist: PlaylistEntity?) async -> WidgetNowPlayingInfo? {
        let playlistID = playlist?.id ?? SharedStorage.unconfiguredWidgetStatusKey
        let tokenProvider = SpotifyTokenProvider()
        tokenProvider.refreshLoginState()

        guard tokenProvider.isLoggedIn else {
            return cached(for: playlistID)
        }

        let apiService = SpotifyAPIService(tokenProvider: tokenProvider)

        do {
            let track = try await apiService.fetchCurrentlyPlaying()
            guard let trackURI = track.uri else {
                SharedStorage.shared.clearNowPlayingCache(for: playlistID)
                return nil
            }

            if let playlistID = playlist?.id {
                let isInPlaylist = (try? await apiService.playlistContainsTrack(
                    playlistId: playlistID,
                    trackURI: trackURI
                )) ?? false

                if isInPlaylist {
                    SharedStorage.shared.recordInPlaylistWarningIfNeeded(
                        trackURI: trackURI,
                        for: playlistID
                    )
                }
            }

            var artworkData: Data?
            if let artworkURL = track.artworkURL {
                artworkData = await WidgetAddSongService.downloadArtwork(from: artworkURL)
                if let artworkData {
                    SharedStorage.shared.saveWidgetArtwork(artworkData, for: playlistID)
                }
            } else {
                artworkData = SharedStorage.shared.widgetArtworkData(for: playlistID)
            }

            let trackName = track.name ?? "Track"
            SharedStorage.shared.setNowPlayingCache(
                trackURI: trackURI,
                trackName: trackName,
                artistName: track.primaryArtist,
                for: playlistID
            )

            return WidgetNowPlayingInfo(
                trackURI: trackURI,
                trackName: trackName,
                artistName: track.primaryArtist,
                artworkData: artworkData
            )
        } catch let error as AppError where error == .nothingPlaying {
            SharedStorage.shared.clearNowPlayingCache(for: playlistID)
            return nil
        } catch {
            return cached(for: playlistID)
        }
    }

    static func cached(for playlistID: String) -> WidgetNowPlayingInfo? {
        guard let cache = SharedStorage.shared.nowPlayingCache(for: playlistID) else {
            return nil
        }

        return WidgetNowPlayingInfo(
            trackURI: cache.trackURI,
            trackName: cache.trackName,
            artistName: cache.artistName,
            artworkData: SharedStorage.shared.widgetArtworkData(for: playlistID)
        )
    }
}
