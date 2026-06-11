import Foundation

enum AppError: LocalizedError, Equatable {
    case nothingPlaying
    case unsupportedContent
    case alreadyInPlaylist
    case permissionDenied
    case loginRequired
    case widgetLoginRequired
    case noPlaylistSelected
    case playlistNotConfigured
    case networkFailure(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .nothingPlaying:
            return "Nothing is currently playing."
        case .unsupportedContent:
            return "Current item is not a supported Spotify song."
        case .alreadyInPlaylist:
            return "This song is already in that playlist."
        case .permissionDenied:
            return "You do not have permission to modify this playlist."
        case .loginRequired:
            return "Spotify login required."
        case .widgetLoginRequired:
            return "Spotify login required. Open the app to sign in."
        case .noPlaylistSelected:
            return "Please select a playlist."
        case .playlistNotConfigured:
            return "Please configure this widget with a playlist."
        case .networkFailure(let message):
            return message
        case .unknown(let message):
            return message
        }
    }
}
