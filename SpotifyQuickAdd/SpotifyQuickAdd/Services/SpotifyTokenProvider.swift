import Foundation

actor TokenRefreshGate {
    static let shared = TokenRefreshGate()

    private var refreshTask: Task<String, Error>?

    func refresh(_ operation: @escaping () async throws -> String) async throws -> String {
        if let refreshTask {
            return try await refreshTask.value
        }

        let task = Task {
            try await operation()
        }
        refreshTask = task
        defer { refreshTask = nil }

        return try await task.value
    }
}

final class SpotifyTokenProvider: SpotifyTokenProviding {
    private(set) var isLoggedIn = false

    private let keychain: KeychainManager

    init(keychain: KeychainManager = KeychainManager()) {
        self.keychain = keychain
        refreshLoginState()
    }

    func refreshLoginState() {
        isLoggedIn = (try? keychain.read(.refreshToken)) != nil
    }

    func validAccessToken() async throws -> String {
        if let expirationString = try keychain.read(.expirationDate),
           let expiration = Self.dateFormatter.date(from: expirationString),
           expiration.timeIntervalSinceNow > 60,
           let accessToken = try keychain.read(.accessToken) {
            return accessToken
        }

        return try await forceRefreshAccessToken()
    }

    func forceRefreshAccessToken() async throws -> String {
        try await TokenRefreshGate.shared.refresh {
            try await self.refreshAccessToken()
        }
    }

    func exchangeCodeForTokens(code: String, verifier: String) async throws {
        let bodyItems = [
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "redirect_uri", value: SpotifyConfig.redirectURI),
            URLQueryItem(name: "client_id", value: SpotifyConfig.clientID),
            URLQueryItem(name: "code_verifier", value: verifier)
        ]

        let response: TokenResponse = try await performTokenRequest(bodyItems: bodyItems)
        try storeTokens(from: response)
        refreshLoginState()
    }

    func clearTokens() {
        keychain.clearAll()
        refreshLoginState()
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
                clearTokens()
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
        let expirationString = Self.dateFormatter.string(from: expiration)
        try keychain.save(expirationString, for: .expirationDate)
    }

    private static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static func spotifyErrorMessage(from data: Data) -> String? {
        guard let decoded = try? JSONDecoder().decode(SpotifyAPIErrorResponse.self, from: data) else {
            return String(data: data, encoding: .utf8)
        }
        return decoded.error?.message
    }
}
