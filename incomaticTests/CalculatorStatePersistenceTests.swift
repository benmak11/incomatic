//
//  CalculatorStatePersistenceTests.swift
//  incomaticTests
//
//  The retention leak this closes: a cold launch used to discard everything the
//  user had entered.
//

import XCTest
@testable import Incomatic

final class MemoryCalculatorStateStorage: CalculatorStateStorage, @unchecked Sendable {
    var stored: CalculatorStateSnapshot?
    func load() -> CalculatorStateSnapshot? { stored }
    func save(_ snapshot: CalculatorStateSnapshot) { stored = snapshot }
    func clear() { stored = nil }
}

@MainActor
final class CalculatorStatePersistenceTests: XCTestCase {

    private var storage: MemoryCalculatorStateStorage!

    override func setUp() {
        super.setUp()
        storage = MemoryCalculatorStateStorage()
        CalculatorStatePersistence.storage = storage
    }

    override func tearDown() {
        CalculatorStatePersistence.storage = FileCalculatorStateStorage()
        super.tearDown()
    }

    private func populated() -> CalculatorState {
        let state = CalculatorState()
        state.salaryAmount = "125000"
        state.payFrequency = .semiMonthly
        state.incomeType = .salary
        state.filingStatus = .marriedJoint
        state.selectedStateCode = "NY"
        state.medicalPerPeriod = "142.50"
        state.traditional401kPercent = 6
        state.bonusRecurring = true
        state.customDeductions = [CustomDeduction(name: "Union dues", amount: "25")]
        return state
    }

    func test_inputsSurviveARelaunch() {
        CalculatorStatePersistence.save(populated())

        let fresh = CalculatorState()
        CalculatorStatePersistence.restore(into: fresh)

        XCTAssertEqual(fresh.salaryAmount, "125000")
        XCTAssertEqual(fresh.payFrequency, .semiMonthly)
        XCTAssertEqual(fresh.filingStatus, .marriedJoint)
        XCTAssertEqual(fresh.selectedStateCode, "NY")
        XCTAssertEqual(fresh.medicalPerPeriod, "142.50")
        XCTAssertEqual(fresh.traditional401kPercent, 6)
        XCTAssertTrue(fresh.bonusRecurring)
        XCTAssertEqual(fresh.customDeductions.first?.name, "Union dues")
    }

    func test_serverAndDerivedValuesAreNotPersisted() {
        let state = populated()
        state.grantDerivedRsuAnnual = 40_000
        state.needsRecalculation = true
        state.statesList = [SalaryCalculatorService.StateEntry(code: "ZZ", name: "Stale")]
        CalculatorStatePersistence.save(state)

        let fresh = CalculatorState()
        CalculatorStatePersistence.restore(into: fresh)

        // Recomputed from EquityStore — a persisted copy would let a deleted grant
        // go on inflating the estimate.
        XCTAssertEqual(fresh.grantDerivedRsuAnnual, 0)
        XCTAssertFalse(fresh.needsRecalculation)
        // Fetched from the backend; a stale list would outlive a server-side change.
        XCTAssertTrue(fresh.statesList.isEmpty)
    }

    func test_restoringFromNothingLeavesTheDefaults() {
        let fresh = CalculatorState()
        CalculatorStatePersistence.restore(into: fresh)

        XCTAssertEqual(fresh.salaryAmount, "")
        XCTAssertEqual(fresh.regularHoursPerPeriod, "80")
        XCTAssertEqual(fresh.selectedStateCode, "CA")
    }

    func test_clearRemovesTheUsersFigures() {
        CalculatorStatePersistence.save(populated())
        CalculatorStatePersistence.clear()

        let fresh = CalculatorState()
        CalculatorStatePersistence.restore(into: fresh)
        XCTAssertEqual(fresh.salaryAmount, "", "figures must not outlive a deleted account")
    }

    func test_aSnapshotFromAnOlderBuildStillDecodes() throws {
        // An added field must not make the whole file unreadable, or the upgrade
        // silently wipes exactly the data this exists to keep.
        let partial = #"{"salaryAmount":"90000","selectedStateCode":"TX"}"#.data(using: .utf8)!
        let snapshot = try JSONDecoder().decode(CalculatorStateSnapshot.self, from: partial)

        XCTAssertEqual(snapshot.salaryAmount, "90000")
        XCTAssertEqual(snapshot.selectedStateCode, "TX")
        XCTAssertEqual(snapshot.regularHoursPerPeriod, "80", "missing fields fall back to defaults")
    }
}
