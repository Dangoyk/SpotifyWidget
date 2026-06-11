import AppIntents
import SwiftUI
import WidgetKit

struct PlaylistWidgetEntry: TimelineEntry {
    let date: Date
    let playlistEntity: PlaylistEntity?
    let playlistName: String
    let statusMessage: String?
    let statusIsError: Bool
    let statusIsSuccess: Bool
}

struct AddCurrentSongWidgetView: View {
    let entry: PlaylistWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.playlistName)
                .font(.headline)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            if let playlist = entry.playlistEntity {
                Button(intent: AddCurrentSongIntent(playlist: playlist)) {
                    Label("Add Current Song", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.11, green: 0.73, blue: 0.33))
            } else {
                Text("❌ Please configure this widget with a playlist.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if let status = entry.statusMessage {
                Text(status)
                    .font(.caption2)
                    .foregroundStyle(entry.statusIsError ? .red : .green)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding()
        .containerBackground(for: .widget) {
            Color(red: 0.08, green: 0.08, blue: 0.10)
        }
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
        .supportedFamilies([.systemSmall, .systemMedium])
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
            statusIsSuccess: false
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

        return PlaylistWidgetEntry(
            date: Date(),
            playlistEntity: playlist,
            playlistName: playlistName,
            statusMessage: status?.message,
            statusIsError: status?.isError ?? false,
            statusIsSuccess: status?.isSuccess ?? false
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
