//
//  SalaryCalculatorViewModel.swift
//  incomatic
//
//  Created by Ben Makusha on 11/9/25.
//
//  ViewModel for managing salary calculation state and API calls.
//

import Foundation
import Combine

@MainActor
class SalaryCalculatorViewModel: ObservableObject {
    @Published var calculationResult: ViewFriendlyResponse?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let service = SalaryCalculatorService()

    func calculateSalary(
        request: SalaryCalculationRequest,
        baseSalaryAnnual: Double,
        bonusAnnual: Double,
        benefits: BenefitsInput
    ) async {
        isLoading = true
        errorMessage = nil
        calculationResult = nil

        do {
            let result = try await service.calculateSalary(
                request: request,
                baseSalaryAnnual: baseSalaryAnnual,
                bonusAnnual: bonusAnnual,
                benefits: benefits
            )
            calculationResult = result
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func reset() {
        calculationResult = nil
        errorMessage = nil
        isLoading = false
    }
}
