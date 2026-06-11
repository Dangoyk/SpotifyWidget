import Foundation

actor WidgetAddSongLock {
    static let shared = WidgetAddSongLock()

    private var inFlightPlaylistIDs = Set<String>()

    func perform<T>(
        playlistID: String,
        ifBusy: () -> T,
        operation: () async -> T
    ) async -> T {
        if inFlightPlaylistIDs.contains(playlistID) {
            return ifBusy()
        }

        inFlightPlaylistIDs.insert(playlistID)
        defer { inFlightPlaylistIDs.remove(playlistID) }

        return await operation()
    }
}
