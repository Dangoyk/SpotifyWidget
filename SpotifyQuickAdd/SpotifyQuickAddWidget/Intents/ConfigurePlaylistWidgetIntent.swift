import AppIntents
import WidgetKit

struct ConfigurePlaylistWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Spotify Quick Add"
    static var description = IntentDescription("Choose which playlist this widget adds songs to.")

    @Parameter(title: "Playlist", default: nil)
    var playlist: PlaylistEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Add songs to \(\.$playlist)")
    }
}
