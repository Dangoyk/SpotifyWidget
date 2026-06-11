import Foundation

protocol SpotifyTokenProviding: AnyObject {
    var isLoggedIn: Bool { get }
    func refreshLoginState()
    func validAccessToken() async throws -> String
    func forceRefreshAccessToken() async throws -> String
}
