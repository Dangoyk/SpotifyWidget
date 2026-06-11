import AuthenticationServices
import Foundation

@MainActor
final class SpotifyAuthService: NSObject, ObservableObject {
    @Published private(set) var isLoggedIn = false

    private let keychain: KeychainManager
    private let presentationProvider = WebAuthPresentationContextProvider()
    private var authSession: ASWebAuthenticationSession?
    private var pendingCodeVerifier: String?

    private let codeVerifierDefaultsKey = "spotify.pkce.codeVerifier"

    init(keychain: KeychainManager = KeychainManager()) {
        self.keychain = keychain
        super.init()
        refreshLoginState()
    }

    func refreshLoginState() {
        isLoggedIn = (try? keychain.read(.refreshToken)) != nil
    }

    func startLogin() async throws {
        let verifier = PKCEHelper.generateCodeVerifier()
        pendingCodeVerifier = verifier
        UserDefaults.standard.set(verifier, forKey: codeVerifierDefaultsKey)

        let challenge = PKCEHelper.codeChallenge(for: verifier)

        var components = URLComponents(url: SpotifyConfig.authorizationURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: SpotifyConfig.clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: SpotifyConfig.redirectURI),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "scope", value: SpotifyConfig.scopes)
        ]

        guard let authURL = components?.url else {
            throw AppError.unknown("Could not build Spotify authorization URL.")
        }

        let callbackScheme = SpotifyConfig.urlScheme

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: callbackScheme
            ) { [weak self] callbackURL, error in
                Task { @MainActor in
                    if let error {
                        if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                            continuation.resume(throwing: AppError.unknown("Spotify login was cancelled."))
                        } else {
                            continuation.resume(throwing: AppError.networkFailure(error.localizedDescription))
                        }
                        return
                    }

                    guard let callbackURL else {
                        continuation.resume(throwing: AppError.unknown("Spotify login did not return a callback URL."))
                        return
                    }

                    do {
                        try await self?.handleCallback(url: callbackURL)
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }

            session.presentationContextProvider = presentationProvider
            session.prefersEphemeralWebBrowserSession = false
            self.authSession = session

            if !session.start() {
                continuation.resume(throwing: AppError.unknown("Could not start Spotify login session."))
            }
        }
    }

    func handleCallback(url: URL) async throws {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw AppError.unknown("Invalid Spotify callback URL.")
        }

        if let error = components.queryItems?.first(where: { $0.name == "error" })?.value {
            throw AppError.networkFailure("Spotify login failed: \(error)")
        }

        guard let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw AppError.unknown("Spotify login did not include an authorization code.")
        }

        let verifier = pendingCodeVerifier ?? UserDefaults.standard.string(forKey: codeVerifierDefaultsKey)
        guard let verifier else {
            throw AppError.unknown("Missing PKCE code verifier. Please try signing in again.")
        }

        try await exchangeCodeForTokens(code: code, verifier: verifier)
        pendingCodeVerifier = nil
        UserDefaults.standard.removeObject(forKey: codeVerifierDefaultsKey)
        refreshLoginState()
    }

    func logout() {
        keychain.clearAll()
        pendingCodeVerifier = nil
        UserDefaults.standard.removeObject(forKey: codeVerifierDefaultsKey)
        refreshLoginState()
    }

    func validAccessToken() async throws -> String {
        if let expirationString = try keychain.read(.expirationDate),
           let expiration = ISO8601DateFormatter().date(from: expirationString),
           expiration.timeIntervalSinceNow > 60,
           let accessToken = try keychain.read(.accessToken) {
            return accessToken
        }

        return try await refreshAccessToken()
    }

    private func exchangeCodeForTokens(code: String, verifier: String) async throws {
        let bodyItems = [
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "redirect_uri", value: SpotifyConfig.redirectURI),
            URLQueryItem(name: "client_id", value: SpotifyConfig.clientID),
            URLQueryItem(name: "code_verifier", value: verifier)
        ]

        let response: TokenResponse = try await performTokenRequest(bodyItems: bodyItems)
        try storeTokens(from: response)
    }

    private func refreshAccessToken() async throws -> String {
        guard let refreshToken = try keychain.read(.refreshToken) else {
            refreshLoginState()
            throw AppError.loginRequired
        }

        let bodyItems = [
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "refresh_token", value: refreshToken),
            URLQueryItem(name: "client_id", value: SpotifyConfig.clientID)
        ]

        let response: TokenResponse = try await performTokenRequest(bodyItems: bodyItems)
        try storeTokens(from: response, existingRefreshToken: refreshToken)

        guard let accessToken = try keychain.read(.accessToken) else {
            throw AppError.loginRequired
        }

        return accessToken
    }

    private func performTokenRequest(bodyItems: [URLQueryItem]) async throws -> TokenResponse {
        var request = URLRequest(url: SpotifyConfig.tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var components = URLComponents()
        components.queryItems = bodyItems
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.networkFailure("Spotify token request failed.")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = Self.spotifyErrorMessage(from: data) ?? "Spotify token request failed with status \(httpResponse.statusCode)."
            if httpResponse.statusCode == 401 {
                keychain.clearAll()
                refreshLoginState()
                throw AppError.loginRequired
            }
            throw AppError.networkFailure(message)
        }

        do {
            return try JSONDecoder().decode(TokenResponse.self, from: data)
        } catch {
            throw AppError.networkFailure("Could not parse Spotify token response.")
        }
    }

    private func storeTokens(from response: TokenResponse, existingRefreshToken: String? = nil) throws {
        try keychain.save(response.accessToken, for: .accessToken)

        if let refreshToken = response.refreshToken ?? existingRefreshToken {
            try keychain.save(refreshToken, for: .refreshToken)
        }

        let expiration = Date().addingTimeInterval(TimeInterval(response.expiresIn))
        let expirationString = ISO8601DateFormatter().string(from: expiration)
        try keychain.save(expirationString, for: .expirationDate)
    }

    private static func spotifyErrorMessage(from data: Data) -> String? {
        guard let decoded = try? JSONDecoder().decode(SpotifyAPIErrorResponse.self, from: data) else {
            return String(data: data, encoding: .utf8)
        }
        return decoded.error?.message
    }
}
