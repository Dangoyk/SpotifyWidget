import Foundation

struct SelectedPlaylist: Equatable, Codable {
    let id: String
    let name: String
}

struct CachedPlaylist: Codable, Identifiable, Equatable {
    let id: String
    let name: String
}

struct WidgetStatus: Codable, Equatable {
    let message: String
    let isError: Bool
    let isSuccess: Bool
    let updatedAt: Date
    let trackName: String?
    let artistName: String?

    init(
        message: String,
        isError: Bool,
        isSuccess: Bool,
        updatedAt: Date = Date(),
        trackName: String? = nil,
        artistName: String? = nil
    ) {
        self.message = message
        self.isError = isError
        self.isSuccess = isSuccess
        self.updatedAt = updatedAt
        self.trackName = trackName
        self.artistName = artistName
    }
}

final class SharedStorage {
    static let shared = SharedStorage()
    static let unconfiguredWidgetStatusKey = "unconfigured"

    private enum Keys {
        static let selectedPlaylistID = "selectedPlaylistID"
        static let selectedPlaylistName = "selectedPlaylistName"
        static let cachedPlaylists = "cachedPlaylistsJSON"
        static let widgetStatusPrefix = "widgetStatus_"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private let suiteName: String
    private let usesAppGroup: Bool

    init(suiteName: String = SpotifyConfig.appGroupIdentifier) {
        self.suiteName = suiteName
        usesAppGroup = UserDefaults(suiteName: suiteName) != nil
        defaults = UserDefaults(suiteName: suiteName) ?? .standard
    }

    var isAppGroupAvailable: Bool {
        usesAppGroup
    }

    private func persist() {
        defaults.synchronize()
    }

    var selectedPlaylist: SelectedPlaylist? {
        get {
            guard
                let id = defaults.string(forKey: Keys.selectedPlaylistID),
                let name = defaults.string(forKey: Keys.selectedPlaylistName),
                !id.isEmpty
            else {
                return nil
            }
            return SelectedPlaylist(id: id, name: name)
        }
        set {
            if let newValue {
                defaults.set(newValue.id, forKey: Keys.selectedPlaylistID)
                defaults.set(newValue.name, forKey: Keys.selectedPlaylistName)
            } else {
                defaults.removeObject(forKey: Keys.selectedPlaylistID)
                defaults.removeObject(forKey: Keys.selectedPlaylistName)
            }
            persist()
        }
    }

    func cachePlaylists(_ playlists: [SpotifyPlaylist]) {
        let cached = playlists.map { CachedPlaylist(id: $0.id, name: $0.name) }
        guard let data = try? encoder.encode(cached) else { return }
        defaults.set(data, forKey: Keys.cachedPlaylists)
        persist()
    }

    func clearCachedPlaylists() {
        defaults.removeObject(forKey: Keys.cachedPlaylists)
        persist()
    }

    func cachedPlaylists() -> [CachedPlaylist] {
        guard
            let data = defaults.data(forKey: Keys.cachedPlaylists),
            let playlists = try? decoder.decode([CachedPlaylist].self, from: data)
        else {
            return []
        }
        return playlists
    }

    func widgetStatus(for playlistID: String) -> WidgetStatus? {
        guard
            let data = defaults.data(forKey: Keys.widgetStatusPrefix + playlistID),
            let status = try? decoder.decode(WidgetStatus.self, from: data)
        else {
            return nil
        }
        return status
    }

    func setWidgetStatus(
        for playlistID: String,
        message: String,
        isError: Bool,
        isSuccess: Bool,
        trackName: String? = nil,
        artistName: String? = nil,
        artworkData: Data? = nil
    ) {
        if isError {
            clearWidgetArtwork(for: playlistID)
        } else if let artworkData {
            saveWidgetArtwork(artworkData, for: playlistID)
        }

        let status = WidgetStatus(
            message: message,
            isError: isError,
            isSuccess: isSuccess,
            trackName: trackName,
            artistName: artistName
        )
        guard let data = try? encoder.encode(status) else { return }
        defaults.set(data, forKey: Keys.widgetStatusPrefix + playlistID)
        persist()
    }

    func clearWidgetStatus(for playlistID: String) {
        defaults.removeObject(forKey: Keys.widgetStatusPrefix + playlistID)
        clearWidgetArtwork(for: playlistID)
        persist()
    }

    func widgetArtworkURL(for playlistID: String) -> URL? {
        guard usesAppGroup, let url = artworkFileURL(for: playlistID) else { return nil }
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    @discardableResult
    func saveWidgetArtwork(_ data: Data, for playlistID: String) -> URL? {
        guard let fileURL = artworkFileURL(for: playlistID) else { return nil }

        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            return nil
        }
    }

    func clearWidgetArtwork(for playlistID: String) {
        guard let url = artworkFileURL(for: playlistID),
              FileManager.default.fileExists(atPath: url.path) else {
            return
        }
        try? FileManager.default.removeItem(at: url)
    }

    private func artworkFileURL(for playlistID: String) -> URL? {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: suiteName
        ) else {
            return nil
        }

        return container
            .appendingPathComponent("WidgetArtwork", isDirectory: true)
            .appendingPathComponent("\(playlistID).jpg")
    }
}
