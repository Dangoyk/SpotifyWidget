import AuthenticationServices
import Foundation

@MainActor
final class SpotifyAuthService: NSObject, ObservableObject, SpotifyTokenProviding {
    @Published private(set) var isLoggedIn = false

    private let tokenProvider: SpotifyTokenProvider
    private let presentationProvider = WebAuthPresentationContextProvider()
    private var authSession: ASWebAuthenticationSession?
    private var pendingCodeVerifier: String?
    private var callbackExchangeTask: Task<Void, Error>?

    private let codeVerifierDefaultsKey = "spotify.pkce.codeVerifier"

    init(tokenProvider: SpotifyTokenProvider = SpotifyTokenProvider()) {
        self.tokenProvider = tokenProvider
        super.init()
        refreshLoginState()
    }

    func refreshLoginState() {
        tokenProvider.refreshLoginState()
        isLoggedIn = tokenProvider.isLoggedIn
    }

    func startLogin() async throws {
        guard SpotifyConfig.clientID != "YOUR_SPOTIFY_CLIENT_ID", !SpotifyConfig.clientID.isEmpty else {
            throw AppError.unknown("Add your Spotify Client ID in SpotifyConfig.swift before signing in.")
        }

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
            var didResume = false

            func resumeOnce(with result: Result<Void, Error>) {
                guard !didResume else { return }
                didResume = true
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: callbackScheme
            ) { [weak self] callbackURL, error in
                Task { @MainActor in
                    if let error {
                        if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                            resumeOnce(with: .failure(AppError.unknown("Spotify login was cancelled.")))
                        } else {
                            resumeOnce(with: .failure(AppError.networkFailure(error.localizedDescription)))
                        }
                        return
                    }

                    guard let callbackURL else {
                        resumeOnce(with: .failure(AppError.unknown("Spotify login did not return a callback URL.")))
                        return
                    }

                    guard let self else {
                        resumeOnce(with: .failure(AppError.unknown("Spotify login session ended unexpectedly.")))
                        return
                    }

                    do {
                        try await self.handleCallback(url: callbackURL)
                        resumeOnce(with: .success(()))
                    } catch {
                        resumeOnce(with: .failure(error))
                    }
                }
            }

            session.presentationContextProvider = presentationProvider
            session.prefersEphemeralWebBrowserSession = false
            self.authSession = session

            if !session.start() {
                resumeOnce(with: .failure(AppError.unknown("Could not start Spotify login session.")))
            }
        }
    }

    func handleCallback(url: URL) async throws {
        if let callbackExchangeTask {
            return try await callbackExchangeTask.value
        }

        let task = Task { @MainActor in
            try await self.exchangeAuthorizationCode(from: url)
        }
        callbackExchangeTask = task
        defer { callbackExchangeTask = nil }

        return try await task.value
    }

    private func exchangeAuthorizationCode(from url: URL) async throws {
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

        try await tokenProvider.exchangeCodeForTokens(code: code, verifier: verifier)
        pendingCodeVerifier = nil
        UserDefaults.standard.removeObject(forKey: codeVerifierDefaultsKey)
        refreshLoginState()
    }

    func logout() {
        tokenProvider.clearTokens()
        pendingCodeVerifier = nil
        UserDefaults.standard.removeObject(forKey: codeVerifierDefaultsKey)
        refreshLoginState()
    }

    func validAccessToken() async throws -> String {
        try await tokenProvider.validAccessToken()
    }

    func forceRefreshAccessToken() async throws -> String {
        try await tokenProvider.forceRefreshAccessToken()
    }
}
