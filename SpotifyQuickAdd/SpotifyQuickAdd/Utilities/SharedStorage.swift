import Foundation

struct SelectedPlaylist: Equatable, Codable {
    let id: String
    let name: String
}

struct CachedPlaylist: Codable, Identifiable, Equatable {
    let id: String
    let name: String
}

struct WidgetDuplicateWarning: Codable, Equatable {
    let trackURI: String
    let shownAt: Date
}

struct WidgetNowPlayingCache: Codable, Equatable {
    let trackURI: String
    let trackName: String
    let artistName: String?
    let updatedAt: Date
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
        static let widgetArtworkDataPrefix = "widgetArtworkData_"
        static let widgetDuplicateWarningPrefix = "widgetDuplicateWarning_"
        static let widgetNowPlayingPrefix = "widgetNowPlaying_"
    }

    static let duplicateWarningDuration: TimeInterval = 8
    static let lockScreenFeedbackDuration: TimeInterval = 8
    static let nowPlayingRefreshInterval: TimeInterval = 30

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private let suiteName: String
    private let usesAppGroup: Bool

    init(suiteName: String = SpotifyConfig.appGroupIdentifier) {
        self.suiteName = suiteName
        let hasContainer = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: suiteName
        ) != nil
        usesAppGroup = hasContainer
        if hasContainer, let groupDefaults = UserDefaults(suiteName: suiteName) {
            defaults = groupDefaults
        } else {
            defaults = .standard
        }
    }

    var isAppGroupAvailable: Bool {
        usesAppGroup
    }

    var cachedPlaylistCount: Int {
        cachedPlaylists().count
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

        if let fileURL = playlistCacheFileURL {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    func clearCachedPlaylists() {
        defaults.removeObject(forKey: Keys.cachedPlaylists)
        persist()

        if let fileURL = playlistCacheFileURL,
           FileManager.default.fileExists(atPath: fileURL.path) {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    func cachedPlaylists() -> [CachedPlaylist] {
        let fromFile = loadCachedPlaylists(from: playlistCacheFileURL)
        if !fromFile.isEmpty {
            return fromFile
        }
        return loadCachedPlaylists(fromDefaultsKey: Keys.cachedPlaylists)
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
        if let artworkData, !artworkData.isEmpty {
            saveWidgetArtwork(artworkData, for: playlistID)
        } else if isError {
            clearWidgetArtwork(for: playlistID)
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

    func duplicateWarning(for playlistID: String) -> WidgetDuplicateWarning? {
        guard
            let data = defaults.data(forKey: Keys.widgetDuplicateWarningPrefix + playlistID),
            let warning = try? decoder.decode(WidgetDuplicateWarning.self, from: data)
        else {
            return nil
        }
        return warning
    }

    func setDuplicateWarning(trackURI: String, for playlistID: String, at date: Date = Date()) {
        let warning = WidgetDuplicateWarning(trackURI: trackURI, shownAt: date)
        guard let data = try? encoder.encode(warning) else { return }
        defaults.set(data, forKey: Keys.widgetDuplicateWarningPrefix + playlistID)
        persist()
    }

    func shouldShowDuplicateWarning(trackURI: String?, for playlistID: String, at date: Date = Date()) -> Bool {
        guard let trackURI,
              let warning = duplicateWarning(for: playlistID),
              warning.trackURI == trackURI else {
            return false
        }
        return date.timeIntervalSince(warning.shownAt) < Self.duplicateWarningDuration
    }

    func recordInPlaylistWarningIfNeeded(trackURI: String, for playlistID: String) {
        if duplicateWarning(for: playlistID)?.trackURI != trackURI {
            setDuplicateWarning(trackURI: trackURI, for: playlistID)
        }
    }

    func nowPlayingCache(for playlistID: String) -> WidgetNowPlayingCache? {
        guard
            let data = defaults.data(forKey: Keys.widgetNowPlayingPrefix + playlistID),
            let cache = try? decoder.decode(WidgetNowPlayingCache.self, from: data)
        else {
            return nil
        }
        return cache
    }

    func setNowPlayingCache(
        trackURI: String,
        trackName: String,
        artistName: String?,
        for playlistID: String
    ) {
        let cache = WidgetNowPlayingCache(
            trackURI: trackURI,
            trackName: trackName,
            artistName: artistName,
            updatedAt: Date()
        )
        guard let data = try? encoder.encode(cache) else { return }
        defaults.set(data, forKey: Keys.widgetNowPlayingPrefix + playlistID)
        persist()
    }

    func clearNowPlayingCache(for playlistID: String) {
        defaults.removeObject(forKey: Keys.widgetNowPlayingPrefix + playlistID)
        persist()
    }

    func widgetArtworkURL(for playlistID: String) -> URL? {
        guard let url = artworkFileURL(for: playlistID),
              FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return url
    }

    func widgetArtworkData(for playlistID: String) -> Data? {
        if let url = widgetArtworkURL(for: playlistID),
           let data = try? Data(contentsOf: url),
           !data.isEmpty {
            return data
        }

        guard let data = defaults.data(forKey: Keys.widgetArtworkDataPrefix + playlistID),
              !data.isEmpty else {
            return nil
        }
        return data
    }

    @discardableResult
    func saveWidgetArtwork(_ data: Data, for playlistID: String) -> Bool {
        defaults.set(data, forKey: Keys.widgetArtworkDataPrefix + playlistID)
        persist()

        guard let fileURL = artworkFileURL(for: playlistID) else {
            return true
        }

        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: fileURL, options: .atomic)
            return true
        } catch {
            return true
        }
    }

    func clearWidgetArtwork(for playlistID: String) {
        defaults.removeObject(forKey: Keys.widgetArtworkDataPrefix + playlistID)
        persist()

        guard let url = artworkFileURL(for: playlistID),
              FileManager.default.fileExists(atPath: url.path) else {
            return
        }
        try? FileManager.default.removeItem(at: url)
    }

    private var playlistCacheFileURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName)?
            .appendingPathComponent("cachedPlaylists.json")
    }

    private func artworkFileURL(for playlistID: String) -> URL? {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: suiteName
        ) else {
            return nil
        }

        return container
            .appendingPathComponent("WidgetArtwork", isDirectory: true)
            .appendingPathComponent("\(sanitizedFileComponent(playlistID)).jpg")
    }

    private func loadCachedPlaylists(from url: URL?) -> [CachedPlaylist] {
        guard let url,
              let data = try? Data(contentsOf: url),
              let playlists = try? decoder.decode([CachedPlaylist].self, from: data) else {
            return []
        }
        return playlists
    }

    private func loadCachedPlaylists(fromDefaultsKey key: String) -> [CachedPlaylist] {
        guard
            let data = defaults.data(forKey: key),
            let playlists = try? decoder.decode([CachedPlaylist].self, from: data)
        else {
            return []
        }
        return playlists
    }

    private func sanitizedFileComponent(_ value: String) -> String {
        value.replacingOccurrences(of: "/", with: "_")
    }
}
