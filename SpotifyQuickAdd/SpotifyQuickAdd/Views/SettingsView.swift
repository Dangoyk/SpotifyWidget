import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        Form {
            Section("Spotify Account") {
                if !SharedStorage.shared.isAppGroupAvailable {
                    Text("App Group is not configured. Widgets will not work until App Groups are enabled on both targets.")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

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
                Text("Fetch playlists here first so they appear when configuring Home Screen widgets. Only playlists you own are shown.")
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

            Section("Home Screen Widgets (A+)") {
                Text("After fetching playlists, add widgets from the Home Screen gallery. Configure each widget with a different playlist (Favorites, Gym, etc.).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Test Workflow") {
                Text("Test adding to the playlist selected above (app settings). Widgets use their own configured playlist.")
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
    let api = SpotifyAPIService(tokenProvider: auth)
    let manager = PlaylistManager(tokenProvider: auth, apiService: api)

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
