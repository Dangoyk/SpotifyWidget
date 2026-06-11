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

            if entry.hasTrackResult {
                HStack(alignment: .top, spacing: 8) {
                    WidgetArtworkImage(
                        artworkData: entry.artworkData,
                        size: artworkSize,
                        cornerRadius: 8
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.trackName ?? "")
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                        if let artistName = entry.artistName {
                            Text(artistName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)
                        }
                        if entry.isDuplicateTrackResult {
                            Text("Already in playlist")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                                .lineLimit(1)
                        }
                    }
                }
            } else if entry.statusMessage != nil {
                Text(entry.cleanStatusMessage)
                    .font(.caption2)
                    .foregroundStyle(entry.statusTextColor)
                    .lineLimit(3)
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
                Text("Configure this widget with a playlist.")
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
        if let playlist = entry.playlistEntity {
            Button(intent: AddCurrentSongIntent(playlist: playlist)) {
                Label {
                    Text(entry.inlineActionText)
                        .lineLimit(2)
                } icon: {
                    Image(systemName: entry.statusIsSuccess ? "checkmark.circle" : "music.note.list")
                }
            }
            .buttonStyle(.plain)
        } else {
            Label("Set up playlist", systemImage: "exclamationmark.triangle")
        }
    }
}

struct LockScreenCircularWidgetView: View {
    let entry: PlaylistWidgetEntry

    var body: some View {
        if let playlist = entry.playlistEntity {
            Button(intent: AddCurrentSongIntent(playlist: playlist)) {
                ZStack {
                    if entry.showsArtwork,
                       let data = entry.artworkData,
                       let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .clipShape(Circle())
                    } else {
                        AccessoryWidgetBackground()
                        Image(systemName: "plus")
                            .font(.title2.weight(.semibold))
                    }
                }
            }
            .buttonStyle(.plain)
        } else {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "exclamationmark")
                    .font(.title3.weight(.semibold))
            }
        }
    }
}

struct LockScreenRectangularWidgetView: View {
    let entry: PlaylistWidgetEntry

    var body: some View {
        if let playlist = entry.playlistEntity {
            Button(intent: AddCurrentSongIntent(playlist: playlist)) {
                HStack(alignment: .top, spacing: 8) {
                    if entry.showsArtwork {
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

                        if entry.hasTrackResult, let trackName = entry.trackName {
                            Text(trackName)
                                .font(.caption.weight(.semibold))
                                .lineLimit(2)
                            if let artistName = entry.artistName {
                                Text(artistName)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        } else {
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
                Text("Configure playlist")
                    .font(.caption)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private extension PlaylistWidgetEntry {
    var hasTrackResult: Bool {
        statusIsSuccess && trackName != nil
    }

    var isDuplicateTrackResult: Bool {
        cleanStatusMessage.localizedCaseInsensitiveContains("already in playlist")
    }

    var showsArtwork: Bool {
        hasTrackResult && artworkData != nil
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
        if statusIsSuccess, let trackName {
            if let artistName {
                return "\(trackName) · \(artistName)"
            }
            return trackName
        }
        return "Add to \(shortPlaylistName)"
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
            artworkData: nil
        )
    }

    func snapshot(for configuration: ConfigurePlaylistWidgetIntent, in context: Context) async -> PlaylistWidgetEntry {
        makeEntry(for: configuration)
    }

    func timeline(for configuration: ConfigurePlaylistWidgetIntent, in context: Context) async -> Timeline<PlaylistWidgetEntry> {
        let entry = makeEntry(for: configuration)
        return Timeline(entries: [entry], policy: .atEnd)
    }

    private func makeEntry(for configuration: ConfigurePlaylistWidgetIntent) -> PlaylistWidgetEntry {
        let playlist = configuration.playlist
        let playlistName = resolvedPlaylistName(for: playlist)
        let status = widgetStatus(for: playlist)
        let playlistID = playlist?.id ?? SharedStorage.unconfiguredWidgetStatusKey

        return PlaylistWidgetEntry(
            date: Date(),
            playlistEntity: playlist,
            playlistName: playlistName,
            statusMessage: status?.message,
            statusIsError: status?.isError ?? false,
            statusIsSuccess: status?.isSuccess ?? false,
            trackName: status?.trackName,
            artistName: status?.artistName,
            artworkData: SharedStorage.shared.widgetArtworkData(for: playlistID)
        )
    }

    private func resolvedPlaylistName(for playlist: PlaylistEntity?) -> String {
        guard let playlist else { return "Not configured" }
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
