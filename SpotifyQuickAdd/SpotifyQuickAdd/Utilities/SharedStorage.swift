import Foundation

struct SelectedPlaylist: Equatable {
    let id: String
    let name: String
}

final class SharedStorage {
    static let shared = SharedStorage()

    private enum Keys {
        static let selectedPlaylistID = "selectedPlaylistID"
        static let selectedPlaylistName = "selectedPlaylistName"
    }

    private let defaults: UserDefaults

    init(suiteName: String = SpotifyConfig.appGroupIdentifier) {
        defaults = UserDefaults(suiteName: suiteName) ?? .standard
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
        }
    }
}
