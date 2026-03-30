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

// MARK: - Design tokens
private extension Color {
    static let incNavy    = Color(red: 0.102, green: 0.180, blue: 0.267) // #1A2E44
    static let incTeal    = Color(red: 0.165, green: 0.361, blue: 0.431) // #2A5C6E
    static let incBg      = Color(red: 0.941, green: 0.957, blue: 0.973) // #F0F4F8
    static let incSecText = Color(red: 0.420, green: 0.478, blue: 0.553) // #6B7A8D
    static let incRed     = Color(red: 0.851, green: 0.310, blue: 0.310) // #D94F4F
    static let incPill    = Color(red: 0.906, green: 0.929, blue: 0.953)
    static let incGreen   = Color(red: 0.100, green: 0.650, blue: 0.400)
}

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var viewModel = SalaryCalculatorViewModel()

    // All original state preserved — these feed directly into the API request
    @State private var annualSalary: String = ""
    @State private var selectedPayFrequency: PayFrequency = .biweekly
    @State private var selectedFilingStatus: FilingStatus = .single
    @State private var allowances: Int = 0
    @State private var pensionPercent: String = "6"
    @State private var hsaContribution: String = "0"

    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            inputScreen
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)

            dashboardScreen
                .tabItem { Label("Summary", systemImage: "chart.bar.fill") }
                .tag(1)

            settingsScreen
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(2)
        }
        .accentColor(.incNavy)
        // Auto-navigate to dashboard once a calculation completes
        .onChange(of: viewModel.isLoading) { _, isLoading in
            if !isLoading && viewModel.calculationResult != nil {
                selectedTab = 1
            }
        }
    }

    // ─────────────────────────────────────────
    // MARK: - Tab 1: Input Screen
    // ─────────────────────────────────────────
    private var inputScreen: some View {
        ZStack {
            Color.incBg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {
                    inputNavBar
                    VStack(alignment: .leading, spacing: 24) {
                        inputHeroHeader
                        baseCompensationCard
                        taxDeductionsCard
                        calculationCtaCard
                        Spacer(minLength: 80)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
            }
        }
    }

    private var inputNavBar: some View {
        HStack {
            avatarCircle(size: 36)
            Text("Incomatic")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.incNavy)
            Spacer()
            Button(action: {}) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 20))
                    .foregroundColor(.incNavy)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var inputHeroHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("REVENUE PROJECTION")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.incSecText)
                .tracking(1.5)
            Text("Define your\nFinancial Horizon.")
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(.incNavy)
                .lineSpacing(3)
            Text("Enter your core earnings and deductions to visualize your net impact. Our engine calculates real-time volatility and sanctuary thresholds.")
                .font(.system(size: 14))
                .foregroundColor(.incSecText)
                .lineSpacing(3)
                .padding(.top, 2)
        }
    }

    private var baseCompensationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("YEARLY BASE COMPENSATION")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.incSecText)
                .tracking(1.5)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("$")
                    .font(.system(size: 36, weight: .light))
                    .foregroundColor(.incSecText)
                TextField("0.00", text: $annualSalary)
                    .font(.system(size: 36, weight: .light))
                    .foregroundColor(annualSalary.isEmpty ? .incSecText : .incNavy)
                    .keyboardType(.decimalPad)
            }

            HStack(spacing: 10) {
                // Frequency pill
                Menu {
                    ForEach(PayFrequency.allCases, id: \.self) { freq in
                        Button(freq.displayName) { selectedPayFrequency = freq }
                    }
                } label: {
                    pillView(selectedPayFrequency.displayName)
                }

                // Location pill
                pillView(locationDisplayText,
                         icon: locationManager.isLoading ? nil : "mappin.and.ellipse")
                    .overlay(
                        Group {
                            if locationManager.isLoading { ProgressView().scaleEffect(0.7) }
                        }
                    )
            }

            // Filing status — subtle secondary control
            Menu {
                ForEach(FilingStatus.allCases, id: \.self) { status in
                    Button(status.displayName) { selectedFilingStatus = status }
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Filing: \(selectedFilingStatus.displayName)")
                        .font(.system(size: 12))
                        .foregroundColor(.incSecText)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(.incSecText)
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
    }

    private var taxDeductionsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Tax & Deductions")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.incNavy)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            deductionInputRow(
                icon: "bag.fill",
                iconBg: Color(red: 0.851, green: 0.933, blue: 0.953),
                iconFg: .incTeal,
                title: "401(k) Contribution",
                subtitle: "Pre-tax retirement savings"
            ) {
                HStack(spacing: 2) {
                    TextField("6", text: $pensionPercent)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.incNavy)
                        .frame(width: 36)
                        .multilineTextAlignment(.center)
                        .padding(6)
                        .background(Color.incPill)
                        .cornerRadius(8)
                    Text("%")
                        .font(.system(size: 14))
                        .foregroundColor(.incSecText)
                }
            }

            Divider().padding(.leading, 62)

            deductionInputRow(
                icon: "cross.fill",
                iconBg: Color(red: 0.851, green: 0.851, blue: 0.933),
                iconFg: Color(red: 0.40, green: 0.40, blue: 0.80),
                title: "Healthcare Premium",
                subtitle: "Monthly medical & dental"
            ) {
                Button(action: {}) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.incSecText)
                }
            }

            Spacer(minLength: 4)
        }
        .background(Color.white)
        .cornerRadius(16)
    }

    private func deductionInputRow<T: View>(
        icon: String,
        iconBg: Color,
        iconFg: Color,
        title: String,
        subtitle: String,
        @ViewBuilder trailing: () -> T
    ) -> some View {
        HStack(spacing: 14) {
            iconBadge(systemName: icon, bg: iconBg, fg: iconFg)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.incNavy)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.incSecText)
            }
            Spacer()
            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var calculationCtaCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 20))
                .foregroundColor(.white.opacity(0.8))

            VStack(alignment: .leading, spacing: 6) {
                Text("Instant Precision\nReporting")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                Text("Our sanctuary logic calculates federal, state, and local taxes based on the latest 2024 fiscal guidelines.")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.75))
                    .lineSpacing(3)
            }

            // Projected take-home readout
            HStack {
                Text("PROJECTED TAKE-HOME")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                    .tracking(0.8)
                Spacer()
                if viewModel.isLoading {
                    ProgressView().tint(.white).scaleEffect(0.8)
                } else {
                    Text(viewModel.calculationResult.map { formatCurrency($0.netPay.perPayPeriod) } ?? "$0.00")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.12))
            .cornerRadius(10)

            // Inline error
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(10)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(8)
            }

            Button(action: calculateSalary) {
                Group {
                    if viewModel.isLoading {
                        ProgressView().tint(.incTeal)
                    } else {
                        Text("Calculate Impact")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.incTeal)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.white)
                .cornerRadius(12)
            }
            .disabled(!canCalculate || viewModel.isLoading)
        }
        .padding(20)
        .background(Color.incTeal)
        .cornerRadius(20)
    }

    // ─────────────────────────────────────────
    // MARK: - Tab 2: Dashboard Screen
    // ─────────────────────────────────────────
    private var dashboardScreen: some View {
        ZStack {
            Color.incBg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {
                    dashboardNavBar
                    if let result = viewModel.calculationResult {
                        VStack(spacing: 16) {
                            dashboardHero
                            netPayHeroCard(result.netPay)
                            HStack(spacing: 12) {
                                grossCard(result.grossPay)
                                taxCard(result.taxes)
                            }
                            deductionBreakdownCard(result)
                            smartInsightCard
                            longTermTeaser
                            Spacer(minLength: 80)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    } else {
                        emptyDashboard
                    }
                }
            }
        }
    }

    private var dashboardNavBar: some View {
        HStack {
            Text("Incomatic")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.incNavy)
            Spacer()
            avatarCircle(size: 36)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var dashboardHero: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MONTHLY SUMMARY")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.incSecText)
                .tracking(1.5)
            Text("Financial\nClarity.")
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.incNavy)
                .lineSpacing(3)
            Text("Your personalized breakdown of net earnings, projected tax liabilities, and strategic deductions.")
                .font(.system(size: 14))
                .foregroundColor(.incSecText)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func netPayHeroCard(_ netPay: NetPay) -> some View {
        let parts = splitCurrency(netPay.perPayPeriod)
        return VStack(alignment: .leading, spacing: 12) {
            Text("Estimated Net Pay")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.incSecText)

            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(parts.0)
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(.incNavy)
                Text(parts.1)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.incSecText)
                    .padding(.leading, 2)
            }

            HStack(spacing: 4) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11))
                Text("+\(String(format: "%.1f", netPay.takeHomePercentage))% take-home rate")
                    .font(.system(size: 12))
            }
            .foregroundColor(.incGreen)

            sparklineView.frame(height: 56)
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
    }

    private var sparklineView: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let pts: [CGFloat] = [0.50, 0.38, 0.55, 0.32, 0.48, 0.62, 0.42, 0.68, 0.52, 0.72]
            let step = w / CGFloat(pts.count - 1)
            Path { path in
                for (i, y) in pts.enumerated() {
                    let pt = CGPoint(x: CGFloat(i) * step,
                                    y: h - (y * h * 0.8) - h * 0.1)
                    if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
                }
            }
            .stroke(Color(red: 0.10, green: 0.55, blue: 0.45), lineWidth: 2)
        }
    }

    private func grossCard(_ grossPay: GrossPay) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            iconBadge(systemName: "building.columns.fill",
                      bg: Color(red: 0.851, green: 0.933, blue: 0.953),
                      fg: .incTeal)
            Text("Total Gross")
                .font(.system(size: 12))
                .foregroundColor(.incSecText)
            Text(formatCurrency(grossPay.perPayPeriod))
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.incNavy)
            Text("Pre-tax earnings per \(grossPay.payFrequency) period")
                .font(.system(size: 10))
                .foregroundColor(.incSecText)
                .lineLimit(2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(16)
    }

    private func taxCard(_ taxes: Taxes) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            iconBadge(systemName: "doc.text.fill",
                      bg: Color(red: 1.0, green: 0.90, blue: 0.90),
                      fg: .incRed)
            Text("Tax Withheld")
                .font(.system(size: 12))
                .foregroundColor(.incSecText)
            Text(formatCurrency(taxes.totalTaxes))
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.incNavy)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(UIColor.systemGray5)).frame(height: 4)
                    Capsule()
                        .fill(Color.incRed)
                        .frame(width: geo.size.width * CGFloat(min(taxes.effectiveTaxRate / 50.0, 1.0)),
                               height: 4)
                }
            }
            .frame(height: 4)

            Text("\(String(format: "%.1f", taxes.effectiveTaxRate))% EFFECTIVE RATE")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.incRed)
                .tracking(0.5)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(16)
    }

    private func deductionBreakdownCard(_ result: ViewFriendlyResponse) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("Deduction Breakdown")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.incNavy)
                Spacer()
                Button("View Paystub") {}
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.incTeal)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            if let fed = result.taxes.federal {
                Divider().padding(.leading, 62)
                deductionResultRow(icon: "building.columns",
                                   iconBg: Color(red: 0.90, green: 0.93, blue: 0.97), iconFg: .incTeal,
                                   title: "Federal Income Tax", subtitle: "Standard Rate",
                                   amount: fed.amount, badge: nil)
            }
            if let ss = result.taxes.fica.socialSecurity {
                Divider().padding(.leading, 62)
                deductionResultRow(icon: "shield.fill",
                                   iconBg: Color(red: 0.88, green: 0.93, blue: 0.97),
                                   iconFg: Color(red: 0.30, green: 0.55, blue: 0.75),
                                   title: "Social Security", subtitle: "FICA mandated",
                                   amount: ss.amount, badge: nil)
            }
            if let med = result.taxes.fica.medicare {
                Divider().padding(.leading, 62)
                deductionResultRow(icon: "cross.fill",
                                   iconBg: Color(red: 0.90, green: 0.90, blue: 1.00),
                                   iconFg: Color(red: 0.40, green: 0.40, blue: 0.80),
                                   title: "Medicare", subtitle: "FICA mandated",
                                   amount: med.amount, badge: nil)
            }
            ForEach(result.deductions.preTax, id: \.name) { item in
                Divider().padding(.leading, 62)
                deductionResultRow(icon: "bag.fill",
                                   iconBg: Color(red: 0.851, green: 0.933, blue: 0.953), iconFg: .incTeal,
                                   title: item.name, subtitle: "Pre-tax Savings",
                                   amount: item.amount,
                                   badge: (item.name.contains("401") || item.name.lowercased().contains("pension")) ? "MATCHED" : nil)
            }
            if let addMed = result.taxes.fica.additionalMedicare {
                Divider().padding(.leading, 62)
                deductionResultRow(icon: "cross.circle.fill",
                                   iconBg: Color(red: 1.00, green: 0.90, blue: 0.90), iconFg: .incRed,
                                   title: "Additional Medicare", subtitle: "FICA mandated",
                                   amount: addMed.amount, badge: nil)
            }
        }
        .background(Color.white)
        .cornerRadius(16)
    }

    private func deductionResultRow(icon: String, iconBg: Color, iconFg: Color,
                                    title: String, subtitle: String,
                                    amount: Double, badge: String?) -> some View {
        HStack(spacing: 14) {
            iconBadge(systemName: icon, bg: iconBg, fg: iconFg)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.incNavy)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.incSecText)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("-\(formatCurrency(amount))")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.incNavy)
                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.incGreen)
                        .tracking(0.5)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var smartInsightCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 22))
                .foregroundColor(.white.opacity(0.9))

            VStack(alignment: .leading, spacing: 6) {
                Text("Smart Insight")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                Text("By increasing your 401(k) contribution by 1%, you could reduce your taxable income by $1,200 annually while securing your future sanctuary.")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.8))
                    .lineSpacing(3)
            }

            Button(action: {}) {
                Text("Apply Strategy")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.black.opacity(0.25))
                    .cornerRadius(12)
            }
        }
        .padding(20)
        .background(Color.incTeal)
        .cornerRadius(20)
    }

    private var longTermTeaser: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.systemGray3))
                .frame(height: 160)
            VStack(alignment: .leading, spacing: 4) {
                Text("Plan for the long term.")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                Text("Incomatic ensures your daily work\ntranslates into permanent security.")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.85))
            }
            .padding(20)
        }
    }

    private var emptyDashboard: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 60)
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 52))
                .foregroundColor(.incSecText.opacity(0.4))
            Text("Financial Clarity.")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.incNavy)
            Text("Go to the Home tab, enter your salary,\nand tap Calculate Impact to see your\npersonalized breakdown here.")
                .font(.system(size: 14))
                .foregroundColor(.incSecText)
                .multilineTextAlignment(.center)
            Button(action: { selectedTab = 0 }) {
                Text("Get Started")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(Color.incTeal)
                    .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
    }

    // ─────────────────────────────────────────
    // MARK: - Tab 3: Settings
    // ─────────────────────────────────────────
    private var settingsScreen: some View {
        ZStack {
            Color.incBg.ignoresSafeArea()
            VStack(spacing: 8) {
                Text("Settings")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.incNavy)
                Text("Coming soon")
                    .font(.system(size: 14))
                    .foregroundColor(.incSecText)
            }
        }
    }

    // ─────────────────────────────────────────
    // MARK: - Shared helpers
    // ─────────────────────────────────────────
    private func avatarCircle(size: CGFloat) -> some View {
        Circle()
            .fill(Color(red: 0.20, green: 0.40, blue: 0.55))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: "person.fill")
                    .foregroundColor(.white)
                    .font(.system(size: size * 0.4))
            )
    }

    private func iconBadge(systemName: String, bg: Color, fg: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(bg)
                .frame(width: 38, height: 38)
            Image(systemName: systemName)
                .font(.system(size: 15))
                .foregroundColor(fg)
        }
    }

    private func pillView(_ text: String, icon: String? = nil) -> some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 11))
            }
            Text(text)
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundColor(.incNavy)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.incPill)
        .cornerRadius(8)
    }

    private var locationDisplayText: String {
        if locationManager.isLoading { return "Detecting..." }
        if !locationManager.state.isEmpty {
            let code = getStateCode(from: locationManager.state) ?? locationManager.state
            let city = locationManager.county
            return city.isEmpty ? code : "\(city), \(code)"
        }
        return locationManager.errorMessage != nil ? "Location Error" : "Add Location"
    }

    private func splitCurrency(_ amount: Double) -> (String, String) {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        let full = formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
        let parts = full.components(separatedBy: ".")
        return parts.count == 2 ? (parts[0], ".\(parts[1])") : (full, "")
    }

    // ─────────────────────────────────────────
    // MARK: - Logic (unchanged from original)
    // ─────────────────────────────────────────
    private var canCalculate: Bool {
        guard let salary = Double(annualSalary), salary > 0 else { return false }
        return !locationManager.state.isEmpty
    }

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

// MARK: - Enums (unchanged)
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
