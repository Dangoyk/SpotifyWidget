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
        static let widgetResultArtworkPrefix = "widgetResultArtwork_"
        static let widgetNowPlayingArtworkPrefix = "widgetNowPlayingArtwork_"
        static let widgetDuplicateWarningPrefix = "widgetDuplicateWarning_"
        static let widgetNowPlayingPrefix = "widgetNowPlaying_"
    }

    static let duplicateWarningDuration: TimeInterval = 8
    static let lockScreenFeedbackDuration: TimeInterval = 8
    static let nowPlayingRefreshInterval: TimeInterval = 15

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
            saveResultArtwork(artworkData, for: playlistID)
        } else if isError {
            clearResultArtwork(for: playlistID)
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
        clearResultArtwork(for: playlistID)
        persist()
    }

    func clearDuplicateWarning(for playlistID: String) {
        defaults.removeObject(forKey: Keys.widgetDuplicateWarningPrefix + playlistID)
        persist()
    }

    func clearAllWidgetState() {
        var playlistIDs = Set(cachedPlaylists().map(\.id))
        playlistIDs.insert(Self.unconfiguredWidgetStatusKey)
        if let selected = selectedPlaylist {
            playlistIDs.insert(selected.id)
        }

        for playlistID in playlistIDs {
            clearWidgetStatus(for: playlistID)
            clearNowPlayingCache(for: playlistID)
            clearNowPlayingArtwork(for: playlistID)
            clearDuplicateWarning(for: playlistID)
        }
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

    func resultArtworkData(for playlistID: String) -> Data? {
        artworkData(
            defaultsKey: Keys.widgetResultArtworkPrefix + playlistID,
            fileName: "result_\(sanitizedFileComponent(playlistID)).jpg"
        )
    }

    func nowPlayingArtworkData(for playlistID: String) -> Data? {
        artworkData(
            defaultsKey: Keys.widgetNowPlayingArtworkPrefix + playlistID,
            fileName: "nowPlaying_\(sanitizedFileComponent(playlistID)).jpg"
        )
    }

    @discardableResult
    func saveResultArtwork(_ data: Data, for playlistID: String) -> Bool {
        saveArtwork(
            data,
            defaultsKey: Keys.widgetResultArtworkPrefix + playlistID,
            fileName: "result_\(sanitizedFileComponent(playlistID)).jpg"
        )
    }

    @discardableResult
    func saveNowPlayingArtwork(_ data: Data, for playlistID: String) -> Bool {
        saveArtwork(
            data,
            defaultsKey: Keys.widgetNowPlayingArtworkPrefix + playlistID,
            fileName: "nowPlaying_\(sanitizedFileComponent(playlistID)).jpg"
        )
    }

    func clearResultArtwork(for playlistID: String) {
        clearArtwork(
            defaultsKey: Keys.widgetResultArtworkPrefix + playlistID,
            fileName: "result_\(sanitizedFileComponent(playlistID)).jpg"
        )
    }

    func clearNowPlayingArtwork(for playlistID: String) {
        clearArtwork(
            defaultsKey: Keys.widgetNowPlayingArtworkPrefix + playlistID,
            fileName: "nowPlaying_\(sanitizedFileComponent(playlistID)).jpg"
        )
    }

    private func artworkData(defaultsKey: String, fileName: String) -> Data? {
        if let url = artworkFileURL(fileName: fileName),
           let data = try? Data(contentsOf: url),
           !data.isEmpty {
            return data
        }

        guard let data = defaults.data(forKey: defaultsKey), !data.isEmpty else {
            return nil
        }
        return data
    }

    @discardableResult
    private func saveArtwork(_ data: Data, defaultsKey: String, fileName: String) -> Bool {
        defaults.set(data, forKey: defaultsKey)
        persist()

        guard let fileURL = artworkFileURL(fileName: fileName) else {
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
            return false
        }
    }

    private func clearArtwork(defaultsKey: String, fileName: String) {
        defaults.removeObject(forKey: defaultsKey)
        persist()

        guard let url = artworkFileURL(fileName: fileName),
              FileManager.default.fileExists(atPath: url.path) else {
            return
        }
        try? FileManager.default.removeItem(at: url)
    }

    private var playlistCacheFileURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName)?
            .appendingPathComponent("cachedPlaylists.json")
    }

    private func artworkFileURL(fileName: String) -> URL? {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: suiteName
        ) else {
            return nil
        }

        return container
            .appendingPathComponent("WidgetArtwork", isDirectory: true)
            .appendingPathComponent(fileName)
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
