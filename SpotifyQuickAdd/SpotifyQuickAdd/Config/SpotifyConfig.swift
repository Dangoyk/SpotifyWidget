import Foundation

enum SpotifyConfig {
    /// Replace with your Spotify Developer Dashboard Client ID before building.
    static let clientID = "YOUR_SPOTIFY_CLIENT_ID"

    static let redirectURI = "spotifyquickadd://callback"
    static let urlScheme = "spotifyquickadd"

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
    static let keychainService = "com.yourname.spotifyquickadd"
    /// Suffix shared by both targets' keychain-access-groups entitlements.
    static let keychainAccessGroupSuffix = "com.yourname.spotifyquickadd"
    /// Optional: set your 10-character Apple Team ID for explicit shared Keychain access.
    /// Leave nil to use the entitlement default access group.
    static let appleTeamID: String? = nil
    static var keychainAccessGroup: String? {
        guard let teamID = appleTeamID, !teamID.isEmpty else { return nil }
        return "\(teamID).\(keychainAccessGroupSuffix)"
    }
    static let widgetKind = "SpotifyQuickAddWidget"
}
