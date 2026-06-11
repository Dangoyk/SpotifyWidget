import Foundation
import WidgetKit

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published private(set) var isLoggedIn = false
    @Published var playlists: [SpotifyPlaylist] = []
    @Published var selectedPlaylist: SelectedPlaylist?
    @Published var isLoading = false
    @Published var statusMessage: String?
    @Published var isError = false
    @Published private(set) var cachedPlaylistCount = 0

    private let authService: SpotifyAuthService
    private let apiService: SpotifyAPIService
    private let playlistManager: PlaylistManager
    private let storage: SharedStorage
    private var didAttemptPlaylistBootstrap = false

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
        refreshCachedPlaylistCount()

        guard isLoggedIn, cachedPlaylistCount == 0, !didAttemptPlaylistBootstrap else { return }
        didAttemptPlaylistBootstrap = true
        Task { await fetchPlaylists(preserveStatusMessage: true) }
    }

    func refreshCachedPlaylistCount() {
        cachedPlaylistCount = storage.cachedPlaylistCount
    }

    func handleIncomingURL(_ url: URL) async {
        guard url.scheme == SpotifyConfig.urlScheme else { return }

        switch url.host {
        case "callback":
            let wasLoggedIn = isLoggedIn
            do {
                try await authService.handleCallback(url: url)
                isLoggedIn = authService.isLoggedIn

                guard !wasLoggedIn, isLoggedIn else { return }

                showSuccess("Signed in to Spotify.")
                await fetchPlaylists(preserveStatusMessage: true)
            } catch let error as AppError {
                showError(error)
            } catch {
                showError(.networkFailure(error.localizedDescription))
            }
        default:
            break
        }
    }

    func login() async {
        isLoading = true
        clearStatus()

        do {
            try await authService.startLogin()
            isLoggedIn = authService.isLoggedIn
            showSuccess("Signed in to Spotify.")
            await fetchPlaylists(preserveStatusMessage: true)
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
        storage.clearCachedPlaylists()
        isLoggedIn = false
        didAttemptPlaylistBootstrap = false
        refreshCachedPlaylistCount()
        WidgetCenter.shared.reloadTimelines(ofKind: SpotifyConfig.widgetKind)
        showSuccess("Signed out of Spotify.")
    }

    func fetchPlaylists(preserveStatusMessage: Bool = false) async {
        guard isLoggedIn else {
            showError(.loginRequired)
            return
        }

        isLoading = true
        if !preserveStatusMessage {
            clearStatus()
        }

        do {
            playlists = try await apiService.fetchEditablePlaylists()
            storage.cachePlaylists(playlists)
            refreshCachedPlaylistCount()
            WidgetCenter.shared.reloadTimelines(ofKind: SpotifyConfig.widgetKind)

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
            if preserveStatusMessage {
                showError(.unknown("Signed in, but could not load playlists. \(error.errorDescription ?? "Try Fetch Playlists again.")"))
            } else {
                showError(error)
            }
        } catch {
            if preserveStatusMessage {
                showError(.unknown("Signed in, but could not load playlists. \(error.localizedDescription)"))
            } else {
                showError(.networkFailure(error.localizedDescription))
            }
        }

        isLoading = false
    }

    func selectPlaylist(_ playlist: SpotifyPlaylist) {
        let selected = SelectedPlaylist(id: playlist.id, name: playlist.name)
        selectedPlaylist = selected
        storage.selectedPlaylist = selected
        showSuccess("Selected \"\(playlist.name)\".")
    }

    func testAddCurrentSong() async -> Result<AddedTrackResult, AppError> {
        guard isLoggedIn else {
            let error = AppError.loginRequired
            showError(error)
            return .failure(error)
        }

        isLoading = true
        clearStatus()

        let result = await playlistManager.addCurrentTrackToSelectedPlaylist()

        switch result {
        case .success(let added):
            showSuccess(added.message)
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
