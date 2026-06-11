import SwiftUI

struct ContentView: View {
    @ObservedObject var settingsViewModel: SettingsViewModel
    @ObservedObject var addSongViewModel: AddSongViewModel

    var body: some View {
        NavigationStack {
            SettingsView(viewModel: settingsViewModel)
                .navigationTitle("Spotify Quick Add")
        }
        .overlay(alignment: .top) {
            if let message = bannerMessage {
                ResultBannerView(message: message, isError: bannerIsError)
                    .padding()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut, value: bannerMessage)
    }

    private var bannerMessage: String? {
        addSongViewModel.resultMessage ?? settingsViewModel.statusMessage
    }

    private var bannerIsError: Bool {
        if addSongViewModel.resultMessage != nil {
            return addSongViewModel.isError
        }
        return settingsViewModel.isError
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
    let api = SpotifyAPIService(authService: auth)
    let manager = PlaylistManager(authService: auth, apiService: api)

    return ContentView(
        settingsViewModel: SettingsViewModel(
            authService: auth,
            apiService: api,
            playlistManager: manager
        ),
        addSongViewModel: AddSongViewModel(playlistManager: manager)
    )
}
