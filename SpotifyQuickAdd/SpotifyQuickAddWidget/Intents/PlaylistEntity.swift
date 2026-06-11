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

enum WidgetPlaylistResolver {
    /// Widget system config when available; otherwise the playlist chosen in the app.
    static func effectivePlaylist(widgetPlaylist: PlaylistEntity?) -> PlaylistEntity? {
        if let widgetPlaylist {
            return widgetPlaylist
        }
        guard let selected = SharedStorage.shared.selectedPlaylist else {
            return nil
        }
        return PlaylistEntity(id: selected.id, name: selected.name)
    }
}

struct PlaylistEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [PlaylistEntity.ID]) async throws -> [PlaylistEntity] {
        let all = await PlaylistCatalog.allEntities()
        var byID: [String: PlaylistEntity] = [:]
        for entity in all {
            byID[entity.id] = entity
        }

        return identifiers.map { id in
            byID[id] ?? PlaylistEntity(id: id, name: "Playlist")
        }
    }

    func suggestedEntities() async throws -> [PlaylistEntity] {
        await PlaylistCatalog.allEntities()
    }

    func entities(matching string: String) async throws -> [PlaylistEntity] {
        let all = await PlaylistCatalog.allEntities()
        guard !string.isEmpty else { return all }

        return all.filter { $0.name.localizedCaseInsensitiveContains(string) }
    }
}
