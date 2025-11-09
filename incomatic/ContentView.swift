//
//  ContentView.swift
//  incomatic
//
//  Created by Ben Makusha on 11/9/25.
//
//  Main view with salary input and breakdown display
//  Updated for: https://github.com/benmak11/salary-calculator
//

import SwiftUI

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var viewModel = SalaryCalculatorViewModel()
    
    @State private var annualSalary: String = ""
    @State private var selectedPayFrequency: PayFrequency = .biweekly
    @State private var selectedFilingStatus: FilingStatus = .single
    @State private var allowances: Int = 0
    @State private var pensionPercent: String = "0"
    @State private var hsaContribution: String = "0"
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    headerSection
                    
                    // Location Section
                    locationSection
                    
                    // Input Section
                    inputSection
                    
                    // Calculate Button
                    calculateButton
                    
                    // Results Section
                    if viewModel.isLoading {
                        ProgressView()
                            .padding()
                    } else if let error = viewModel.errorMessage {
                        errorView(error)
                    } else if let result = viewModel.calculationResult {
                        resultsSection(result)
                    }
                }
                .padding()
            }
            .navigationTitle("Incomatic")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Calculate Your Take-Home Pay")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Enter your annual salary to see your paycheck breakdown after taxes and deductions")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Location Section
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(.blue)
                Text("Location")
                    .font(.headline)
                Spacer()
                
                if locationManager.isLoading {
                    ProgressView()
                } else {
                    Button(action: {
                        locationManager.requestLocation()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.blue)
                    }
                }
            }
            
            if !locationManager.state.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("State:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(locationManager.state)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
            } else if let error = locationManager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            } else {
                Button(action: {
                    locationManager.requestLocation()
                }) {
                    HStack {
                        Image(systemName: "location.circle")
                        Text("Enable Location")
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Input Section
    private var inputSection: some View {
        VStack(spacing: 16) {
            // Annual Salary
            VStack(alignment: .leading, spacing: 8) {
                Text("Annual Salary")
                    .font(.headline)
                
                HStack {
                    Text("$")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    TextField("Enter annual salary", text: $annualSalary)
                        .keyboardType(.decimalPad)
                        .font(.title3)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            
            // Pay Frequency
            VStack(alignment: .leading, spacing: 8) {
                Text("Pay Frequency")
                    .font(.headline)
                
                Picker("Pay Frequency", selection: $selectedPayFrequency) {
                    ForEach(PayFrequency.allCases, id: \.self) { frequency in
                        Text(frequency.displayName).tag(frequency)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            // Filing Status
            VStack(alignment: .leading, spacing: 8) {
                Text("Filing Status")
                    .font(.headline)
                
                Picker("Filing Status", selection: $selectedFilingStatus) {
                    ForEach(FilingStatus.allCases, id: \.self) { status in
                        Text(status.displayName).tag(status)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            
            // Allowances
            VStack(alignment: .leading, spacing: 8) {
                Text("Allowances")
                    .font(.headline)
                
                Stepper(value: $allowances, in: 0...10) {
                    Text("\(allowances)")
                        .font(.title3)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            
            // Optional: 401(k) Contribution
            VStack(alignment: .leading, spacing: 8) {
                Text("401(k) Contribution % (Optional)")
                    .font(.headline)
                
                HStack {
                    TextField("0", text: $pensionPercent)
                        .keyboardType(.decimalPad)
                        .font(.body)
                    Text("%")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            
            // Optional: HSA Contribution
            VStack(alignment: .leading, spacing: 8) {
                Text("HSA Annual Contribution (Optional)")
                    .font(.headline)
                
                HStack {
                    Text("$")
                        .foregroundColor(.secondary)
                    TextField("0", text: $hsaContribution)
                        .keyboardType(.decimalPad)
                        .font(.body)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Calculate Button
    private var calculateButton: some View {
        Button(action: {
            calculateSalary()
        }) {
            HStack {
                Image(systemName: "plus.forwardslash.minus")
                Text("Calculate")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(canCalculate ? Color.blue : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(!canCalculate)
    }
    
    private var canCalculate: Bool {
        guard let salary = Double(annualSalary), salary > 0 else { return false }
        return !locationManager.state.isEmpty
    }
    
    // MARK: - Results Section
    private func resultsSection(_ result: ViewFriendlyResponse) -> some View {
        VStack(spacing: 20) {
            // Summary Card
            summaryCard(result)
            
            // Gross Pay Section
            grossPaySection(result.grossPay)
            
            // Taxes Section
            taxesSection(result.taxes)
            
            // Deductions Section (if any)
            if result.deductions.total > 0 {
                deductionsSection(result.deductions)
            }
            
            // Net Pay Section
            netPaySection(result.netPay)
        }
        .padding(.top)
    }
    
    // MARK: - Summary Card
    private func summaryCard(_ result: ViewFriendlyResponse) -> some View {
        VStack(spacing: 12) {
            Text("Your Paycheck Breakdown")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Gross Pay")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(result.grossPay.perPayPeriod))
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Net Pay")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(result.netPay.perPayPeriod))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
            }
            
            // Visual breakdown bar
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: geometry.size.width * CGFloat(result.netPay.takeHomePercentage / 100))
                    
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: geometry.size.width * CGFloat((100 - result.netPay.takeHomePercentage) / 100))
                }
            }
            .frame(height: 8)
            .cornerRadius(4)
            
            HStack {
                Text("Take home: \(String(format: "%.1f", result.netPay.takeHomePercentage))%")
                    .font(.caption)
                    .foregroundColor(.green)
                Spacer()
                Text("Taxes & Deductions: \(String(format: "%.1f", 100 - result.netPay.takeHomePercentage))%")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Gross Pay Section
    private func grossPaySection(_ grossPay: GrossPay) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Gross Pay", icon: "dollarsign.circle.fill")
            
            VStack(spacing: 8) {
                breakdownRow(label: "Annual Salary", value: formatCurrency(grossPay.annual))
                breakdownRow(label: "Per Pay Period (\(grossPay.payFrequency.capitalized))",
                           value: formatCurrency(grossPay.perPayPeriod),
                           highlighted: true)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Taxes Section
    private func taxesSection(_ taxes: Taxes) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Taxes", icon: "doc.text.fill")
            
            VStack(spacing: 8) {
                // Federal Tax
                if let federalTax = taxes.federal {
                    breakdownRow(label: "Federal Income Tax", value: formatCurrency(federalTax.amount))
                    if let rate = federalTax.rate {
                        Text("Rate: \(String(format: "%.2f", rate))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    Divider()
                }
                
                // FICA Taxes
                Text("FICA Taxes")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                if let socialSecurity = taxes.fica.socialSecurity {
                    breakdownRow(label: "  Social Security",
                               value: formatCurrency(socialSecurity.amount),
                               indent: true)
                }
                if let medicare = taxes.fica.medicare {
                    breakdownRow(label: "  Medicare",
                               value: formatCurrency(medicare.amount),
                               indent: true)
                }
                
                if let additionalMedicare = taxes.fica.additionalMedicare {
                    breakdownRow(label: "  Additional Medicare",
                               value: formatCurrency(additionalMedicare.amount),
                               indent: true)
                }
                
                Divider()
                
                // State Tax
                if let stateTax = taxes.state {
                    breakdownRow(label: "State Income Tax", value: formatCurrency(stateTax.amount))
                    if let rate = stateTax.rate {
                        Text("Rate: \(String(format: "%.2f", rate))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    Divider()
                }
                
                // Local Tax
                if let localTax = taxes.local {
                    breakdownRow(label: "Local Tax", value: formatCurrency(localTax.amount))
                    Divider()
                }
                
                // Total Taxes
                breakdownRow(label: "Total Taxes",
                           value: formatCurrency(taxes.totalTaxes),
                           highlighted: true)
                
                Text("Effective Tax Rate: \(String(format: "%.2f", taxes.effectiveTaxRate))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Deductions Section
    private func deductionsSection(_ deductions: Deductions) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Deductions", icon: "minus.circle.fill")
            
            VStack(spacing: 8) {
                if !deductions.preTax.isEmpty {
                    Text("Pre-Tax Deductions")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    ForEach(deductions.preTax, id: \.name) { item in
                        breakdownRow(label: "  \(item.name)",
                                   value: formatCurrency(item.amount),
                                   indent: true)
                    }
                    
                    Divider()
                }
                
                if !deductions.postTax.isEmpty {
                    Text("Post-Tax Deductions")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    ForEach(deductions.postTax, id: \.name) { item in
                        breakdownRow(label: "  \(item.name)",
                                   value: formatCurrency(item.amount),
                                   indent: true)
                    }
                    
                    Divider()
                }
                
                breakdownRow(label: "Total Deductions",
                           value: formatCurrency(deductions.total),
                           highlighted: true)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Net Pay Section
    private func netPaySection(_ netPay: NetPay) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Net Pay (Take Home)", icon: "banknote.fill", color: .green)
            
            VStack(spacing: 8) {
                breakdownRow(label: "Annual Net Pay", value: formatCurrency(netPay.annual))
                breakdownRow(label: "Per Pay Period",
                           value: formatCurrency(netPay.perPayPeriod),
                           highlighted: true)
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Helper Views
    private func sectionHeader(title: String, icon: String, color: Color = .blue) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(title)
                .font(.headline)
        }
    }
    
    private func breakdownRow(label: String, value: String, highlighted: Bool = false, indent: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(highlighted ? .body : .subheadline)
                .fontWeight(highlighted ? .semibold : .regular)
                .foregroundColor(highlighted ? .primary : .secondary)
            Spacer()
            Text(value)
                .font(highlighted ? .body : .subheadline)
                .fontWeight(highlighted ? .bold : .medium)
                .foregroundColor(highlighted ? .primary : .secondary)
        }
    }
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundColor(.red)
            
            Text("Error")
                .font(.headline)
            
            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Helper Functions
    private func calculateSalary() {
        guard let salary = Double(annualSalary) else { return }
        guard let stateCode = getStateCode(from: locationManager.state) else {
            viewModel.errorMessage = "Unable to determine state code from location"
            return
        }
        
        let pensionPercentValue = (Double(pensionPercent) ?? 0) / 100.0
        let hsaValue = Double(hsaContribution) ?? 0
        
        let pretax: PreTaxDeductions? = (pensionPercentValue > 0 || hsaValue > 0) ?
            PreTaxDeductions(
                pensionPercent: pensionPercentValue > 0 ? pensionPercentValue : nil,
                fixed: nil,
                hsa: hsaValue > 0 ? hsaValue : nil
            ) : nil
        
        let request = SalaryCalculationRequest(
            country: "US",
            taxYear: 2025,
            annualSalary: salary,
            cadence: selectedPayFrequency.apiValue,
            pretax: pretax,
            posttax: nil,
            countryOptions: CountryOptions(
                US: USOptions(
                    state: stateCode,
                    filingStatus: selectedFilingStatus.apiValue,
                    allowances: allowances > 0 ? allowances : nil
                ),
                UK: nil
            )
        )
        
        Task {
            await viewModel.calculateSalary(request: request)
        }
    }
    
    private func getStateCode(from stateName: String) -> String? {
        let stateAbbreviations: [String: String] = [
            "Alabama": "AL", "Alaska": "AK", "Arizona": "AZ", "Arkansas": "AR",
            "California": "CA", "Colorado": "CO", "Connecticut": "CT", "Delaware": "DE",
            "Florida": "FL", "Georgia": "GA", "Hawaii": "HI", "Idaho": "ID",
            "Illinois": "IL", "Indiana": "IN", "Iowa": "IA", "Kansas": "KS",
            "Kentucky": "KY", "Louisiana": "LA", "Maine": "ME", "Maryland": "MD",
            "Massachusetts": "MA", "Michigan": "MI", "Minnesota": "MN", "Mississippi": "MS",
            "Missouri": "MO", "Montana": "MT", "Nebraska": "NE", "Nevada": "NV",
            "New Hampshire": "NH", "New Jersey": "NJ", "New Mexico": "NM", "New York": "NY",
            "North Carolina": "NC", "North Dakota": "ND", "Ohio": "OH", "Oklahoma": "OK",
            "Oregon": "OR", "Pennsylvania": "PA", "Rhode Island": "RI", "South Carolina": "SC",
            "South Dakota": "SD", "Tennessee": "TN", "Texas": "TX", "Utah": "UT",
            "Vermont": "VT", "Virginia": "VA", "Washington": "WA", "West Virginia": "WV",
            "Wisconsin": "WI", "Wyoming": "WY"
        ]
        return stateAbbreviations[stateName]
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

// MARK: - Enums
enum PayFrequency: String, CaseIterable {
    case weekly
    case biweekly
    case monthly
    
    var displayName: String {
        switch self {
        case .weekly: return "Weekly"
        case .biweekly: return "Bi-weekly"
        case .monthly: return "Monthly"
        }
    }
    
    var apiValue: String {
        switch self {
        case .weekly: return "WEEKLY"
        case .biweekly: return "BIWEEKLY"
        case .monthly: return "MONTHLY"
        }
    }
}

enum FilingStatus: String, CaseIterable {
    case single
    case married
    
    var displayName: String {
        switch self {
        case .single: return "Single"
        case .married: return "Married Filing Jointly"
        }
    }
    
    var apiValue: String {
        switch self {
        case .single: return "SINGLE"
        case .married: return "MARRIED"
        }
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
