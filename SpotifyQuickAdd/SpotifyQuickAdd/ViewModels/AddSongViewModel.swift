import Foundation

@MainActor
final class AddSongViewModel: ObservableObject {
    @Published private(set) var resultMessage: String?
    @Published private(set) var isError = false
    @Published private(set) var isProcessing = false

    private let playlistManager: PlaylistManager

    init(playlistManager: PlaylistManager) {
        self.playlistManager = playlistManager
    }

    func addCurrentSongFromWidget() async {
        guard !isProcessing else { return }

        isProcessing = true
        resultMessage = nil
        isError = false

        let result = await playlistManager.addCurrentTrackToSelectedPlaylist()

        switch result {
        case .success(let message):
            resultMessage = message
            isError = false
        case .failure(let error):
            resultMessage = error.errorDescription
            isError = true
        }

        isProcessing = false
    }

    func clearResult() {
        resultMessage = nil
        isError = false
    }
}
