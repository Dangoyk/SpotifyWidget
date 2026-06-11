import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published private(set) var isLoggedIn = false
    @Published var playlists: [SpotifyPlaylist] = []
    @Published var selectedPlaylist: SelectedPlaylist?
    @Published var isLoading = false
    @Published var statusMessage: String?
    @Published var isError = false

    private let authService: SpotifyAuthService
    private let apiService: SpotifyAPIService
    private let playlistManager: PlaylistManager
    private let storage: SharedStorage

    init(
        authService: SpotifyAuthService,
        apiService: SpotifyAPIService,
        playlistManager: PlaylistManager,
        storage: SharedStorage = .shared
    ) {
        self.authService = authService
        self.apiService = apiService
        self.playlistManager = playlistManager
        self.storage = storage
        self.selectedPlaylist = storage.selectedPlaylist
        syncLoginState()
    }

    func syncLoginState() {
        authService.refreshLoginState()
        isLoggedIn = authService.isLoggedIn
        selectedPlaylist = storage.selectedPlaylist
    }

    func handleOAuthCallback(url: URL) async {
        isLoading = true
        clearStatus()

        do {
            try await authService.handleCallback(url: url)
            isLoggedIn = authService.isLoggedIn
            showSuccess("Signed in to Spotify.")
        } catch let error as AppError {
            showError(error)
        } catch {
            showError(.networkFailure(error.localizedDescription))
        }

        isLoading = false
    }

    func login() async {
        isLoading = true
        clearStatus()

        do {
            try await authService.startLogin()
            isLoggedIn = authService.isLoggedIn
            showSuccess("Signed in to Spotify.")
        } catch let error as AppError {
            showError(error)
        } catch {
            showError(.networkFailure(error.localizedDescription))
        }

        isLoading = false
    }

    func logout() {
        authService.logout()
        playlists = []
        selectedPlaylist = nil
        storage.selectedPlaylist = nil
        isLoggedIn = false
        showSuccess("Signed out of Spotify.")
    }

    func fetchPlaylists() async {
        guard isLoggedIn else {
            showError(.loginRequired)
            return
        }

        isLoading = true
        clearStatus()

        do {
            playlists = try await apiService.fetchEditablePlaylists()

            if let selected = selectedPlaylist,
               !playlists.contains(where: { $0.id == selected.id }) {
                selectedPlaylist = nil
                storage.selectedPlaylist = nil
            }

            if playlists.isEmpty {
                showSuccess("No editable playlists found. Create a playlist in Spotify first.")
            } else {
                showSuccess("Loaded \(playlists.count) editable playlist(s).")
            }
        } catch let error as AppError {
            showError(error)
        } catch {
            showError(.networkFailure(error.localizedDescription))
        }

        isLoading = false
    }

    func selectPlaylist(_ playlist: SpotifyPlaylist) {
        let selected = SelectedPlaylist(id: playlist.id, name: playlist.name)
        selectedPlaylist = selected
        storage.selectedPlaylist = selected
        showSuccess("Selected \"\(playlist.name)\".")
    }

    func testAddCurrentSong() async -> Result<String, AppError> {
        guard isLoggedIn else {
            let error = AppError.loginRequired
            showError(error)
            return .failure(error)
        }

        isLoading = true
        clearStatus()

        let result = await playlistManager.addCurrentTrackToSelectedPlaylist()

        switch result {
        case .success(let message):
            showSuccess(message)
        case .failure(let error):
            showError(error)
        }

        isLoading = false
        return result
    }

    private func showSuccess(_ message: String) {
        statusMessage = message
        isError = false
    }

    private func showError(_ error: AppError) {
        statusMessage = error.errorDescription
        isError = true
    }

    private func clearStatus() {
        statusMessage = nil
        isError = false
    }
}
