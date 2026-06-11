import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section("Spotify Account") {
                HStack {
                    Text("Status")
                    Spacer()
                    Text(viewModel.isLoggedIn ? "Signed In" : "Not Signed In")
                        .foregroundStyle(viewModel.isLoggedIn ? .green : .secondary)
                }

                if viewModel.isLoggedIn {
                    Button("Sign Out", role: .destructive) {
                        viewModel.logout()
                    }
                } else {
                    Button("Sign In with Spotify") {
                        Task { await viewModel.login() }
                    }
                    .disabled(viewModel.isLoading)
                }
            }

            Section("Playlist") {
                Text("Only playlists you own are shown. Followed playlists and Spotify mixes cannot be edited.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let selected = viewModel.selectedPlaylist {
                    Text("Selected: \(selected.name)")
                        .font(.subheadline)
                } else {
                    Text("No playlist selected")
                        .foregroundStyle(.secondary)
                }

                Button("Fetch Playlists") {
                    Task { await viewModel.fetchPlaylists() }
                }
                .disabled(!viewModel.isLoggedIn || viewModel.isLoading)

                if !viewModel.playlists.isEmpty {
                    PlaylistPickerView(
                        playlists: viewModel.playlists,
                        selectedPlaylistID: viewModel.selectedPlaylist?.id,
                        onSelect: viewModel.selectPlaylist
                    )
                }
            }

            Section("Test Workflow") {
                Text("Use this to test the same flow triggered by the Home Screen widget.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button("Test Add Current Song") {
                    Task { await viewModel.testAddCurrentSong() }
                }
                .disabled(!viewModel.isLoggedIn || viewModel.isLoading)
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView("Working…")
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .onAppear {
            viewModel.syncLoginState()
        }
    }
}

#Preview {
    let auth = SpotifyAuthService()
    let api = SpotifyAPIService(authService: auth)
    let manager = PlaylistManager(authService: auth, apiService: api)

    return NavigationStack {
        SettingsView(
            viewModel: SettingsViewModel(
                authService: auth,
                apiService: api,
                playlistManager: manager
            )
        )
    }
}
