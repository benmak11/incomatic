//
//  ContentView.swift
//  incomatic
//
//  Created by Ben Makusha on 11/9/25.
//
//  Main view with salary input and breakdown display

import SwiftUI

// MARK: - Design Tokens (Sage)

private extension Color {
    static let incBg              = Color(red: 0.961, green: 0.945, blue: 0.918)  // #F5F1EA
    static let incSurface         = Color.white
    static let incText            = Color(red: 0.122, green: 0.165, blue: 0.165)  // #1F2A2A
    static let incTextDim         = Color(red: 0.353, green: 0.408, blue: 0.408)  // #5A6868
    static let incTextMute        = Color(red: 0.580, green: 0.627, blue: 0.620)  // #94A09E
    static let incSage            = Color(red: 0.373, green: 0.549, blue: 0.486)  // #5F8C7C
    static let incSageDeep        = Color(red: 0.247, green: 0.420, blue: 0.361)  // #3F6B5C
    static let incSageSoft        = Color(red: 0.843, green: 0.894, blue: 0.871)  // #D7E4DE
    static let incSageBg          = Color(red: 0.933, green: 0.961, blue: 0.945)  // #EEF5F1
    static let incBlush           = Color(red: 0.910, green: 0.608, blue: 0.490)  // #E89B7D
    static let incBlushBg         = Color(red: 0.984, green: 0.914, blue: 0.871)  // #FBE9DE
    static let incHairline        = Color(red: 0.122, green: 0.165, blue: 0.165).opacity(0.08)
    static let incHairlineStrong  = Color(red: 0.122, green: 0.165, blue: 0.165).opacity(0.14)
    static let incRed             = Color(red: 0.851, green: 0.231, blue: 0.231)
}

// MARK: - Currency Helpers

private func formatCurrency(_ amount: Double) -> String {
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.currencyCode = "USD"
    return f.string(from: NSNumber(value: amount)) ?? "$\(amount)"
}

private func formatSigned(_ amount: Double) -> String {
    if amount < 0 { return "−" + formatCurrency(-amount) }
    return formatCurrency(amount)
}

// MARK: - Shared Card

struct IncCard<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.incSurface)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 22, x: 0, y: 6)
            .shadow(color: Color.black.opacity(0.02), radius: 2, x: 0, y: 1)
    }
}

struct CustomDeduction: Identifiable {
    var id = UUID()
    var name: String = ""
    var amount: String = ""
}

// MARK: - Top Bar (wordmark only)

struct IncTopBar: View {
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.incSage)
                    .frame(width: 34, height: 34)
                    .shadow(color: Color.incSage.opacity(0.3), radius: 6, x: 0, y: 2)
                Text("i")
                    .italic()
                    .font(.system(size: 16, weight: .bold, design: .serif))
                    .foregroundColor(.white)
            }
            Text("incomatic")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.incText)
                .kerning(-0.4)
            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }
}

// MARK: - Root View

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var viewModel = SalaryCalculatorViewModel()
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            CalculatorTab(
                locationManager: locationManager,
                viewModel: viewModel
            )
            .tabItem { Label("Calculator", systemImage: "doc.text") }
            .tag(0)

            InsightsTab(
                result: viewModel.calculationResult,
                isLoading: viewModel.isLoading,
                errorMessage: viewModel.errorMessage,
                onAdjust: { selectedTab = 0 }
            )
            .tabItem { Label("Insights", systemImage: "chart.bar") }
            .tag(1)
        }
        .accentColor(.incSage)
        .onChange(of: viewModel.isLoading) { _, loading in
            if !loading && viewModel.calculationResult != nil {
                selectedTab = 1
            }
        }
    }
}

// MARK: - CALCULATOR TAB

struct CalculatorTab: View {
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var viewModel: SalaryCalculatorViewModel

    @State private var activeSection: CalculatorSection = .earnings

    // ─ Earnings ───────────────────────────────────────────────
    @State private var payFrequency: PayFrequency = .biweekly
    @State private var incomeType: IncomeType = .salary
    @State private var salaryAmount: String = ""
    @State private var salaryBasis: SalaryBasis = .perYear
    @State private var hourlyRate: String = ""
    @State private var regularHoursPerPeriod: String = "80"
    @State private var overtimeHoursPerPeriod: String = ""
    @State private var bonusAmount: String = ""        // annual
    @State private var commissionAmount: String = ""   // annual
    @State private var payDate: Date = Date()

    // ─ Federal ────────────────────────────────────────────────
    @State private var filingStatus: FilingStatus = .single
    @State private var useOldW4: Bool = false
    @State private var nonresidentAlien: Bool = false
    @State private var multipleJobs: Bool = false
    @State private var dependentsAmount: String = ""
    @State private var otherIncome: String = ""
    @State private var itemizedDeductions: String = ""
    @State private var additionalWithholding: String = ""   // per period
    @State private var exemptFederal: Bool = false
    @State private var exemptSocialSecurity: Bool = false
    @State private var exemptMedicare: Bool = false

    // ─ State / Territory ──────────────────────────────────────
    @State private var statesList: [SalaryCalculatorService.StateEntry] = []
    @State private var selectedStateCode: String = "CA"
    @State private var livesInDifferentState: Bool = false
    @State private var resideStateCode: String = ""
    @State private var nonResidencyCertificate: Bool = false
    @State private var mdCounty: String = "Anne Arundel"

    // ─ Benefits ───────────────────────────────────────────────
    @State private var medicalPerPeriod: String = ""
    @State private var dentalPerPeriod: String = ""
    @State private var visionPerPeriod: String = ""
    @State private var healthcareFsaPerPeriod: String = ""
    @State private var dependentCareFsaPerPeriod: String = ""
    @State private var hsaPerPeriod: String = ""
    @State private var traditional401kPercent: Double = 6.0
    @State private var roth401kPercent: Double = 0.0
    @State private var customDeductions: [CustomDeduction] = []

    private let service = SalaryCalculatorService()

