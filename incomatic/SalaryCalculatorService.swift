//
//  SalaryCalculatorService.swift
//  incomatic
//
//  Created by Ben Makusha on 11/9/25.
//
//  API service for calculating salary breakdown
//

import Foundation

// MARK: - Request/Response Models
struct SalaryCalculationRequest: Codable {
    let country: String
    let taxYear: Int
    let annualSalary: Double
    let cadence: String? // "ANNUAL", "MONTHLY", "BIWEEKLY", "WEEKLY"
    let pretax: PreTaxDeductions?
    let posttax: PostTaxDeductions?
    let countryOptions: CountryOptions
}

struct CountryOptions: Codable {
    let US: USOptions?
    let UK: UKOptions?
}

struct USOptions: Codable {
    let state: String
    let filingStatus: String // "SINGLE", "MARRIED"
    let allowances: Int?
}

struct UKOptions: Codable {
    let taxCode: String?
    let scottishResident: Bool?
    let niCategory: String?
}

struct PreTaxDeductions: Codable {
    let pensionPercent: Double?
    let fixed: Double?
    let hsa: Double?
}

struct PostTaxDeductions: Codable {
    let fixed: Double?
    let studentLoanPlan: String?
}

struct SalaryCalculationResponse: Codable {
    let calculationId: String
    let grossPerCadence: Double
    let netPerCadence: Double
    let currency: String
    let rulePackVersion: String
    let lineItems: [LineItem]
    let explanation: [ExplanationItem]
}

struct LineItem: Codable {
    let name: String
    let amount: Double
}

struct ExplanationItem: Codable {
    let id: String
    let text: String
}

// MARK: - View-friendly models for UI display
struct ViewFriendlyResponse {
    let grossPay: GrossPay
    let taxes: Taxes
    let deductions: Deductions
    let netPay: NetPay
}

struct GrossPay {
    let annual: Double
    let perPayPeriod: Double
    let payFrequency: String
}

struct Taxes {
    let federal: TaxBreakdown?
    let state: TaxBreakdown?
    let local: TaxBreakdown?
    let fica: FICATaxes
    let totalTaxes: Double
    let effectiveTaxRate: Double
}

struct TaxBreakdown {
    let amount: Double
    let rate: Double?
    let description: String
}

struct FICATaxes {
    let socialSecurity: TaxBreakdown?
    let medicare: TaxBreakdown?
    let additionalMedicare: TaxBreakdown?
    let total: Double
}

struct Deductions {
    let preTax: [DeductionItem]
    let postTax: [DeductionItem]
    let total: Double
}

struct DeductionItem {
    let name: String
    let amount: Double
}

struct NetPay {
    let annual: Double
    let perPayPeriod: Double
    let takeHomePercentage: Double
}

// MARK: - API Service
class SalaryCalculatorService {
    // Update this with your actual API endpoint
    private let baseURL = "http://localhost:8080"
    
