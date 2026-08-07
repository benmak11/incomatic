//
//  Analytics.swift
//  incomatic
//
//  Created by Ben Makusha on 08/06/2026
//
//  First-party event client for POST /v1/events. Batched, queued on disk, and
//  usable before sign-in.
//

import Combine
import Foundation
import UIKit

/// One queued event. Properties are `[String: String]` by design, not by omission:
/// the API cannot accept a `Double`, so a raw salary cannot be passed even by accident.
/// Amounts go through `Analytics.bucket(_:)`.
struct QueuedEvent: Codable, Equatable {
    let name: String
    let occurredAt: Date
    let properties: [String: String]
}

/// Event names, kept in one place so a typo is a compile error rather than a
/// silently unqueryable event. The backend enforces `[a-z][a-z0-9_]{0,49}`.
enum AnalyticsEventName {
    static let sessionStart = "session_start"
    static let onboardingStep = "onboarding_step"
    static let onboardingCompleted = "onboarding_completed"
    static let calculationCompleted = "calculation_completed"
    static let linkCodeGenerated = "link_code_generated"
    static let linkCodeRedeemed = "link_code_redeemed"
}

/// Batched, offline-queued analytics.
///
/// **Anonymous before sign-in is the point.** Most users are signed out through
/// onboarding and their first calculation, so an auth-only funnel would measure
/// a self-selected minority. Every batch carries a stable `deviceId`, which is
/// what lets a signed-out run be stitched to an account later; the backend
/// attributes the batch to an accountId when a session token is present.
///
/// **Nothing is ever lost to a bad connection.** Events are appended to a queue
/// persisted on disk and only removed once the server has accepted them. The
/// app is used on phones in lifts and car parks; a dropped batch would silently
/// bias the very measurement that gates Phase 2.
@MainActor
final class Analytics: ObservableObject {
    static let shared = Analytics()

    /// The server caps a batch at 50 events.
    private static let maxBatchSize = 50

    /// Flush once this many are pending, rather than one request per event.
    private static let flushThreshold = 10

    /// Older events are dropped first when the queue overflows. A cap is
    /// required: an install that never regains connectivity must not grow a
    /// file without limit.
    private static let maxQueuedEvents = 500

    private static let deviceIdKey = "incomatic.analytics.deviceId"

    /// Set by the host so batches from a signed-in user carry their session.
    var sessionTokenProvider: () -> String? = { nil }

    private var pending: [QueuedEvent] = []
    private var isFlushing = false
    private var observers: [NSObjectProtocol] = []

    private let storage: AnalyticsStorage

    init(storage: AnalyticsStorage = FileAnalyticsStorage()) {
        self.storage = storage
        pending = storage.load()
    }

    /// Stable per-install identifier. Not tied to a person: it resets on
    /// reinstall, which is the correct behaviour for an install-level metric.
    var deviceId: String {
        if let existing = UserDefaults.standard.string(forKey: Self.deviceIdKey) {
            return existing
        }
        let fresh = UUID().uuidString
        UserDefaults.standard.set(fresh, forKey: Self.deviceIdKey)
        return fresh
    }

    /// Starts the lifecycle hooks. Flushing on background is what gets the last
    /// events of a session off the device before it is suspended.
    func start() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in await self?.flush() }
            })
        track(AnalyticsEventName.sessionStart)
        Task { await flush() }
    }

    /// Queues an event. Never throws and never blocks the caller: analytics
    /// must not be able to break a screen.
    func track(_ name: String, properties: [String: String] = [:]) {
        let event = QueuedEvent(name: name, occurredAt: Date(), properties: properties)
        pending.append(event)
        if pending.count > Self.maxQueuedEvents {
            pending.removeFirst(pending.count - Self.maxQueuedEvents)
        }
        storage.save(pending)

        if pending.count >= Self.flushThreshold {
            Task { await flush() }
        }
    }

    /// Sends as many whole batches as are pending. Events are removed only after
    /// the server accepts them, so a failure leaves the queue intact for the
    /// next attempt.
    func flush() async {
        guard !isFlushing, !pending.isEmpty else { return }
        isFlushing = true
        defer { isFlushing = false }

        while !pending.isEmpty {
            let batch = Array(pending.prefix(Self.maxBatchSize))
            guard await send(batch) else { return }
            pending.removeFirst(batch.count)
            storage.save(pending)
        }
    }

    /// True only when the server accepted the batch. A 4xx also counts as
    /// accepted: a batch the server will never take is a poison pill that would
    /// otherwise block the queue forever.
    private func send(_ batch: [QueuedEvent]) async -> Bool {
        guard let url = URL(string: "\(AppConfig.apiBaseURL)/v1/events") else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = sessionTokenProvider(), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let formatter = ISO8601DateFormatter()
        let payload: [String: Any] = [
            "deviceId": deviceId,
            "client": APISession.clientHeader,
            "events": batch.map { event in
                [
                    "name": event.name,
                    "occurredAt": formatter.string(from: event.occurredAt),
                    "properties": event.properties,
                ] as [String: Any]
            },
        ]

        guard let body = try? JSONSerialization.data(withJSONObject: payload) else {
            return true // unencodable is a poison pill; drop it rather than retry forever
        }
        request.httpBody = body

        guard let (_, response) = try? await APISession.data(for: request),
              let http = response as? HTTPURLResponse else {
            return false
        }
        // 429 is the one refusal worth retrying: we are being throttled, not rejected.
        if http.statusCode == 429 { return false }
        return (200...499).contains(http.statusCode)
    }

    /// Turns an amount into a coarse range. The analytics store must never hold
    /// an exact salary: a first-party store of precise figures is a materially
    /// worse breach than one holding bands.
    static func bucket(_ amount: Double, width: Double = 1000) -> String {
        guard amount.isFinite, width > 0 else { return "unknown" }
        let lower = (amount / width).rounded(.down) * width
        return "\(Int(lower))-\(Int(lower + width))"
    }
}

/// Where the pending queue lives between launches.
protocol AnalyticsStorage {
    func load() -> [QueuedEvent]
    func save(_ events: [QueuedEvent])
}

/// A JSON file in Application Support. Not UserDefaults: the queue can reach a
/// few hundred events, and UserDefaults is the wrong home for something that
/// size and churn.
struct FileAnalyticsStorage: AnalyticsStorage {
    private var fileURL: URL? {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        guard let base else { return nil }
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("analytics-queue.json")
    }

    func load() -> [QueuedEvent] {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([QueuedEvent].self, from: data)) ?? []
    }

    func save(_ events: [QueuedEvent]) {
        guard let fileURL else { return }
        guard let data = try? JSONEncoder().encode(events) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
