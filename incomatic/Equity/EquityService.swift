//
//  EquityService.swift
//  incomatic
//
//  Created by Ben Makusha on 07/17/2026
//
//  Talks to /v1/grants (CRUD) and /v1/stocks (search + quote). All endpoints
//  require a session token; the AccountManager supplies it via the injected
//  provider closure — same pattern as CalculationHistoryService.
//

import Foundation

nonisolated final class EquityService {
    private var baseURL: String { AppConfig.apiBaseURL }

    var sessionTokenProvider: () -> String? = { nil }

    enum EquityError: LocalizedError {
        case invalidURL
        case notAuthenticated
        /// Backend 503 — Finnhub down or key unset. Callers flip to manual price entry.
        case lookupUnavailable
        /// Quote for a symbol the provider doesn't know.
        case unknownSymbol
        case network(Error)
        case server(Int, String)
        case decoding(Error)

        var errorDescription: String? {
            switch self {
            case .invalidURL:         return "Invalid equity URL"
            case .notAuthenticated:   return "Sign in to sync RSU grants"
            case .lookupUnavailable:  return "Stock lookup unavailable. Enter price manually"
            case .unknownSymbol:      return "Unknown ticker symbol"
            case .network(let e):     return e.localizedDescription
            case .server(let c, let m): return "HTTP \(c): \(m)"
            case .decoding(let e):    return "Failed to decode equity response: \(e.localizedDescription)"
            }
        }
    }

    // MARK: - Grants

    func listGrants() async throws -> [RsuGrant] {
        let response: GrantListResponse = try await get("/v1/grants")
        return response.items
    }

    func createGrant(_ grant: RsuGrant) async throws -> RsuGrant {
        try await sendExpecting(method: "POST", path: "/v1/grants", body: grant)
    }

    func updateGrant(_ grant: RsuGrant) async throws -> RsuGrant {
        guard let id = grant.id else { throw EquityError.invalidURL }
        return try await sendExpecting(method: "PUT", path: "/v1/grants/\(id)", body: grant)
    }

    func deleteGrant(id: String) async throws {
        let _: Empty? = try await send(method: "DELETE", path: "/v1/grants/\(id)", body: nil, expectingBody: false)
    }

    // MARK: - Stocks

    func searchStocks(query: String) async throws -> [StockSymbol] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let response: StockSearchResponse = try await get("/v1/stocks/search?q=\(encoded)")
        return response.items
    }

    func quote(symbol: String) async throws -> StockQuote {
        do {
            return try await get("/v1/stocks/quote/\(symbol)")
        } catch EquityError.server(404, _) {
            throw EquityError.unknownSymbol
        }
    }

    // MARK: - Internals

    private struct Empty: Decodable {}

    private func get<T: Decodable>(_ path: String) async throws -> T {
        guard let result = try await send(method: "GET", path: path, body: nil, expectingBody: true) as T? else {
            throw EquityError.network(NSError(domain: "equity", code: -1))
        }
        return result
    }

    private func sendExpecting<T: Decodable>(method: String, path: String, body: Encodable) async throws -> T {
        let data: Data
        do {
            data = try JSONEncoder().encode(body)
        } catch {
            throw EquityError.network(error)
        }
        guard let result = try await send(method: method, path: path, body: data, expectingBody: true) as T? else {
            throw EquityError.network(NSError(domain: "equity", code: -1))
        }
        return result
    }

    private func send<T: Decodable>(
        method: String,
        path: String,
        body: Data?,
        expectingBody: Bool
    ) async throws -> T? {
        guard let token = sessionTokenProvider(), !token.isEmpty else {
            throw EquityError.notAuthenticated
        }
        guard let url = URL(string: "\(baseURL)\(path)") else { throw EquityError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await APISession.data(for: request)
        } catch {
            throw EquityError.network(error)
        }
        guard let http = response as? HTTPURLResponse else {
            throw EquityError.network(NSError(domain: "equity", code: -2))
        }
        switch http.statusCode {
        case 200...299:
            break
        case 402:
            // Pro-only route. A distinct type, not another server(402,…): the paywall
            // needs to open on the refused feature rather than surface an error toast.
            throw SubscriptionRequired.from(data)
        case 401:
            throw EquityError.notAuthenticated
        case 503:
            throw EquityError.lookupUnavailable
        default:
            let message = String(data: data, encoding: .utf8) ?? "Unexpected status"
            throw EquityError.server(http.statusCode, message)
        }
        if !expectingBody || data.isEmpty { return nil }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw EquityError.decoding(error)
        }
    }
}