    enum APIError: LocalizedError {
        case invalidURL
        case networkError(Error)
        case invalidResponse
        case decodingError(Error)
        case serverError(String)
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid API URL"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .invalidResponse:
                return "Invalid response from server"
            case .decodingError(let error):
                return "Failed to decode response: \(error.localizedDescription)"
            case .serverError(let message):
                return message
            }
        }
    }
    
    func calculateSalary(request: SalaryCalculationRequest) async throws -> ViewFriendlyResponse {
        guard let url = URL(string: "\(baseURL)/v1/calculate") else {
            throw APIError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let jsonData = try JSONEncoder().encode(request)
            urlRequest.httpBody = jsonData
            
            // Debug print
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("Request JSON: \(jsonString)")
            }
            
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                if let errorMessage = String(data: data, encoding: .utf8) {
                    throw APIError.serverError(errorMessage)
                }
                throw APIError.serverError("Server returned status code: \(httpResponse.statusCode)")
            }
            
            let decoder = JSONDecoder()
            let apiResponse = try decoder.decode(SalaryCalculationResponse.self, from: data)
            
            // Transform API response to view-friendly format
            return transformToViewFriendly(apiResponse: apiResponse, originalRequest: request)
            
        } catch let error as APIError {
            throw error
        } catch let error as DecodingError {
            throw APIError.decodingError(error)
        } catch {
            throw APIError.networkError(error)
        }
    }
    
    // Transform the API response to our view-friendly format
    private func transformToViewFriendly(apiResponse: SalaryCalculationResponse, originalRequest: SalaryCalculationRequest) -> ViewFriendlyResponse {
        
        // Calculate annual amounts based on cadence
        let cadence = originalRequest.cadence ?? "ANNUAL"
        let periodsPerYear: Double
        let displayCadence: String
        
        switch cadence {
        case "WEEKLY":
            periodsPerYear = 52
            displayCadence = "weekly"
        case "BIWEEKLY":
            periodsPerYear = 26
            displayCadence = "biweekly"
        case "MONTHLY":
            periodsPerYear = 12
            displayCadence = "monthly"
        default: // ANNUAL
            periodsPerYear = 1
            displayCadence = "annual"
        }
        
        let annualGross = cadence == "ANNUAL" ? apiResponse.grossPerCadence : apiResponse.grossPerCadence * periodsPerYear
        let annualNet = cadence == "ANNUAL" ? apiResponse.netPerCadence : apiResponse.netPerCadence * periodsPerYear
        
        // Parse line items
        var federalTax: TaxBreakdown?
        var stateTax: TaxBreakdown?
        var localTax: TaxBreakdown?
        var socialSecurity: TaxBreakdown?
        var medicare: TaxBreakdown?
        var additionalMedicare: TaxBreakdown?
        var preTaxDeductions: [DeductionItem] = []
        var postTaxDeductions: [DeductionItem] = []
        var totalTaxes: Double = 0
        
        for item in apiResponse.lineItems {
            _ = cadence == "ANNUAL" ? item.amount : item.amount * periodsPerYear
            
            if item.name.contains("Federal Income Tax") {
                federalTax = TaxBreakdown(amount: item.amount, rate: nil, description: item.name)
                totalTaxes += item.amount
            } else if item.name.contains("State Income Tax") {
                stateTax = TaxBreakdown(amount: item.amount, rate: nil, description: item.name)
                totalTaxes += item.amount
            } else if item.name.contains("Local") && item.name.contains("Tax") {
                localTax = TaxBreakdown(amount: item.amount, rate: nil, description: item.name)
                totalTaxes += item.amount
            } else if item.name.contains("Social Security") || item.name.contains("FICA (Social Security)") {
                socialSecurity = TaxBreakdown(amount: item.amount, rate: 6.2, description: "Social Security")
                totalTaxes += item.amount
            } else if item.name.contains("Medicare") && !item.name.contains("Additional") {
                medicare = TaxBreakdown(amount: item.amount, rate: 1.45, description: "Medicare")
                totalTaxes += item.amount
            } else if item.name.contains("Additional Medicare") {
                additionalMedicare = TaxBreakdown(amount: item.amount, rate: 0.9, description: "Additional Medicare Tax")
                totalTaxes += item.amount
            } else if item.name.contains("Pre-tax Deductions") || item.name.contains("Employee Pension") || item.name.contains("HSA") {
                if item.amount > 0 {
                    preTaxDeductions.append(DeductionItem(name: item.name, amount: item.amount))
                }
            } else if item.name.contains("Post-tax Deductions") {
                if item.amount > 0 {
                    postTaxDeductions.append(DeductionItem(name: item.name, amount: item.amount))
                }
            }
        }
        
        let ficaTotal = (socialSecurity?.amount ?? 0) + (medicare?.amount ?? 0) + (additionalMedicare?.amount ?? 0)
        let fica = FICATaxes(
            socialSecurity: socialSecurity,
            medicare: medicare,
            additionalMedicare: additionalMedicare,
            total: ficaTotal
        )
        
        let effectiveTaxRate = annualGross > 0 ? (totalTaxes * periodsPerYear / annualGross) * 100 : 0
        let takeHomePercentage = annualGross > 0 ? (annualNet / annualGross) * 100 : 0
        
        let grossPay = GrossPay(
            annual: annualGross,
            perPayPeriod: apiResponse.grossPerCadence,
            payFrequency: displayCadence
        )
        
        let taxes = Taxes(
            federal: federalTax,
            state: stateTax,
            local: localTax,
            fica: fica,
            totalTaxes: totalTaxes,
            effectiveTaxRate: effectiveTaxRate
        )
        
        let preTaxTotal = preTaxDeductions.reduce(0) { $0 + $1.amount }
        let postTaxTotal = postTaxDeductions.reduce(0) { $0 + $1.amount }
        
        let deductions = Deductions(
            preTax: preTaxDeductions,
            postTax: postTaxDeductions,
            total: preTaxTotal + postTaxTotal
        )
        
        let netPay = NetPay(
            annual: annualNet,
            perPayPeriod: apiResponse.netPerCadence,
            takeHomePercentage: takeHomePercentage
        )
        
        return ViewFriendlyResponse(
            grossPay: grossPay,
            taxes: taxes,
            deductions: deductions,
            netPay: netPay
        )
    }
}

