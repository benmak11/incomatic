//
//  AuthService.swift
//  incomatic
//
//
//  Created by Ben Makusha on 06/09/2026
//
//  Exchanges an Apple identity token for a server-issued session token.
//

import Foundation

nonisolated struct AppleSignInRequestBody: Encodable {
    let identityToken: String
    let nonce: String
    let displayName: String?
}

nonisolated struct AppleSignInResponseBody: Decodable {
    let sessionToken: String
    let expiresAt: String
    let user: User

    nonisolated struct User: Decodable {
        let id: String
        let displayName: String?
    }
}

nonisolated final class AuthService {
    private var baseURL: String { AppConfig.apiBaseURL }

    enum AuthError: LocalizedError {
        case invalidURL
        case network(Error)
        case invalidResponse
        /// 401 — expired/invalid session token (deleteAccount) or a rejected Apple
        /// identity token (signInWithApple). Same mapping EquityService,
        /// BudgetService and CalculationHistoryService use for their authed calls.
        case notAuthenticated
        case server(Int, String)
        case decoding(Error)

        var errorDescription: String? {
            switch self {
            case .invalidURL:            return "Invalid API URL"
            case .network(let e):        return "Network error: \(e.localizedDescription)"
            case .invalidResponse:       return "Invalid response from server"
            case .notAuthenticated:      return "Sign-in session invalid or expired"
            case .server(let code, let m):
                return "Sign-in failed (HTTP \(code)): \(m)"
            case .decoding(let e):       return "Failed to decode response: \(e.localizedDescription)"
            }
        }
    }

    func signInWithApple(identityToken: String,
                        nonce: String,
                        displayName: String?) async throws -> AppleSignInResponseBody {
        guard let url = URL(string: "\(baseURL)/v1/auth/apple") else { throw AuthError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try JSONEncoder().encode(AppleSignInRequestBody(
                identityToken: identityToken, nonce: nonce, displayName: displayName))
        } catch {
            throw AuthError.network(error)
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AuthError.network(error)
        }
        try validate(response, data: data)

        do {
            return try JSONDecoder().decode(AppleSignInResponseBody.self, from: data)
        } catch {
            throw AuthError.decoding(error)
        }
    }

    /// Permanently deletes the signed-in user's account and saved calculations
    /// (DELETE /v1/account). The backend returns 204 on success.
    func deleteAccount(token: String) async throws {
        guard let url = URL(string: "\(baseURL)/v1/account") else { throw AuthError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AuthError.network(error)
        }
        try validate(response, data: data)
    }

    /// Shared status-code check for both endpoints in this file: not-2xx and not a
    /// decode concern, just translating the HTTP status into the right AuthError.
    private func validate(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw AuthError.invalidResponse }
        if (200...299).contains(http.statusCode) { return }
        if http.statusCode == 401 { throw AuthError.notAuthenticated }
        let message = String(data: data, encoding: .utf8) ?? "Server returned \(http.statusCode)"
        throw AuthError.server(http.statusCode, message)
    }
}

