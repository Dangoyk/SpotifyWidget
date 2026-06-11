import SwiftUI

@main
struct SpotifyQuickAddApp: App {
    @StateObject private var settingsViewModel: SettingsViewModel

    init() {
        let auth = SpotifyAuthService()
        let api = SpotifyAPIService(tokenProvider: auth)
        let manager = PlaylistManager(tokenProvider: auth, apiService: api)

        _settingsViewModel = StateObject(
            wrappedValue: SettingsViewModel(
                authService: auth,
                apiService: api,
                playlistManager: manager
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView(settingsViewModel: settingsViewModel)
                .onOpenURL { url in
                    Task {
                        await settingsViewModel.handleIncomingURL(url)
                    }
                }
        }
    }
}
