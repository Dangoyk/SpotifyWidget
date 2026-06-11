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

            Section("Widget Playlist") {
                Text("Pick the playlist your widgets add songs to. Lock Screen widgets use this selection from the app — you do not need to configure them on the lock screen.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if viewModel.isLoggedIn {
                    if viewModel.cachedPlaylistCount > 0 {
                        Text("\(viewModel.cachedPlaylistCount) playlist(s) ready for widget setup.")
                            .font(.footnote)
                            .foregroundStyle(.green)
                    } else {
                        Text("No playlists cached yet. Tap Fetch Playlists, then try configuring a widget again.")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }

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

            Section("Add Widgets") {
                Text("1. Sign in and fetch playlists above\n2. Select a playlist\n3. Add Spotify Quick Add from the Home Screen or Lock Screen widget gallery")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text("Optional: long-press a Home Screen widget → Edit Widget to give that widget its own playlist.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Test Workflow") {
                Text("Test adding to the playlist selected above. Widgets use the same playlist unless a Home Screen widget was edited separately.")
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
            WidgetReloader.reloadWidgets()
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