    private var canCalculate: Bool {
        let hasSalary  = (Double(salaryAmount) ?? 0) > 0
        let hasHourly  = (Double(hourlyRate) ?? 0) > 0
        let hasBonus   = (Double(bonusAmount) ?? 0) > 0
        let hasComm    = (Double(commissionAmount) ?? 0) > 0
        return (hasSalary || hasHourly || hasBonus || hasComm) && !selectedStateCode.isEmpty
    }

    // ─ Live preview (client-side estimate; no network) ────────
    // Quick approximation so the sticky CTA can show "projected take-home
    // per period" as the user types. Server's /v1/calculate result is
    // always authoritative on Calculate.
    private var livePreviewPerPeriod: Double? {
        let salary  = Double(salaryAmount) ?? 0
        let hourly  = (Double(hourlyRate) ?? 0) *
                      ((Double(regularHoursPerPeriod) ?? 0) +
                       (Double(overtimeHoursPerPeriod) ?? 0) * 1.5) *
                      payFrequency.periodsPerYear
        let bonus   = Double(bonusAmount) ?? 0
        let comm    = Double(commissionAmount) ?? 0
        let annualGross = (incomeType == .salary
            ? (salaryBasis == .perYear ? salary : salary * payFrequency.periodsPerYear)
            : hourly) + bonus + comm
        guard annualGross > 0 else { return nil }

        // Pre-tax benefits (per-period → annual)
        let periods = payFrequency.periodsPerYear
        func ann(_ s: String) -> Double {
            (Double(s) ?? 0) * periods
        }
        let pretaxBenefits = ann(medicalPerPeriod) + ann(dentalPerPeriod) +
            ann(visionPerPeriod) + ann(healthcareFsaPerPeriod) +
            ann(dependentCareFsaPerPeriod) + ann(hsaPerPeriod) +
            (annualGross * (traditional401kPercent / 100.0))

        let taxable = max(0, annualGross - pretaxBenefits - 14_600) // 2025 std deduction (single)
        // Progressive federal (2025 single, rough)
        let brackets: [(cap: Double, rate: Double)] = [
            (11_600, 0.10), (47_150, 0.12), (100_525, 0.22),
            (191_950, 0.24), (243_725, 0.32), (609_350, 0.35),
            (.infinity, 0.37),
        ]
        var fed = 0.0, prev = 0.0, rem = taxable
        for b in brackets {
            let slice = min(rem, b.cap - prev)
            if slice <= 0 { break }
            fed += slice * b.rate
            rem -= slice
            prev = b.cap
            if rem <= 0 { break }
        }

        let stateRates: [String: Double] = [
            "CA": 0.06, "NY": 0.055, "TX": 0, "FL": 0, "MD": 0.0475,
            "WA": 0, "IL": 0.0495, "MA": 0.05,
        ]
        let stateTax = taxable * (stateRates[selectedStateCode] ?? 0.04)
        let ss = min(annualGross, 168_600) * 0.062
        let medicare = annualGross * 0.0145
        let rothAmt = annualGross * (roth401kPercent / 100.0)
        let net = annualGross - fed - stateTax - ss - medicare - pretaxBenefits - rothAmt
        return net / periods
    }

