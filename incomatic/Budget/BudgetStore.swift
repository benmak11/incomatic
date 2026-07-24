//
//  BudgetStore.swift
//  incomatic
//
//  Created by Ben Makusha on 07/24/2026
//
//  Owns the signed-in user's household budget: loads/saves/deletes the
//  single /v1/budget object, and fetches AI-suggested plans from
//  /v1/budget/plan. Same shape as EquityStore, with two differences that
//  follow from the backend being single-object rather than list-CRUD: no
//  per-item create/update, and a plan fetch that works even when signed out
//  (mirrors /v1/calculate's auth-optional preview behavior) — callers that
//  get a nil plan back should fall back to BudgetEngine's own default
//  waterfall (aiContributions: nil), not treat it as a hard failure.
//

import Foundation
import Combine

@MainActor
final class BudgetStore: ObservableObject {
    @Published private(set) var budget = Budget()
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var hasLoaded = false
    @Published private(set) var isGeneratingPlan = false
    @Published private(set) var latestPlan: BudgetPlan?

    private let service = BudgetService()

    /// Wire the AccountManager so budget calls carry the session token.
    func attach(accountManager: AccountManager) {
        service.sessionTokenProvider = { [weak accountManager] in accountManager?.sessionToken }
    }

    /// Exposed for callers building a `BudgetPlanRequest` directly against
    /// the service (e.g. a not-yet-saved preview before the goals sheet
    /// commits anything to `budget`).
    var budgetService: BudgetService { service }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            budget = try await service.getBudget()
            hasLoaded = true
        } catch BudgetService.BudgetServiceError.notFound {
            budget = Budget()
            hasLoaded = true
        } catch BudgetService.BudgetServiceError.notAuthenticated {
            budget = Budget()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Replaces the whole budget (goals + expenses) — mirrors the server's
    /// PUT-replaces-wholesale semantics, there's no per-item save.
    @discardableResult
    func save(_ budget: Budget) async -> Bool {
        errorMessage = nil
        do {
            self.budget = try await service.saveBudget(budget)
            hasLoaded = true
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Optimistic clear; restores the budget and surfaces the error on failure.
    func delete() async {
        errorMessage = nil
        let previous = budget
        budget = Budget()
        do {
            try await service.deleteBudget()
        } catch {
            budget = previous
            errorMessage = "Couldn't delete budget — restored"
        }
    }

    /// Fetches an AI-generated plan for `request`. Returns nil (with
    /// `errorMessage` left untouched for the expected "unavailable" case) so
    /// callers reliably fall back to `BudgetEngine.buildPlan(aiContributions: nil)`
    /// instead of showing an error for what is, by design, a graceful-degradation path.
    func generatePlan(_ request: BudgetPlanRequest) async -> BudgetPlan? {
        isGeneratingPlan = true
        defer { isGeneratingPlan = false }
        do {
            let plan = try await service.generatePlan(request)
            latestPlan = plan
            return plan
        } catch BudgetService.BudgetServiceError.planUnavailable {
            return nil
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func clear() {
        budget = Budget()
        hasLoaded = false
        errorMessage = nil
        latestPlan = nil
    }
}
