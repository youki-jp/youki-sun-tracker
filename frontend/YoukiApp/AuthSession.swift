import AuthenticationServices
import Combine
import CryptoKit
import Foundation
import Security

struct YoukiAccount: Codable {
    struct User: Codable { let id: String; let email: String? }
    struct Limits: Codable { let forecastPerMinute: Int; let forecastPerDay: Int }
    let user: User
    let tier: String
    let entitlements: [String]
    let limits: Limits
}

private struct AuthTokens: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let account: YoukiAccount
}

private struct AuthChallenge: Decodable { let nonce: String }
private struct AuthConfiguration: Decodable {
    let appleSignInEnabled: Bool
    let testLoginEnabled: Bool
}

private enum SessionError: LocalizedError, Equatable {
    case signInRequired
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .signInRequired: "Sign in to load a live forecast."
        case .invalidResponse: "The account server returned an invalid response."
        case .server(let message): message
        }
    }
}

@MainActor
final class AuthSession: ObservableObject {
    static let shared = AuthSession()

    @Published private(set) var account: YoukiAccount?
    @Published private(set) var isAuthenticated = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var appleNonce: String?
    @Published private(set) var temporaryLoginEnabled = false
    @Published private(set) var cooldownUntil: Date?

    private var tokens: AuthTokens?
    private var refreshTask: Task<AuthTokens, Error>?
    private var generation = UUID()
    private let service = "jp.youki.YoukiApp.session"

    private init() {
        if let data = readKeychain(), let restored = try? JSONDecoder().decode(AuthTokens.self, from: data) {
            tokens = restored
            account = restored.account
            isAuthenticated = true
        }
    }

    var appleNonceHash: String? {
        guard let appleNonce else { return nil }
        let bytes = SHA256.hash(data: Data(appleNonce.utf8))
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    func prepareSignIn() async {
        errorMessage = nil
        appleNonce = nil
        do {
            let configRequest = URLRequest(url: AppConfig.serverURL.appendingPathComponent("api/v1/auth/config"))
            let (configData, configResponse) = try await URLSession.shared.data(for: configRequest)
            let configStatus = (configResponse as? HTTPURLResponse)?.statusCode
            if configStatus == 200 {
                let config = try JSONDecoder().decode(AuthConfiguration.self, from: configData)
                temporaryLoginEnabled = !config.appleSignInEnabled && config.testLoginEnabled
                if temporaryLoginEnabled { return }
                guard config.appleSignInEnabled else {
                    throw SessionError.server("Sign-in is currently unavailable.")
                }
            } else if configStatus != 404 {
                throw SessionError.invalidResponse
            }
            var request = URLRequest(url: AppConfig.serverURL.appendingPathComponent("api/v1/auth/challenge"))
            request.httpMethod = "POST"
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw SessionError.invalidResponse }
            appleNonce = try JSONDecoder().decode(AuthChallenge.self, from: data).nonce
        } catch { errorMessage = error.localizedDescription }
    }