    private var livePreviewPctOfGross: Double? {
        let salary  = Double(salaryAmount) ?? 0
        let bonus   = Double(bonusAmount) ?? 0
        let comm    = Double(commissionAmount) ?? 0
        let annual = (salaryBasis == .perYear ? salary : salary * payFrequency.periodsPerYear) + bonus + comm
        guard annual > 0, let net = livePreviewPerPeriod else { return nil }
        let grossPerPeriod = annual / payFrequency.periodsPerYear
        return grossPerPeriod > 0 ? (net / grossPerPeriod) * 100 : nil
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.incBg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    IncTopBar()
                    SectionStepIndicator(active: $activeSection)
                        .padding(.horizontal, 22)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Define your\nfinancial horizon")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.incText)
                            .kerning(-1)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 24)
                        Text("Enter your earnings and deductions to project your take-home pay.")
                            .font(.system(size: 14))
                            .foregroundColor(.incTextDim)
                            .lineSpacing(3)
                            .frame(maxWidth: 280, alignment: .leading)
                            .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 16)

                    VStack(spacing: 0) {
                        switch activeSection {
                        case .earnings: earningsSection
                        case .federal:  federalSection
                        case .state:    stateSection
                        case .benefits: benefitsSection
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 230)   // leave room for sticky CTA + tab bar
                    .id(activeSection)        // re-mount for animation
                    .transition(.opacity.combined(with: .offset(y: 8)))
                }
            }
            .scrollDismissesKeyboard(.interactively)

            StickyProgressCTA(
                activeSection: $activeSection,
                isLoading: viewModel.isLoading,
                canCalculate: canCalculate,
                payFrequency: payFrequency,
                projectedPerPeriod: livePreviewPerPeriod,
                projectedPct: livePreviewPctOfGross,
                onCalculate: triggerCalculation
            )
            .padding(.bottom, 8)
        }
        .animation(.easeInOut(duration: 0.35), value: activeSection)
        .task { await loadStatesFromApi() }
        .onChange(of: locationManager.state) { _, newState in
            if let match = statesList.first(where: { $0.name == newState }) {
                selectedStateCode = match.code
            }
        }
    }

    // MARK: - Field helpers (underline only)

    private func fieldLabel(_ text: String, suffix: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(text)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.incTextMute)
                .kerning(0.8)
            Spacer()
            if let suffix {
                Text(suffix)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.incSage)
            }
        }
        .padding(.bottom, 6)
    }

    private func amountField(label: String, text: Binding<String>, suffix: String? = nil, placeholder: String = "0.00") -> some View {
        VStack(alignment: .leading, spacing: 0) {
            fieldLabel(label.uppercased(), suffix: suffix)
            HStack(spacing: 8) {
                Text("$").font(.system(size: 18, weight: .semibold)).foregroundColor(.incTextMute)
                TextField(placeholder, text: text)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.incText)
                    .kerning(-0.3)
            }
            .padding(.bottom, 8)
            .overlay(Rectangle().fill(Color.incHairline).frame(height: 2), alignment: .bottom)
        }
        .padding(.bottom, 18)
    }

    private func plainNumberField(label: String, text: Binding<String>, placeholder: String = "0") -> some View {
        VStack(alignment: .leading, spacing: 0) {
            fieldLabel(label.uppercased())
            TextField(placeholder, text: text)
                .keyboardType(.decimalPad)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.incText)
                .padding(.bottom, 8)
                .overlay(Rectangle().fill(Color.incHairline).frame(height: 2), alignment: .bottom)
        }
        .padding(.bottom, 18)
    }

    private func radioRow(_ label: String, status: FilingStatus) -> some View {
        Button(action: { filingStatus = status }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .strokeBorder(filingStatus == status ? Color.incSage : Color.incHairlineStrong, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if filingStatus == status {
                        Circle().fill(Color.incSage).frame(width: 22, height: 22)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundColor(.white)
                    }
                }
                Text(label)
                    .font(.system(size: 15, weight: filingStatus == status ? .semibold : .medium))
                    .foregroundColor(.incText)
                Spacer()
            }
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }

    private func toggleRow(_ label: String, sub: String? = nil, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 15, weight: .medium)).foregroundColor(.incText)
                if let sub {
                    Text(sub).font(.system(size: 12)).foregroundColor(.incTextMute)
                }
            }
            Spacer()
            Toggle("", isOn: isOn).labelsHidden().tint(.incSage)
        }
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private func styledMenu<MenuItems: View>(
        label: String,
        @ViewBuilder items: () -> MenuItems
    ) -> some View {
        Menu {
            items()
        } label: {
            HStack {
                Text(label).foregroundColor(.incText).font(.system(size: 18, weight: .semibold))
                Spacer()
                Image(systemName: "chevron.down")
                    .foregroundColor(.incTextMute).font(.system(size: 13, weight: .bold))
            }
            .padding(.bottom, 8)
            .overlay(Rectangle().fill(Color.incHairline).frame(height: 2), alignment: .bottom)
        }
    }

    private func cardHeader(icon: String, title: String, sub: String? = nil) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.incSageBg)
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .foregroundColor(.incSage)
                    .font(.system(size: 15, weight: .medium))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .bold)).foregroundColor(.incText)
                if let sub {
                    Text(sub).font(.system(size: 12)).foregroundColor(.incTextDim)
                }
            }
        }
        .padding(.bottom, 16)
    }

    // MARK: - Earnings

    @ViewBuilder
    private var earningsSection: some View {
        IncCard {
            VStack(alignment: .leading, spacing: 0) {
                cardHeader(icon: "calendar", title: "Pay frequency", sub: "When your paycheck lands")
                styledMenu(label: payFrequency.displayName) {
                    ForEach(PayFrequency.allCases, id: \.self) { f in
                        Button(f.displayName) { payFrequency = f }
                    }
                }
            }
        }
        .padding(.bottom, 14)

        IncCard {
            VStack(alignment: .leading, spacing: 0) {
                cardHeader(icon: "creditcard", title: "How you're paid")
                Picker("Income Type", selection: $incomeType) {
                    ForEach(IncomeType.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.bottom, 18)
                .colorMultiply(.incSage)

                if incomeType == .salary {
                    amountField(label: "Gross amount", text: $salaryAmount, suffix: salaryBasis.displayName)
                    VStack(alignment: .leading, spacing: 0) {
                        fieldLabel("METHOD")
                        styledMenu(label: salaryBasis.displayName) {
                            ForEach(SalaryBasis.allCases, id: \.self) { b in
                                Button(b.displayName) { salaryBasis = b }
                            }
                        }
                    }
                    .padding(.bottom, 18)
                } else {
                    amountField(label: "Hourly rate", text: $hourlyRate)
                    plainNumberField(label: "Regular hours / period", text: $regularHoursPerPeriod, placeholder: "80")
                    plainNumberField(label: "Overtime hours / period (1.5×)", text: $overtimeHoursPerPeriod)
                }
            }
        }
        .padding(.bottom, 14)

        IncCard {
            VStack(alignment: .leading, spacing: 0) {
                cardHeader(icon: "gift", title: "Bonus & commission", sub: "Taxed at 22% supplemental")
                amountField(label: "Bonus (annual)", text: $bonusAmount)
                amountField(label: "Commission (annual)", text: $commissionAmount)
            }
        }
        .padding(.bottom, 14)
    }

    // MARK: - Federal

    @ViewBuilder
    private var federalSection: some View {
        IncCard {
            VStack(alignment: .leading, spacing: 0) {
                cardHeader(icon: "person.fill", title: "Filing status")
                radioRow("Single or Married filing separately", status: .single)
                radioRow("Married filing jointly",              status: .marriedJoint)
                radioRow("Head of Household",                   status: .headOfHousehold)
            }
        }
        .padding(.bottom, 14)

        IncCard {
            VStack(alignment: .leading, spacing: 0) {
                cardHeader(icon: "doc.text", title: "Form W-4")
                toggleRow("Use 2019 or earlier W-4",            isOn: $useOldW4)
                toggleRow("Nonresident alien",                  isOn: $nonresidentAlien)
                toggleRow("Multiple jobs · spouse works",       isOn: $multipleJobs)
            }
        }
        .padding(.bottom, 14)

        IncCard {
            VStack(alignment: .leading, spacing: 0) {
                cardHeader(icon: "person.2.fill", title: "W-4 details")
                amountField(label: "Dependent amount", text: $dependentsAmount)
                amountField(label: "Other income (annual)", text: $otherIncome)
                amountField(label: "Deductions", text: $itemizedDeductions)
                amountField(label: "Extra withholding / period", text: $additionalWithholding)
            }
        }
        .padding(.bottom, 14)

        IncCard {
            VStack(alignment: .leading, spacing: 0) {
                cardHeader(icon: "checkmark.shield", title: "Exemptions")
                toggleRow("Exempt from Federal Income Tax", isOn: $exemptFederal)
                toggleRow("Exempt from Social Security",    isOn: $exemptSocialSecurity)
                toggleRow("Exempt from Medicare",           isOn: $exemptMedicare)
            }
        }
        .padding(.bottom, 14)
    }

    // MARK: - State

    @ViewBuilder
    private var stateSection: some View {
        IncCard {
            VStack(alignment: .leading, spacing: 0) {
                cardHeader(icon: "mappin.circle.fill", title: "Where you work")
                VStack(alignment: .leading, spacing: 0) {
                    fieldLabel("STATE OR TERRITORY")
                    styledMenu(label: stateNameForCode(selectedStateCode) ?? "Select state") {
                        ForEach(statesList) { entry in
                            Button(entry.name) { selectedStateCode = entry.code }
                        }
                    }
                }
                .padding(.bottom, 18)

                toggleRow("Resides in a different state",
                          sub: "Splits work-state and home-state withholding",
                          isOn: $livesInDifferentState)

                if livesInDifferentState {
                    VStack(alignment: .leading, spacing: 0) {
                        fieldLabel("STATE OF RESIDENCE")
                        styledMenu(label: stateNameForCode(resideStateCode) ?? "Select state") {
                            ForEach(statesList) { entry in
                                Button(entry.name) { resideStateCode = entry.code }
                            }
                        }
                    }
                    .padding(.top, 8).padding(.bottom, 14)
                    toggleRow("Non-residency certificate filed", isOn: $nonResidencyCertificate)
                }

                if selectedStateCode == "MD" {
                    VStack(alignment: .leading, spacing: 0) {
                        fieldLabel("MARYLAND COUNTY")
                        styledMenu(label: mdCounty) {
                            ForEach(["Anne Arundel", "Baltimore City", "Baltimore", "Howard",
                                     "Montgomery", "Prince George's"], id: \.self) { c in
                                Button(c) { mdCounty = c }
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
        .padding(.bottom, 14)

        // Rule-pack callout
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Color.incSurface).frame(width: 36, height: 36)
                Image(systemName: "info.circle.fill").foregroundColor(.incBlush).font(.system(size: 16))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Rule pack 2025.11")
                    .font(.system(size: 13, weight: .bold)).foregroundColor(.incText)
                Text("Multi-state withholding split applies the work-state rate. Your state of residence still files an annual return.")
                    .font(.system(size: 12.5)).foregroundColor(.incTextDim)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.incBlushBg)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .padding(.bottom, 14)
    }

    // MARK: - Benefits

    @ViewBuilder
    private var benefitsSection: some View {
        IncCard {
            VStack(alignment: .leading, spacing: 0) {
                cardHeader(icon: "heart.text.square",
                           title: "Pre-tax benefits",
                           sub: "Per \(payFrequency.displayName.lowercased()) period")
                amountField(label: "Medical",            text: $medicalPerPeriod)
                amountField(label: "Dental",             text: $dentalPerPeriod)
                amountField(label: "Vision",             text: $visionPerPeriod)
                amountField(label: "Healthcare FSA",     text: $healthcareFsaPerPeriod)
                amountField(label: "Dependent care FSA", text: $dependentCareFsaPerPeriod)
                amountField(label: "Healthcare HSA",     text: $hsaPerPeriod)
            }
        }
        .padding(.bottom, 14)

        IncCard {
            VStack(alignment: .leading, spacing: 0) {
                cardHeader(icon: "lock.shield.fill", title: "Retirement", sub: "% of gross pay")

                HStack(alignment: .firstTextBaseline) {
                    fieldLabel("TRADITIONAL 401(K)")
                    Spacer()
                    Text("\(String(format: "%.1f", traditional401kPercent))%")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.incSage)
                        .padding(.horizontal, 12).padding(.vertical, 4)
                        .background(Capsule().fill(Color.incSageBg))
                }
                Slider(value: $traditional401kPercent, in: 0...25, step: 0.5)
                    .tint(.incSage)
                    .padding(.bottom, 18)

                HStack(alignment: .firstTextBaseline) {
                    fieldLabel("ROTH 401(K)")
                    Spacer()
                    Text("\(String(format: "%.1f", roth401kPercent))%")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.incSage)
                        .padding(.horizontal, 12).padding(.vertical, 4)
                        .background(Capsule().fill(Color.incSageBg))
                }
                Slider(value: $roth401kPercent, in: 0...25, step: 0.5)
                    .tint(.incSage)
            }
        }
        .padding(.bottom, 14)

        IncCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    cardHeader(icon: "doc.text", title: "Custom deductions")
                    Spacer()
                    Button(action: { customDeductions.append(CustomDeduction()) }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.incSage).font(.title3)
                    }
                }
                if customDeductions.isEmpty {
                    Text("Tap + to add post-tax line items (annual amounts).")
                        .font(.system(size: 12)).foregroundColor(.incTextDim)
                }
                ForEach($customDeductions) { $deduction in
                    HStack(spacing: 10) {
                        TextField("Name", text: $deduction.name)
                            .font(.system(size: 13))
                            .padding(.horizontal, 10).padding(.vertical, 8)
                            .background(Color.incSageBg).cornerRadius(10)
                        HStack(spacing: 4) {
                            Text("$").foregroundColor(.incTextMute).font(.system(size: 13))
                            TextField("0.00", text: $deduction.amount)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .font(.system(size: 13))
                                .frame(width: 84)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(Color.incSageBg).cornerRadius(10)
                        Button(action: {
                            customDeductions.removeAll { $0.id == deduction.id }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14)).foregroundColor(.incTextMute)
                        }
                    }
                }
            }
        }
        .padding(.bottom, 14)
    }

    // MARK: - Calculation

    private func stateNameForCode(_ code: String) -> String? {
        statesList.first(where: { $0.code == code })?.name
    }

    private func loadStatesFromApi() async {
        do {
            self.statesList = try await service.fetchUSStates()
        } catch {
            self.statesList = Self.fallbackStates
        }
    }

    private func triggerCalculation() {
        let periods = payFrequency.periodsPerYear

        let salaryAmt = Double(salaryAmount) ?? 0
        let salaryRow: SalaryRow? = (incomeType == .salary && salaryAmt > 0)
            ? SalaryRow(amount: salaryAmt, basis: salaryBasis.apiValue)
            : nil

        let rate = Double(hourlyRate) ?? 0
        let hourlyRow: HourlyRow? = (incomeType == .hourly && rate > 0)
            ? HourlyRow(
                rate: rate,
                regularHours: Double(regularHoursPerPeriod),
                overtimeHours: Double(overtimeHoursPerPeriod),
                overtimeMultiplier: nil,
                doubleTimeHours: nil,
                doubleTimeMultiplier: nil
            )
            : nil

        let bonus = Double(bonusAmount) ?? 0
        let commission = Double(commissionAmount) ?? 0

        let earnings: Earnings? = (salaryRow != nil || hourlyRow != nil || bonus > 0 || commission > 0)
            ? Earnings(salary: salaryRow, hourly: hourlyRow,
                       bonus: bonus > 0 ? bonus : nil,
                       commission: commission > 0 ? commission : nil)
            : nil

        func annual(_ s: String) -> Double? {
            guard let v = Double(s), v > 0 else { return nil }
            return v * periods
        }
        let medAnnual = annual(medicalPerPeriod)
        let dentAnnual = annual(dentalPerPeriod)
        let visAnnual = annual(visionPerPeriod)
        let fsaAnnual = annual(healthcareFsaPerPeriod)
        let dcaAnnual = annual(dependentCareFsaPerPeriod)
        let hsaAnnual = annual(hsaPerPeriod)
        let namedCustomDeductions: [NamedDeduction] = customDeductions
            .enumerated()
            .compactMap { idx, deduction in
                guard let amt = Double(deduction.amount), amt > 0 else { return nil }
                let trimmed = deduction.name.trimmingCharacters(in: .whitespacesAndNewlines)
                let label = trimmed.isEmpty ? "Custom Deduction \(idx + 1)" : trimmed
                return NamedDeduction(name: label, amount: amt)
            }

        let pretax = PreTaxDeductions(
            pensionPercent: traditional401kPercent > 0 ? traditional401kPercent / 100.0 : nil,
            fixed: nil,
            hsa: hsaAnnual,
            medical: medAnnual,
            dental: dentAnnual,
            vision: visAnnual,
            healthcareFsa: fsaAnnual,
            dependentCareFsa: dcaAnnual,
            customDeductions: namedCustomDeductions.isEmpty ? nil : namedCustomDeductions
        )

        let posttax = PostTaxDeductions(
            fixed: nil,
            roth401kPercent: roth401kPercent > 0 ? roth401kPercent / 100.0 : nil,
            studentLoanPlan: nil
        )

        let w4HasData = (Double(dependentsAmount) ?? 0) > 0
            || (Double(otherIncome) ?? 0) > 0
            || (Double(itemizedDeductions) ?? 0) > 0
            || (Double(additionalWithholding) ?? 0) > 0
            || exemptFederal || exemptSocialSecurity || exemptMedicare
            || useOldW4 || nonresidentAlien
        let w4: W4? = w4HasData ? W4(
            useOldW4: useOldW4 ? true : nil,
            nonresidentAlien: nonresidentAlien ? true : nil,
            dependentsAmount: Double(dependentsAmount),
            otherIncome: Double(otherIncome),
            itemizedDeductions: Double(itemizedDeductions),
            additionalWithholding: Double(additionalWithholding),
            exemptFederal: exemptFederal ? true : nil,
            exemptSocialSecurity: exemptSocialSecurity ? true : nil,
            exemptMedicare: exemptMedicare ? true : nil
        ) : nil

        let payDateString: String = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            return f.string(from: payDate)
        }()

        let request = SalaryCalculationRequest(
            country: "US",
            taxYear: 2025,
            annualSalary: nil,
            bonus: nil,
            earnings: earnings,
            payDate: payDateString,
            cadence: payFrequency.apiValue,
            pretax: pretax,
            posttax: posttax,
            countryOptions: CountryOptions(
                US: USOptions(
                    state: selectedStateCode,
                    filingStatus: filingStatus.apiValue,
                    allowances: nil,
                    w4: w4
                ),
                UK: nil
            )
        )

        let baseAnnual: Double = {
            if let s = salaryRow {
                return s.basis == "PER_YEAR" ? s.amount : s.amount * periods
            }
            if let h = hourlyRow {
                let rh = (h.regularHours ?? 0) * h.rate * periods
                let oh = (h.overtimeHours ?? 0) * h.rate * (h.overtimeMultiplier ?? 1.5) * periods
                return rh + oh
            }
            return 0
        }()

        Task {
            await viewModel.calculateSalary(
                request: request,
                baseSalaryAnnual: baseAnnual,
                bonusAnnual: bonus + commission,
                benefits: BenefitsInput(
                    medicalPremium: medAnnual ?? 0,
                    dentalPremium: dentAnnual ?? 0,
                    lifeInsurancePremium: 0
                )
            )
        }
    }

    static let fallbackStates: [SalaryCalculatorService.StateEntry] = [
        .init(code: "AL", name: "Alabama"), .init(code: "AK", name: "Alaska"),
        .init(code: "AZ", name: "Arizona"), .init(code: "AR", name: "Arkansas"),
        .init(code: "CA", name: "California"), .init(code: "CO", name: "Colorado"),
        .init(code: "CT", name: "Connecticut"), .init(code: "DE", name: "Delaware"),
        .init(code: "DC", name: "District of Columbia"),
        .init(code: "FL", name: "Florida"), .init(code: "GA", name: "Georgia"),
        .init(code: "HI", name: "Hawaii"), .init(code: "ID", name: "Idaho"),
        .init(code: "IL", name: "Illinois"), .init(code: "IN", name: "Indiana"),
        .init(code: "IA", name: "Iowa"), .init(code: "KS", name: "Kansas"),
        .init(code: "KY", name: "Kentucky"), .init(code: "LA", name: "Louisiana"),
        .init(code: "ME", name: "Maine"), .init(code: "MD", name: "Maryland"),
        .init(code: "MA", name: "Massachusetts"), .init(code: "MI", name: "Michigan"),
        .init(code: "MN", name: "Minnesota"), .init(code: "MS", name: "Mississippi"),
        .init(code: "MO", name: "Missouri"), .init(code: "MT", name: "Montana"),
        .init(code: "NE", name: "Nebraska"), .init(code: "NV", name: "Nevada"),
        .init(code: "NH", name: "New Hampshire"), .init(code: "NJ", name: "New Jersey"),
        .init(code: "NM", name: "New Mexico"), .init(code: "NY", name: "New York"),
        .init(code: "NC", name: "North Carolina"), .init(code: "ND", name: "North Dakota"),
        .init(code: "OH", name: "Ohio"), .init(code: "OK", name: "Oklahoma"),
        .init(code: "OR", name: "Oregon"), .init(code: "PA", name: "Pennsylvania"),
        .init(code: "RI", name: "Rhode Island"), .init(code: "SC", name: "South Carolina"),
        .init(code: "SD", name: "South Dakota"), .init(code: "TN", name: "Tennessee"),
        .init(code: "TX", name: "Texas"), .init(code: "UT", name: "Utah"),
        .init(code: "VT", name: "Vermont"), .init(code: "VA", name: "Virginia"),
        .init(code: "WA", name: "Washington"), .init(code: "WV", name: "West Virginia"),
        .init(code: "WI", name: "Wisconsin"), .init(code: "WY", name: "Wyoming")
    ]
}

