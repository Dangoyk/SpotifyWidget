import Foundation

enum SpotifyConfig {
    /// Replace with your Spotify Developer Dashboard Client ID before building.
    static let clientID = "YOUR_SPOTIFY_CLIENT_ID"

    static let redirectURI = "spotifyquickadd://callback"
    static let urlScheme = "spotifyquickadd"
    static let addSongDeepLink = "spotifyquickadd://add-current-song"

    static let scopes = [
        "user-read-currently-playing",
        "playlist-modify-private",
        "playlist-modify-public",
        "playlist-read-private",
        "playlist-read-collaborative"
    ].joined(separator: " ")

    static let authorizationURL = URL(string: "https://accounts.spotify.com/authorize")!
    static let tokenURL = URL(string: "https://accounts.spotify.com/api/token")!
    static let apiBaseURL = URL(string: "https://api.spotify.com/v1")!

    static let appGroupIdentifier = "group.com.yourname.spotifyquickadd"
}
