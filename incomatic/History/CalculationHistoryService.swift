//
//  CalculationHistoryService.swift
//  incomatic
//
//  Created by Ben Makusha on 06/09/2026
//
//  Talks to /v1/calculations endpoints. Requires a session token; the
//  AccountManager supplies it via the injected provider closure.
//

import Foundation

nonisolated final class CalculationHistoryService {
    private var baseURL: String { AppConfig.apiBaseURL }

    var sessionTokenProvider: () -> String? = { nil }

    enum HistoryError: LocalizedError {
        case invalidURL
        case notAuthenticated
        case network(Error)
        case server(Int, String)
        case decoding(Error)

        var errorDescription: String? {
            switch self {
            case .invalidURL:        return "Invalid history URL"
            case .notAuthenticated:  return "Sign in to access calculation history"
            case .network(let e):    return e.localizedDescription
            case .server(let c, let m): return "HTTP \(c): \(m)"
            case .decoding(let e):   return "Failed to decode history: \(e.localizedDescription)"
            }
        }
    }

    func list(limit: Int = 20) async throws -> CalculationListResponse {
        try await get("/v1/calculations?limit=\(limit)")
    }

    func get(id: String) async throws -> SavedCalculationDetail {
        try await get("/v1/calculations/\(id)")
    }

    func delete(id: String) async throws {
        let _: Empty? = try await send(method: "DELETE", path: "/v1/calculations/\(id)", expectingBody: false)
    }

    // MARK: - Internals

    private struct Empty: Decodable {}

    private func get<T: Decodable>(_ path: String) async throws -> T {
        guard let result = try await send(method: "GET", path: path, expectingBody: true) as T? else {
            throw HistoryError.network(NSError(domain: "history", code: -1))
        }
        return result
    }

    private func send<T: Decodable>(method: String, path: String, expectingBody: Bool) async throws -> T? {
        guard let token = sessionTokenProvider(), !token.isEmpty else {
            throw HistoryError.notAuthenticated
        }
        guard let url = URL(string: "\(baseURL)\(path)") else { throw HistoryError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw HistoryError.network(error)
        }
        guard let http = response as? HTTPURLResponse else {
            throw HistoryError.network(NSError(domain: "history", code: -2))
        }
        guard (200...299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unexpected status"
            throw HistoryError.server(http.statusCode, message)
        }
        if !expectingBody || data.isEmpty { return nil }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw HistoryError.decoding(error)
        }
    }
}