// MARK: - Section Step Indicator (numbered circles + connecting progress line)

struct SectionStepIndicator: View {
    @Binding var active: CalculatorSection
    private let all = CalculatorSection.allCases

    var body: some View {
        let activeIdx = all.firstIndex(of: active) ?? 0

        ZStack(alignment: .top) {
            // Connecting line
            GeometryReader { geo in
                let inset: CGFloat = 22
                let span = geo.size.width - inset * 2
                let progress = CGFloat(activeIdx) / CGFloat(all.count - 1)
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.incHairline)
                        .frame(width: span, height: 1.5)
                    Rectangle().fill(Color.incSage)
                        .frame(width: span * progress, height: 1.5)
                        .animation(.easeInOut(duration: 0.35), value: activeIdx)
                }
                .offset(x: inset, y: 19)
            }
            .frame(height: 22)

            // Step circles
            HStack {
                ForEach(Array(all.enumerated()), id: \.offset) { idx, sect in
                    let isActive = sect == active
                    let isDone = idx < activeIdx
                    Button(action: { active = sect }) {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .strokeBorder(
                                        isActive || isDone ? Color.clear : Color.incHairlineStrong,
                                        lineWidth: 1.5
                                    )
                                    .background(
                                        Circle().fill(
                                            isActive ? Color.incSage :
                                                isDone ? Color.incSageSoft : Color.incBg
                                        )
                                    )
                                    .frame(width: 24, height: 24)
                                if isDone {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .heavy))
                                        .foregroundColor(.incSageDeep)
                                } else {
                                    Text("\(idx + 1)")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(isActive ? .white : .incTextMute)
                                }
                            }
                            Text(sect.displayName)
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundColor(isActive ? .incText : .incTextMute)
                        }
                    }
                    .buttonStyle(.plain)
                    if idx < all.count - 1 { Spacer() }
                }
            }
        }
    }
}

