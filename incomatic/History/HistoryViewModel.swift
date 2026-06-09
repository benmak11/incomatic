//
//  HistoryViewModel.swift
//  incomatic
//
//
//  Created by Ben Makusha on 06/09/2026
//
//  Owns the list of saved calculations + load/delete actions for the History tab.
//

import Combine
import Foundation

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published private(set) var sessions: [SavedCalculationSummary] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let service: CalculationHistoryService
    private weak var accountManager: AccountManager?

    init(service: CalculationHistoryService = CalculationHistoryService()) {
        self.service = service
    }

    /// Wire to the AccountManager so the service sees the current token and we can
    /// react to sign-out by clearing state.
    func attach(accountManager: AccountManager) {
        self.accountManager = accountManager
        service.sessionTokenProvider = { [weak accountManager] in accountManager?.sessionToken }
    }

    func load() async {
        guard accountManager?.isSignedIn == true else {
            sessions = []
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let response = try await service.list(limit: 50)
            sessions = response.items
        } catch CalculationHistoryService.HistoryError.notAuthenticated {
            sessions = []
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ id: String) async {
        do {
            try await service.delete(id: id)
            sessions.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearForSignOut() {
        sessions = []
        errorMessage = nil
    }

    /// Optimistically prepend a summary returned from a freshly-saved calculation,
    /// then trigger a background reload to pick up the canonical row.
    func prepend(_ summary: SavedCalculationSummary) {
        sessions.removeAll { $0.id == summary.id }
        sessions.insert(summary, at: 0)
    }

    func detail(for id: String) async throws -> SavedCalculationDetail {
        try await service.get(id: id)
    }
}
