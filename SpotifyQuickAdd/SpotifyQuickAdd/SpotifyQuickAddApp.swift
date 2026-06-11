import SwiftUI

@main
struct SpotifyQuickAddApp: App {
    @StateObject private var settingsViewModel: SettingsViewModel
    @StateObject private var addSongViewModel: AddSongViewModel

    init() {
        let auth = SpotifyAuthService()
        let api = SpotifyAPIService(authService: auth)
        let manager = PlaylistManager(authService: auth, apiService: api)

        _settingsViewModel = StateObject(
            wrappedValue: SettingsViewModel(
                authService: auth,
                apiService: api,
                playlistManager: manager
            )
        )
        _addSongViewModel = StateObject(
            wrappedValue: AddSongViewModel(playlistManager: manager)
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                settingsViewModel: settingsViewModel,
                addSongViewModel: addSongViewModel
            )
            .onOpenURL { url in
                handleIncomingURL(url)
            }
        }
    }

    private func handleIncomingURL(_ url: URL) {
        guard url.scheme == SpotifyConfig.urlScheme else { return }

        switch url.host {
        case "callback":
            Task {
                await settingsViewModel.handleOAuthCallback(url: url)
            }
        case "add-current-song":
            Task {
                await addSongViewModel.addCurrentSongFromWidget()
            }
        default:
            break
        }
    }
}