// MARK: - Sticky Progress CTA
// Live projection ribbon + progressive "Continue to <next>" button with
// a "Skip to calc" escape hatch on non-final sections. On the final
// section the primary button flips to "Calculate detailed projection".

struct StickyProgressCTA: View {
    @Binding var activeSection: CalculatorSection
    let isLoading: Bool
    let canCalculate: Bool
    let payFrequency: PayFrequency
    let projectedPerPeriod: Double?
    let projectedPct: Double?
    let onCalculate: () -> Void

    private var idx: Int { CalculatorSection.allCases.firstIndex(of: activeSection) ?? 0 }
    private var isLast: Bool { idx == CalculatorSection.allCases.count - 1 }
    private var nextSection: CalculatorSection? {
        let all = CalculatorSection.allCases
        return idx + 1 < all.count ? all[idx + 1] : nil
    }

    var body: some View {
        VStack(spacing: 0) {
            ribbon
            buttonRow
        }
        .background(Color.incSurface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22).strokeBorder(Color.incHairline, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.10), radius: 24, x: 0, y: 6)
        .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
        .padding(.horizontal, 14)
    }

    private var ribbon: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("PROJECTED · PER \(payFrequency.displayName.uppercased())")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.incSageDeep)
                    .kerning(0.6)
                if let pct = projectedPct {
                    Text("\(String(format: "%.1f", pct))% of gross")
                        .font(.system(size: 11.5))
                        .foregroundColor(.incTextDim)
                } else {
                    Text("Enter earnings to preview")
                        .font(.system(size: 11.5))
                        .foregroundColor(.incTextDim)
                }
            }
            Spacer()
            Text(projectedPerPeriod.map(formatCurrency) ?? "$0.00")
                .font(.system(size: 19, weight: .bold))
                .foregroundColor(.incSageDeep)
                .kerning(-0.4)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Color.incSageBg)
        .overlay(Rectangle().fill(Color.incHairline).frame(height: 1), alignment: .bottom)
    }

    private var buttonRow: some View {
        HStack(spacing: 8) {
            if !isLast {
                Button(action: onCalculate) {
                    Text("Skip to calc")
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundColor(canCalculate ? .incSage : .incTextMute)
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(canCalculate ? Color.incSageSoft : Color.incHairline, lineWidth: 1.5)
                        )
                }
                .disabled(!canCalculate || isLoading)
            }

            Button(action: {
                if isLast { onCalculate() }
                else if let next = nextSection {
                    withAnimation(.easeInOut(duration: 0.35)) { activeSection = next }
                }
            }) {
                HStack(spacing: 8) {
                    if isLoading {
                        ProgressView().tint(.white)
                        Text("Calculating…")
                    } else {
                        Text(isLast
                             ? "Calculate detailed projection"
                             : "Continue to \(nextSection?.displayName ?? "")")
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .bold))
                    }
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .kerning(-0.2)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isLast && !canCalculate ? Color(red: 0.77, green: 0.80, blue: 0.79) : Color.incSage)
                )
                .shadow(
                    color: (isLast && !canCalculate) ? .clear : Color.incSage.opacity(0.3),
                    radius: 8, x: 0, y: 2
                )
            }
            .disabled((isLast && !canCalculate) || isLoading)
        }
        .padding(10)
    }
}

