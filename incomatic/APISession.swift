//
//  APISession.swift
//  incomatic
//
//  Created by Ben Makusha on 08/06/2026
//
//  One URLSession for every backend call, so the client-version header is
//  attached in a single place and a 426 is noticed no matter which service
//  made the request.
//

import Combine
import Foundation

/// The backend's 426 payload. Every field is optional: this arrives precisely
/// when the client is out of date, so it has to survive the backend adding or
/// renaming fields in a version this build has never seen.
struct UpgradeRequirement: Decodable, Equatable {
    let message: String?
    let minimumVersion: String?
}

/// Set once the backend refuses this build. Watched by `RootView`.
@MainActor
final class UpgradeGate: ObservableObject {
    static let shared = UpgradeGate()

    /// Non-nil means every screen is unusable: the block is server-side and
    /// applies to all endpoints, so there is deliberately no way to clear it.
    @Published private(set) var requirement: UpgradeRequirement?

    private init() {}

    func record(_ requirement: UpgradeRequirement) {
        // First refusal wins. Later calls carry the same verdict and would only
        // retrigger the presentation animation.
        guard self.requirement == nil else { return }
        self.requirement = requirement
    }
}

enum APISession {
    /// `ios/1.9.0`, from MARKETING_VERSION. The backend records this on every
    /// request and compares it against its configured minimum.
    static let clientHeader: String = {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return "ios/\(version ?? "0.0.0")"
    }()

    static let appStoreURL = URL(string: "https://apps.apple.com/app/id6778857123")

    /// Configured rather than `URLSession.shared` so `httpAdditionalHeaders`
    /// covers every call, including the ones made with a bare URL and no
    /// `URLRequest` to hang a header on.
    ///
    /// Settable purely as a test seam. `URLProtocol.registerClass` only affects
    /// `URLSession.shared`; a session built from its own configuration reads
    /// `configuration.protocolClasses` instead, so the test suite has to swap
    /// the whole session to stub the network. Production never reassigns this.
    static var session: URLSession = makeSession()

    static func makeSession(protocolClasses: [AnyClass]? = nil) -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = ["X-Incomatic-Client": clientHeader]
        if let protocolClasses {
            configuration.protocolClasses = protocolClasses
        }
        return URLSession(configuration: configuration)
    }

    static func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let result = try await session.data(for: request)
        noteUpgradeIfRefused(result)
        return result
    }

    static func data(from url: URL) async throws -> (Data, URLResponse) {
        let result = try await session.data(from: url)
        noteUpgradeIfRefused(result)
        return result
    }

    /// Callers keep throwing their own errors for a 426; the gate has already
    /// fired by then, so the upgrade screen covers the failure rather than the
    /// raw response body reaching a toast.
    ///
    /// Not `async`: `UpgradeGate` is `@MainActor` and so is this enum under the
    /// target's default isolation, so recording the refusal is a same-actor call
    /// with nothing to suspend on.
    private static func noteUpgradeIfRefused(_ result: (Data, URLResponse)) {
        guard let http = result.1 as? HTTPURLResponse, http.statusCode == 426 else { return }
        let requirement = (try? JSONDecoder().decode(UpgradeRequirement.self, from: result.0))
            ?? UpgradeRequirement(message: nil, minimumVersion: nil)
        UpgradeGate.shared.record(requirement)
    }
}
