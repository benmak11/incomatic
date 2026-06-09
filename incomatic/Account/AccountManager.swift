//
//  AccountManager.swift
//  incomatic
//
//
//  Created by Ben Makusha on 06/09/2026
//
//  Owns the signed-in state, the session token (in Keychain), and the Apple
//  sign-in flow. The rest of the app observes @Published properties to decide
//  whether to attach Bearer headers, show History, etc.
//

import AuthenticationServices
import Combine
import CryptoKit
import Foundation

@MainActor
final class AccountManager: ObservableObject {
    @Published private(set) var currentUser: AccountUser?
    @Published private(set) var sessionToken: String?
    @Published private(set) var isSigningIn = false
    @Published var errorMessage: String?

    private let authService: AuthService
    private let keychain: KeychainStore

    /// Raw nonce currently in flight. Set in `prepareAppleRequest` so we can pass
    /// it to the backend alongside the identity token, then cleared.
    private var pendingNonce: String?

    init(authService: AuthService = AuthService(), keychain: KeychainStore = KeychainStore()) {
        self.authService = authService
        self.keychain = keychain
    }

    var isSignedIn: Bool { sessionToken != nil }

    func restoreSession() {
        if let stored = keychain.load() {
            sessionToken = stored.token
            currentUser = stored.user
        }
    }

    /// Configure an ASAuthorizationAppleIDRequest. Apple expects the SHA-256 of the
    /// raw nonce in the request; we hold onto the raw value for the backend handshake.
    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let raw = Self.randomNonce()
        pendingNonce = raw
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256Hex(raw)
    }

    /// Consume an Apple authorization result, exchange it with the backend, and
    /// persist the session locally.
    func handleAppleResult(_ result: Result<ASAuthorization, Error>) async {
        guard !isSigningIn else { return }
        isSigningIn = true
        errorMessage = nil
        defer { isSigningIn = false; pendingNonce = nil }

        switch result {
        case .failure(let error):
            if let asError = error as? ASAuthorizationError, asError.code == .canceled {
                return
            }
            errorMessage = error.localizedDescription
            return
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = "Unexpected Apple credential type"
                return
            }
            guard let identityTokenData = credential.identityToken,
                  let identityToken = String(data: identityTokenData, encoding: .utf8) else {
                errorMessage = "Apple did not return an identity token"
                return
            }
            guard let rawNonce = pendingNonce else {
                errorMessage = "Missing sign-in nonce — try again"
                return
            }

            let displayName: String? = {
                guard let name = credential.fullName else { return nil }
                let given = name.givenName ?? ""
                let family = name.familyName ?? ""
                let combined = [given, family].filter { !$0.isEmpty }.joined(separator: " ")
                return combined.isEmpty ? nil : combined
            }()

            do {
                let response = try await authService.signInWithApple(
                    identityToken: identityToken, nonce: rawNonce, displayName: displayName)
                let user = AccountUser(id: response.user.id, displayName: response.user.displayName)
                try keychain.save(StoredSession(token: response.sessionToken, user: user))
                sessionToken = response.sessionToken
                currentUser = user
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func signOut() {
        keychain.clear()
        sessionToken = nil
        currentUser = nil
        errorMessage = nil
    }

    // MARK: - Crypto helpers

    private static func randomNonce(length: Int = 32) -> String {
        let charset: [Character] = Array("0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-._")
        var result = ""
        result.reserveCapacity(length)
        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        precondition(status == errSecSuccess, "SecRandomCopyBytes failed: \(status)")
        for byte in bytes {
            result.append(charset[Int(byte) % charset.count])
        }
        return result
    }

    private static func sha256Hex(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
