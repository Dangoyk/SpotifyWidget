import AppIntents
import Foundation

struct PlaylistEntity: AppEntity, Identifiable, Codable, Sendable {
    var id: String
    var name: String

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Playlist")
    static var defaultQuery = PlaylistEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct PlaylistEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [PlaylistEntity.ID]) async throws -> [PlaylistEntity] {
        let cached = SharedStorage.shared.cachedPlaylists()
        let cachedByID = Dictionary(uniqueKeysWithValues: cached.map { ($0.id, $0) })

        return identifiers.map { id in
            if let playlist = cachedByID[id] {
                return PlaylistEntity(id: playlist.id, name: playlist.name)
            }
            return PlaylistEntity(id: id, name: "Playlist")
        }
    }

    func suggestedEntities() async throws -> [PlaylistEntity] {
        mapCachedPlaylists(SharedStorage.shared.cachedPlaylists())
    }

    func entities(matching string: String) async throws -> [PlaylistEntity] {
        let cached = SharedStorage.shared.cachedPlaylists()
        guard !string.isEmpty else {
            return mapCachedPlaylists(cached)
        }

        return mapCachedPlaylists(
            cached.filter { $0.name.localizedCaseInsensitiveContains(string) }
        )
    }

    private func mapCachedPlaylists(_ playlists: [CachedPlaylist]) -> [PlaylistEntity] {
        playlists.map { PlaylistEntity(id: $0.id, name: $0.name) }
    }
}
