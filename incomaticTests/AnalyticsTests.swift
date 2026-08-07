//
//  AnalyticsTests.swift
//  incomaticTests
//
//  The analytics queue is what makes Phase 1's exit criterion measurable, so
//  the behaviour that matters here is "nothing is silently lost".
//

import XCTest
@testable import Incomatic

/// In-memory stand-in for the on-disk queue.
final class MemoryAnalyticsStorage: AnalyticsStorage, @unchecked Sendable {
    var stored: [QueuedEvent] = []
    func load() -> [QueuedEvent] { stored }
    func save(_ events: [QueuedEvent]) { stored = events }
}

@MainActor
final class AnalyticsTests: XCTestCase {

    private var storage: MemoryAnalyticsStorage!
    private var analytics: Analytics!

    override func setUp() {
        super.setUp()
        StubURLProtocol.install()
        storage = MemoryAnalyticsStorage()
        analytics = Analytics(storage: storage)
    }

    override func tearDown() {
        StubURLProtocol.uninstall()
        super.tearDown()
    }

    func test_track_persistsImmediatelyRatherThanWaitingForAFlush() {
        analytics.track("session_start")

        // A crash or a suspend between tracking and flushing must not lose the event.
        XCTAssertEqual(storage.stored.count, 1)
        XCTAssertEqual(storage.stored.first?.name, "session_start")
    }

    func test_queueSurvivesRelaunch() {
        analytics.track("session_start")
        analytics.track("calculation_completed")

        let relaunched = Analytics(storage: storage)
        XCTAssertEqual(relaunched.deviceId, analytics.deviceId, "device id must be stable across launches")
        XCTAssertEqual(storage.stored.count, 2)
    }

    func test_aFailedSendKeepsTheEventsQueued() async {
        StubURLProtocol.stub = .init(statusCode: 0, transportError: URLError(.notConnectedToInternet))
        analytics.track("session_start")

        await analytics.flush()

        XCTAssertEqual(storage.stored.count, 1, "a dropped batch would bias the measurement it exists to take")
    }

    func test_throttlingIsRetriedRatherThanDiscarded() async {
        StubURLProtocol.stub = .init(statusCode: 429)
        analytics.track("session_start")

        await analytics.flush()

        XCTAssertEqual(storage.stored.count, 1, "429 means try later, not give up")
    }

    func test_anAcceptedBatchClearsTheQueue() async {
        StubURLProtocol.stub = .init(statusCode: 202, body: #"{"accepted":1}"#.data(using: .utf8))
        analytics.track("session_start")

        await analytics.flush()

        XCTAssertTrue(storage.stored.isEmpty)
    }

    func test_aBatchTheServerRejectsIsDroppedRatherThanBlockingTheQueue() async {
        // A 400 will still be a 400 on every retry. Keeping it would wedge the
        // queue permanently and lose every event queued behind it.
        StubURLProtocol.stub = .init(statusCode: 400, body: #"{"error":"bad"}"#.data(using: .utf8))
        analytics.track("session_start")

        await analytics.flush()

        XCTAssertTrue(storage.stored.isEmpty)
    }

    func test_theQueueIsCappedAndDropsOldestFirst() {
        StubURLProtocol.stub = .init(statusCode: 0, transportError: URLError(.notConnectedToInternet))
        for i in 0..<520 {
            analytics.track("session_start", properties: ["i": String(i)])
        }

        XCTAssertEqual(storage.stored.count, 500, "an offline install must not grow a file without limit")
        XCTAssertEqual(storage.stored.first?.properties["i"], "20", "oldest go first; newest are the useful ones")
    }

    func test_bucketRoundsDownToAStableBand() {
        XCTAssertEqual(Analytics.bucket(2847.13), "2000-3000")
        XCTAssertEqual(Analytics.bucket(3000), "3000-4000")
        XCTAssertEqual(Analytics.bucket(0), "0-1000")
        XCTAssertEqual(Analytics.bucket(-50), "-1000-0")
    }

    func test_bucketRefusesValuesItCannotBand() {
        XCTAssertEqual(Analytics.bucket(.nan), "unknown")
        XCTAssertEqual(Analytics.bucket(.infinity), "unknown")
        XCTAssertEqual(Analytics.bucket(1000, width: 0), "unknown")
    }
}