    func completeAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        do {
            let authorization = try result.get()
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identity = credential.identityToken,
                  let identityToken = String(data: identity, encoding: .utf8),
                  let code = credential.authorizationCode,
                  let authorizationCode = String(data: code, encoding: .utf8),
                  let nonce = appleNonce else { throw SessionError.invalidResponse }
            appleNonce = nil
            let issued: AuthTokens = try await post("api/v1/auth/apple", body: [
                "identityToken": identityToken, "authorizationCode": authorizationCode, "nonce": nonce])
            install(issued)
            generation = UUID()
            errorMessage = nil
        } catch {
            let message = error.localizedDescription
            await prepareSignIn()
            errorMessage = message
        }
    }

    func signInLocalTestUser(email: String, password: String) async {
        errorMessage = nil
        do {
            let issued: AuthTokens = try await post("api/v1/auth/test-login", body: [
                "email": email, "password": password])
            install(issued)
            generation = UUID()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func send(_ original: URLRequest) async throws -> (Data, URLResponse) {
        guard tokens != nil else { throw SessionError.signInRequired }
        let isForecast = original.url?.path.hasPrefix("/api/v1/sky-") ?? false
        if isForecast, let cooldownUntil, cooldownUntil > Date() {
            throw SessionError.server("Please wait before refreshing the sky.")
        }
        let initialGeneration = generation
        var request = original
        let firstAccess = tokens?.accessToken
        request.setValue(firstAccess.map { "Bearer \($0)" }, forHTTPHeaderField: "Authorization")
        var pair = try await URLSession.shared.data(for: request)
        if (pair.1 as? HTTPURLResponse)?.statusCode == 401 {
            if tokens?.accessToken == firstAccess { _ = try await refresh() }
            guard generation == initialGeneration, let access = tokens?.accessToken else {
                throw SessionError.signInRequired
            }
            request.setValue("Bearer \(access)", forHTTPHeaderField: "Authorization")
            pair = try await URLSession.shared.data(for: request)
            if (pair.1 as? HTTPURLResponse)?.statusCode == 401 {
                clear()
                throw SessionError.signInRequired
            }
        }
        guard generation == initialGeneration else { throw SessionError.signInRequired }
        if isForecast, let http = pair.1 as? HTTPURLResponse, http.statusCode == 429 {
            let wait = min(max(Int(http.value(forHTTPHeaderField: "Retry-After") ?? "30") ?? 30, 1), 86_400)
            cooldownUntil = Date().addingTimeInterval(TimeInterval(wait))
        }
        return pair
    }

    func refreshAccount() async {
        guard tokens != nil else { return }
        do {
            let request = URLRequest(url: AppConfig.serverURL.appendingPathComponent("api/v1/me"))
            let (data, response) = try await send(request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return }
            let updated = try JSONDecoder().decode(YoukiAccount.self, from: data)
            account = updated
            if let old = tokens {
                let replacement = AuthTokens(accessToken: old.accessToken,
                    refreshToken: old.refreshToken, expiresIn: old.expiresIn, account: updated)
                tokens = replacement
                if let data = try? JSONEncoder().encode(replacement) { saveKeychain(data) }
            }
        } catch {
            // Keep the last known tier for display while offline; the server remains authoritative.
        }
    }

    func signOut() async {
        let old = tokens
        clear()
        guard let old else { return }
        var request = URLRequest(url: AppConfig.serverURL.appendingPathComponent("api/v1/auth/logout"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(old.accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONEncoder().encode(["refreshToken": old.refreshToken])
        _ = try? await URLSession.shared.data(for: request)
    }

    func deleteAccount() async {
        do {
            var request = URLRequest(url: AppConfig.serverURL.appendingPathComponent("api/v1/me"))
            request.httpMethod = "DELETE"
            let (_, response) = try await send(request)
            if (response as? HTTPURLResponse)?.statusCode == 403 {
                throw SessionError.server("Sign out and sign in again before deleting your account.")
            }
            guard (response as? HTTPURLResponse)?.statusCode == 204 else { throw SessionError.invalidResponse }
            clear()
        } catch { errorMessage = error.localizedDescription }
    }

    private func refresh() async throws -> AuthTokens {
        if let refreshTask { return try await refreshTask.value }
        guard let refreshToken = tokens?.refreshToken else { throw SessionError.signInRequired }
        let initialGeneration = generation
        let task = Task { try await self.post("api/v1/auth/refresh", body: ["refreshToken": refreshToken]) as AuthTokens }
        refreshTask = task
        do {
            let issued = try await task.value
            refreshTask = nil
            guard generation == initialGeneration else { throw SessionError.signInRequired }
            install(issued)
            return issued
        } catch {
            refreshTask = nil
            if (error as? SessionError) == .signInRequired { clear() }
            throw error
        }
    }

    private func post<T: Decodable>(_ path: String, body: [String: String]) async throws -> T {
        var request = URLRequest(url: AppConfig.serverURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SessionError.invalidResponse }
        if http.statusCode == 401 {
            if path == "api/v1/auth/test-login" {
                throw SessionError.server("Invalid test account or password.")
            }
            throw SessionError.signInRequired
        }
        guard (200..<300).contains(http.statusCode) else { throw SessionError.server("Account service unavailable (HTTP \(http.statusCode)).") }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func install(_ issued: AuthTokens) {
        tokens = issued
        account = issued.account
        isAuthenticated = true
        if let data = try? JSONEncoder().encode(issued) { saveKeychain(data) }
    }

    private func clear() {
        generation = UUID()
        tokens = nil
        account = nil
        isAuthenticated = false
        refreshTask?.cancel()
        refreshTask = nil
        appleNonce = nil
        cooldownUntil = nil
        SecItemDelete([kSecClass: kSecClassGenericPassword, kSecAttrService: service] as CFDictionary)
    }

    private func readKeychain() -> Data? {
        var item: CFTypeRef?
        let status = SecItemCopyMatching([kSecClass: kSecClassGenericPassword,
                                          kSecAttrService: service,
                                          kSecReturnData: true,
                                          kSecMatchLimit: kSecMatchLimitOne] as CFDictionary, &item)
        return status == errSecSuccess ? item as? Data : nil
    }

    private func saveKeychain(_ data: Data) {
        SecItemDelete([kSecClass: kSecClassGenericPassword, kSecAttrService: service] as CFDictionary)
        SecItemAdd([kSecClass: kSecClassGenericPassword, kSecAttrService: service,
                    kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
                    kSecValueData: data] as CFDictionary, nil)
    }
}
