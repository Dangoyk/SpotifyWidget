import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var settingsViewModel: SettingsViewModel
    @State private var foregroundRefreshTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            SettingsView(viewModel: settingsViewModel)
                .navigationTitle("Spotify Quick Add")
        }
        .overlay(alignment: .top) {
            if let message = settingsViewModel.statusMessage {
                ResultBannerView(message: message, isError: settingsViewModel.isError)
                    .padding()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut, value: settingsViewModel.statusMessage)
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                WidgetReloader.reloadWidgets()
                startForegroundRefreshLoop()
            case .background, .inactive:
                stopForegroundRefreshLoop()
            @unknown default:
                stopForegroundRefreshLoop()
            }
        }
    }

    private func startForegroundRefreshLoop() {
        stopForegroundRefreshLoop()
        foregroundRefreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(SharedStorage.nowPlayingRefreshInterval))
                guard !Task.isCancelled else { return }
                WidgetReloader.reloadWidgets()
            }
        }
    }

    private func stopForegroundRefreshLoop() {
        foregroundRefreshTask?.cancel()
        foregroundRefreshTask = nil
    }
}

struct ResultBannerView: View {
    let message: String
    let isError: Bool

    var body: some View {
        Text(message)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(isError ? Color.red : Color.green, in: RoundedRectangle(cornerRadius: 12))
            .shadow(radius: 4)
    }
}

#Preview {
    let auth = SpotifyAuthService()
    let api = SpotifyAPIService(tokenProvider: auth)
    let manager = PlaylistManager(tokenProvider: auth, apiService: api)

    return ContentView(
        settingsViewModel: SettingsViewModel(
            authService: auth,
            apiService: api,
            playlistManager: manager
        )
    )
}
