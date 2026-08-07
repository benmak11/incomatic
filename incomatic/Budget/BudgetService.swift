//
//  BudgetService.swift
//  incomatic
//
//  Created by Ben Makusha on 07/24/2026
//
//  Talks to /v1/budget (single-object CRUD, not list-CRUD like grants — no
//  POST, no /{id}) and /v1/budget/plan (AI-suggested contribution rates).
//  Same request/error shape as EquityService, with one structural
//  difference: generatePlan() is auth-optional server-side (mirrors
//  /v1/calculate — a not-yet-saved budget can still get a plan preview), so
//  the shared `send` helper takes a `requiresAuth` flag instead of always
//  demanding a session token.
//

import Foundation

nonisolated final class BudgetService {
    private var baseURL: String { AppConfig.apiBaseURL }

    var sessionTokenProvider: () -> String? = { nil }

    enum BudgetServiceError: LocalizedError {
        case invalidURL
        case notAuthenticated
        /// GET with no budget saved yet — not a failure, callers treat this as "start empty".
        case notFound
        /// Backend 503 — Vertex AI unconfigured or the Gemini call failed.
        case planUnavailable
        case network(Error)
        case server(Int, String)
        case decoding(Error)

        var errorDescription: String? {
            switch self {
            case .invalidURL:           return "Invalid budget URL"
            case .notAuthenticated:     return "Sign in to sync your budget"
            case .notFound:             return "No budget saved yet"
            case .planUnavailable:      return "AI budget plan unavailable right now"
            case .network(let e):       return e.localizedDescription
            case .server(let c, let m): return "HTTP \(c): \(m)"
            case .decoding(let e):      return "Failed to decode budget response: \(e.localizedDescription)"
            }
        }
    }

    // MARK: - Budget (single object per user — GET/PUT/DELETE only)

    func getBudget() async throws -> Budget {
        try await get("/v1/budget", requiresAuth: true)
    }

    func saveBudget(_ budget: Budget) async throws -> Budget {
        try await sendExpecting(method: "PUT", path: "/v1/budget", body: budget, requiresAuth: true)
    }

    func deleteBudget() async throws {
        let _: Empty? = try await send(
            method: "DELETE", path: "/v1/budget", body: nil, expectingBody: false, requiresAuth: true
        )
    }

    // MARK: - AI plan (auth-optional)

    func generatePlan(_ request: BudgetPlanRequest) async throws -> BudgetPlan {
        try await sendExpecting(method: "POST", path: "/v1/budget/plan", body: request, requiresAuth: false)
    }

    // MARK: - Internals

    private struct Empty: Decodable {}

    private func get<T: Decodable>(_ path: String, requiresAuth: Bool) async throws -> T {
        guard let result = try await send(
            method: "GET", path: path, body: nil, expectingBody: true, requiresAuth: requiresAuth
        ) as T? else {
            throw BudgetServiceError.network(NSError(domain: "budget", code: -1))
        }
        return result
    }

    private func sendExpecting<T: Decodable>(
        method: String, path: String, body: Encodable, requiresAuth: Bool
    ) async throws -> T {
        let data: Data
        do {
            data = try JSONEncoder().encode(body)
        } catch {
            throw BudgetServiceError.network(error)
        }
        guard let result = try await send(
            method: method, path: path, body: data, expectingBody: true, requiresAuth: requiresAuth
        ) as T? else {
            throw BudgetServiceError.network(NSError(domain: "budget", code: -1))
        }
        return result
    }

    private func send<T: Decodable>(
        method: String,
        path: String,
        body: Data?,
        expectingBody: Bool,
        requiresAuth: Bool
    ) async throws -> T? {
        let token = sessionTokenProvider()
        if requiresAuth, (token ?? "").isEmpty {
            throw BudgetServiceError.notAuthenticated
        }
        guard let url = URL(string: "\(baseURL)\(path)") else { throw BudgetServiceError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = method
        if let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await APISession.data(for: request)
        } catch {
            throw BudgetServiceError.network(error)
        }
        guard let http = response as? HTTPURLResponse else {
            throw BudgetServiceError.network(NSError(domain: "budget", code: -2))
        }
        switch http.statusCode {
        case 200...299:
            break
        case 402:
            // Pro-only route. A distinct type, not another server(402,…): the paywall
            // needs to open on the refused feature rather than surface an error toast.
            throw SubscriptionRequired.from(data)
        case 401:
            throw BudgetServiceError.notAuthenticated
        case 404:
            throw BudgetServiceError.notFound
        case 503:
            throw BudgetServiceError.planUnavailable
        default:
            let message = String(data: data, encoding: .utf8) ?? "Unexpected status"
            throw BudgetServiceError.server(http.statusCode, message)
        }
        if !expectingBody || data.isEmpty { return nil }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw BudgetServiceError.decoding(error)
        }
    }
}