// MARK: - INSIGHTS TAB

struct InsightsTab: View {
    let result: ViewFriendlyResponse?
    let isLoading: Bool
    let errorMessage: String?
    let onAdjust: () -> Void

    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView().tint(.incSage)
                    Text("Calculating…").font(.system(size: 14)).foregroundColor(.incTextDim)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.incBg.ignoresSafeArea())
            } else if let result = result {
                EarningsBreakdownView(result: result, onAdjust: onAdjust)
            } else {
                emptyState
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().fill(Color.incSageBg).frame(width: 80, height: 80)
                Image(systemName: "chart.bar")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(.incSage)
            }
            Text("No results yet")
                .font(.system(size: 26, weight: .semibold))
                .foregroundColor(.incText)
            Text("Run a calculation to see your earnings breakdown.")
                .font(.system(size: 14))
                .foregroundColor(.incTextDim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button(action: onAdjust) {
                Text("Open Calculator")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 22).padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.incSage))
                    .shadow(color: Color.incSage.opacity(0.3), radius: 8, x: 0, y: 2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.incBg.ignoresSafeArea())
    }
}

// MARK: - Earnings Breakdown

struct EarningsBreakdownView: View {
    let result: ViewFriendlyResponse
    let onAdjust: () -> Void
    @State private var showPDFAlert = false

