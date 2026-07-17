//
//  EquityStore.swift
//  incomatic
//
//  Created by Ben Makusha on 07/17/2026
//
//  Owns the signed-in user's RSU grants: loads from /v1/grants, saves edits,
//  deletes optimistically with rollback on failure (§G). Views observe this
//  and derive "vesting this year" via VestMath.
//

import Foundation
import Combine

@MainActor
final class EquityStore: ObservableObject {
    @Published private(set) var grants: [RsuGrant] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var hasLoaded = false

    private let service = EquityService()

    /// Wire the AccountManager so grant + stock calls carry the session token.
    func attach(accountManager: AccountManager) {
        service.sessionTokenProvider = { [weak accountManager] in accountManager?.sessionToken }
    }

    /// Exposed for the grant form's ticker search + quote fetches.
    var equityService: EquityService { service }

    /// Grant-derived RSU value vesting in the current tax year.
    var vestingThisYear: Double {
        VestMath.value(inYear: AppConfig.taxYear, grants: grants)
    }

    /// Distinct tickers/companies for the Equity card subline ("AAPL, RDDT").
    var tickerSummary: String {
        let names = grants.map { $0.ticker ?? $0.company ?? "—" }
        return Array(NSOrderedSet(array: names)).compactMap { $0 as? String }.joined(separator: ", ")
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            grants = try await service.listGrants()
            hasLoaded = true
        } catch EquityService.EquityError.notAuthenticated {
            grants = []
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Create (nil id) or update (existing id). Returns true on success.
    func save(_ grant: RsuGrant) async -> Bool {
        errorMessage = nil
        do {
            if grant.id == nil {
                let created = try await service.createGrant(grant)
                grants.append(created)
            } else {
                let updated = try await service.updateGrant(grant)
                if let idx = grants.firstIndex(where: { $0.id == updated.id }) {
                    grants[idx] = updated
                } else {
                    grants.append(updated)
                }
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Optimistic removal; restores the grant and surfaces the error on failure.
    func delete(_ grant: RsuGrant) async {
        guard let id = grant.id, let idx = grants.firstIndex(where: { $0.id == id }) else { return }
        errorMessage = nil
        let removed = grants.remove(at: idx)
        do {
            try await service.deleteGrant(id: id)
        } catch {
            grants.insert(removed, at: min(idx, grants.count))
            errorMessage = "Couldn't delete grant — restored"
        }
    }

    func clear() {
        grants = []
        hasLoaded = false
        errorMessage = nil
    }
}
