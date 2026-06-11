import SwiftUI

struct PlaylistPickerView: View {
    let playlists: [SpotifyPlaylist]
    let selectedPlaylistID: String?
    let onSelect: (SpotifyPlaylist) -> Void

    var body: some View {
        ForEach(playlists) { playlist in
            Button {
                onSelect(playlist)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(playlist.name)
                            .foregroundStyle(.primary)
                        if let owner = playlist.owner?.displayName {
                            Text(owner)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if playlist.id == selectedPlaylistID {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }
        }
    }
}