    // Sage palette donut
    private let takeHomeColor = Color.incSage
    private let taxesColor    = Color.incBlush
    private let benefitsColor = Color(red: 0.894, green: 0.780, blue: 0.478) // #E4C77A

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                IncTopBar()
                pageHeader
                netPayHero
                itemizedSummaryCard
                actionButtons
            }
            .padding(.bottom, 32)
        }
        .background(Color.incBg.ignoresSafeArea())
        .refreshable {
            // Hook for future GET /v1/calculations/{id}/refresh once implemented.
            try? await Task.sleep(nanoseconds: 700_000_000)
        }
        .alert("Coming Soon", isPresented: $showPDFAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("PDF report download requires a backend endpoint (POST /v1/reports/pdf) that has not yet been implemented.")
        }
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("RESULTS · \(result.grossPay.payFrequency.uppercased())")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.incSage).kerning(0.8)
            Text("Earnings breakdown")
                .font(.system(size: 32, weight: .semibold))
                .foregroundColor(.incText).kerning(-1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        .padding(.top, 4)
    }

    // ─ Category groupings ────────────────────────────────────
    private var earningsItems: [LineItem] {
        result.lineItems.filter { $0.category == "EARNINGS" }
    }
    private var taxItems: [LineItem] {
        result.lineItems.filter {
            $0.category == "TAX_FEDERAL" || $0.category == "TAX_FICA" || $0.category == "TAX_STATE"
        }
    }
    private var benefitItems: [LineItem] {
        result.lineItems.filter {
            $0.category == "PRE_TAX_BENEFIT" || $0.category == "RETIREMENT" || $0.category == "POST_TAX"
        }
    }
    private var earningsTotal: Double { earningsItems.reduce(0) { $0 + $1.amount } }
    private var taxesTotal:    Double { taxItems.reduce(0)    { $0 + $1.amount } }
    private var benefitsTotal: Double { benefitItems.reduce(0){ $0 + $1.amount } }
    private var netPay: Double         { result.netPay.perPayPeriod }

    private var netPayHero: some View {
        IncCard {
            VStack(spacing: 14) {
                DonutChart(
                    wedges: [
                        .init(value: netPay,        color: takeHomeColor),
                        .init(value: taxesTotal,    color: taxesColor),
                        .init(value: benefitsTotal, color: benefitsColor)
                    ],
                    centerLabel: "Take home",
                    centerValue: formatCurrency(netPay)
                )
                .frame(height: 190)

                HStack(spacing: 18) {
                    legendDot(color: takeHomeColor, label: "Take home")
                    legendDot(color: taxesColor,    label: "Taxes")
                    legendDot(color: benefitsColor, label: "Benefits")
                }

                Text("\(String(format: "%.1f", result.netPay.takeHomePercentage))% of gross is yours per \(result.grossPay.payFrequency) paycheck")
                    .font(.system(size: 12.5)).foregroundColor(.incTextDim)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 16)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(label).font(.system(size: 11, weight: .semibold)).foregroundColor(.incTextDim)
        }
    }

    private var itemizedSummaryCard: some View {
        IncCard {
            VStack(spacing: 0) {
                sectionRow("Earnings", amount: earningsTotal)
                ForEach(earningsItems, id: \.name) { item in
                    indentedRow(item.name, amount: item.amount)
                }
                if !taxItems.isEmpty {
                    divider
                    sectionRow("Taxes", amount: -taxesTotal)
                    ForEach(taxItems, id: \.name) { item in
                        indentedRow(item.name, amount: -item.amount)
                    }
                }
                if !benefitItems.isEmpty {
                    divider
                    sectionRow("Benefits", amount: -benefitsTotal)
                    ForEach(benefitItems, id: \.name) { item in
                        indentedRow(item.name, amount: -item.amount)
                    }
                }
                Rectangle().fill(Color.incSageBg).frame(height: 2).padding(.vertical, 10)
                takeHomeRow
            }
        }
        .padding(.horizontal, 16)
    }

    private var divider: some View {
        Rectangle().fill(Color.incHairline).frame(height: 1).padding(.vertical, 8)
    }

    private func sectionRow(_ label: String, amount: Double) -> some View {
        HStack {
            Text(label).font(.system(size: 14, weight: .bold)).foregroundColor(.incText)
            Spacer()
            Text(formatSigned(amount))
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.incText)
                .monospacedDigit()
        }
        .padding(.vertical, 4)
    }

    private func indentedRow(_ label: String, amount: Double) -> some View {
        HStack {
            Text(label).font(.system(size: 12.5)).foregroundColor(.incTextDim).padding(.leading, 12)
            Spacer()
            Text(formatSigned(amount))
                .font(.system(size: 12.5)).foregroundColor(.incTextDim)
                .monospacedDigit()
        }
        .padding(.vertical, 3)
    }

    private var takeHomeRow: some View {
        HStack {
            Text("Take home").font(.system(size: 18, weight: .semibold)).foregroundColor(.incText)
            Spacer()
            Text(formatCurrency(netPay))
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.incSage)
                .monospacedDigit()
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button(action: { showPDFAlert = true }) {
                Text("Download PDF report")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundColor(.incText)
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.incHairlineStrong, lineWidth: 1.5))
            }
            Button(action: onAdjust) {
                Text("Adjust parameters")
                    .font(.system(size: 14, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.incText))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Donut Chart

struct DonutChart: View {
    struct Wedge {
        let value: Double
        let color: Color
    }
    let wedges: [Wedge]
    let centerLabel: String
    let centerValue: String
    var thickness: CGFloat = 22

    private var total: Double { wedges.reduce(0) { $0 + $1.value } }

    private func wedgeRange(_ index: Int) -> (CGFloat, CGFloat) {
        guard total > 0 else { return (0, 0) }
        let before = wedges.prefix(index).reduce(0) { $0 + $1.value }
        return (CGFloat(before / total), CGFloat((before + wedges[index].value) / total))
    }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            ZStack {
                Circle()
                    .stroke(Color.incHairline, style: StrokeStyle(lineWidth: thickness, lineCap: .butt))
                    .frame(width: size - thickness, height: size - thickness)
                ForEach(Array(wedges.enumerated()), id: \.offset) { idx, w in
                    let range = wedgeRange(idx)
                    Circle()
                        .trim(from: range.0, to: range.1)
                        .stroke(w.color, style: StrokeStyle(lineWidth: thickness, lineCap: .butt))
                        .rotationEffect(.degrees(-90))
                        .frame(width: size - thickness, height: size - thickness)
                }
                VStack(spacing: 4) {
                    Text(centerLabel.uppercased())
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundColor(.incTextMute).kerning(0.6)
                    Text(centerValue)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.incText)
                        .lineLimit(1).minimumScaleFactor(0.6)
                        .kerning(-0.5)
                }
                .frame(maxWidth: size * 0.6)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

// MARK: - Enums

enum PayFrequency: String, CaseIterable {
    case daily, weekly, biweekly, semiMonthly, monthly, quarterly, semiAnnual, annual

    var displayName: String {
        switch self {
        case .daily:        return "Daily"
        case .weekly:       return "Weekly"
        case .biweekly:     return "Bi-weekly"
        case .semiMonthly:  return "Semi-monthly"
        case .monthly:      return "Monthly"
        case .quarterly:    return "Quarterly"
        case .semiAnnual:   return "Semi-annual"
        case .annual:       return "Annual"
        }
    }
    var apiValue: String {
        switch self {
        case .daily:        return "DAILY"
        case .weekly:       return "WEEKLY"
        case .biweekly:     return "BIWEEKLY"
        case .semiMonthly:  return "SEMIMONTHLY"
        case .monthly:      return "MONTHLY"
        case .quarterly:    return "QUARTERLY"
        case .semiAnnual:   return "SEMIANNUAL"
        case .annual:       return "ANNUAL"
        }
    }
    var periodsPerYear: Double {
        switch self {
        case .daily:        return 260
        case .weekly:       return 52
        case .biweekly:     return 26
        case .semiMonthly:  return 24
        case .monthly:      return 12
        case .quarterly:    return 4
        case .semiAnnual:   return 2
        case .annual:       return 1
        }
    }
}

enum FilingStatus: String, CaseIterable {
    case single, marriedJoint, headOfHousehold
    var displayName: String {
        switch self {
        case .single:           return "Single"
        case .marriedJoint:     return "Married Joint"
        case .headOfHousehold:  return "Head of Household"
        }
    }
    var apiValue: String {
        switch self {
        case .single:           return "SINGLE"
        case .marriedJoint:     return "MARRIED"
        case .headOfHousehold:  return "HEAD_OF_HOUSEHOLD"
        }
    }
}

enum CalculatorSection: String, CaseIterable {
    case earnings, federal, state, benefits
    var displayName: String {
        switch self {
        case .earnings: return "Earnings"
        case .federal:  return "Federal"
        case .state:    return "State"
        case .benefits: return "Benefits"
        }
    }
}

enum IncomeType: String, CaseIterable {
    case salary, hourly
    var displayName: String {
        switch self {
        case .salary: return "Salary"
        case .hourly: return "Hourly"
        }
    }
}

enum SalaryBasis: String, CaseIterable {
    case perYear, perPeriod
    var displayName: String {
        switch self {
        case .perYear:   return "Per Year"
        case .perPeriod: return "Per Period"
        }
    }
    var apiValue: String {
        switch self {
        case .perYear:   return "PER_YEAR"
        case .perPeriod: return "PER_PERIOD"
        }
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
