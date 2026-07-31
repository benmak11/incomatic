//
//  GrantFormView.swift
//  incomatic
//
//  Created by Ben Makusha on 07/17/2026
//
//  Add / edit grant form (§C): company search → quote pill (manual-price
//  fallback per §G), grant terms, vesting schedule presets, live vest preview.
//  Ticker search debounced 300ms, results capped at 10 by the backend.
//

import SwiftUI

struct GrantFormView: View {
    @ObservedObject var store: EquityStore
    /// Nil = add mode; non-nil = edit mode, pre-filled.
    let existing: RsuGrant?
    let onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss

    // Company
    @State private var searchQuery: String
    @State private var searchResults: [StockSymbol] = []
    @State private var selectedSymbol: StockSymbol?
    @State private var quote: StockQuote?
    @State private var quoteLoading = false
    @State private var lookupUnavailable = false
    @State private var manualMode: Bool
    @State private var companyName: String
    @State private var manualPriceText: String
    // Grant terms
    @State private var sharesText: String
    @State private var grantDate: Date
    // Schedule
    @State private var preset: VestingPreset
    @State private var customTotalMonths: Int
    @State private var customCliffMonths: Int
    @State private var customFreqMonths: Int

    @State private var saving = false

    init(store: EquityStore, existing: RsuGrant? = nil, onSaved: @escaping () -> Void) {
        self.store = store
        self.existing = existing
        self.onSaved = onSaved
        _searchQuery = State(initialValue: existing?.ticker ?? "")
        _manualMode = State(initialValue: existing?.manualPrice == true)
        _companyName = State(initialValue: existing?.company ?? "")
        _manualPriceText = State(initialValue: existing.map { String($0.pricePerShare) } ?? "")
        _sharesText = State(initialValue: existing.map { formatShares($0.sharesTotal) } ?? "")
        _grantDate = State(initialValue: existing.flatMap { VestMath.parseDate($0.grantDate) } ?? Date())
        let existingPreset = existing?.schedule.presetId.flatMap(VestingPreset.init(rawValue:))
        _preset = State(initialValue: existingPreset ?? (existing != nil ? .custom : .monthly1cliff))
        _customTotalMonths = State(initialValue: existing?.schedule.totalMonths ?? 48)
        _customCliffMonths = State(initialValue: existing?.schedule.cliffMonths ?? 12)
        _customFreqMonths = State(initialValue: existing?.schedule.freqMonths ?? 1)
        if let existing, existing.manualPrice != true, let ticker = existing.ticker {
            _selectedSymbol = State(initialValue: StockSymbol(symbol: ticker, name: existing.company ?? ticker))
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                companyCard
                termsCard
                scheduleCard
                previewCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .background(Color.incBg.ignoresSafeArea())
        .navigationTitle(existing == nil ? "Add grant" : "Edit grant")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { saveButton }
        .task(id: searchQuery) { await runSearch() }
        .keyboardDoneToolbar()
    }

    // ─ Company ───────────────────────────────────────────────

    private var companyCard: some View {
        IncCard {
            VStack(alignment: .leading, spacing: 0) {
                CalculatorFields.cardHeader(icon: "building.2", title: "Company")

                if !manualMode {
                    CalculatorFields.fieldLabel("TICKER OR COMPANY")
                    TextField("Search: AAPL, Apple…", text: $searchQuery)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.incText)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .padding(.bottom, 8)
                        .overlay(Rectangle().fill(Color.incHairline).frame(height: 2), alignment: .bottom)
                        .padding(.bottom, 10)

                    if lookupUnavailable {
                        notice("Stock lookup unavailable. Enter price manually", color: .incBlush)
                    }

                    ForEach(searchResults) { result in
                        Button {
                            select(result)
                        } label: {
                            HStack {
                                Text(result.symbol)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.incText)
                                Text(result.name)
                                    .font(.system(size: 13))
                                    .foregroundColor(.incTextDim)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }

                    if let selected = selectedSymbol {
                        quotePill(selected)
                    }
                } else {
                    CalculatorFields.fieldLabel("COMPANY NAME")
                    TextField("Acme Corp", text: $companyName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.incText)
                        .padding(.bottom, 8)
                        .overlay(Rectangle().fill(Color.incHairline).frame(height: 2), alignment: .bottom)
                        .padding(.bottom, 18)
                    CalculatorFields.amountField(label: "Price per share", text: $manualPriceText)
                }

                CalculatorFields.toggleRow(
                    "Company not listed? Enter price manually",
                    isOn: $manualMode
                )
            }
        }
    }

    private func quotePill(_ symbol: StockSymbol) -> some View {
        HStack(spacing: 8) {
            Text(symbol.symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.incSageDeep)
            if quoteLoading {
                ProgressView().controlSize(.small)
            } else if let quote {
                Text("· \(formatCurrency(quote.price))")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.incSageDeep)
                    .monospacedDigit()
                Text("as of \(formatAsOf(quote.asOf))")
                    .font(.system(size: 11))
                    .foregroundColor(.incTextDim)
            }
            Spacer()
            Button {
                selectedSymbol = nil
                quote = nil
                searchQuery = ""
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 15))
                    .foregroundColor(.incTextMute)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Clear selected company")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.incSageBg))
        .padding(.top, 6)
    }

    // ─ Grant terms ───────────────────────────────────────────

    private var termsCard: some View {
        IncCard {
            VStack(alignment: .leading, spacing: 0) {
                CalculatorFields.cardHeader(icon: "doc.text", title: "Grant terms")

                CalculatorFields.fieldLabel("TOTAL SHARES", suffix: valueCaption)
                TextField("400", text: $sharesText)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.incText)
                    .padding(.bottom, 8)
                    .overlay(Rectangle().fill(Color.incHairline).frame(height: 2), alignment: .bottom)
                    .padding(.bottom, 18)

                CalculatorFields.fieldLabel("GRANT DATE")
                DatePicker("Grant date", selection: $grantDate, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .tint(.incSage)
                    .padding(.bottom, 8)
            }
        }
    }

    private var valueCaption: String? {
        guard let price = currentPrice, let shares = Double(sharesText), shares > 0 else { return nil }
        return "≈ \(formatWholeCurrency(shares * price)) at current price"
    }

    // ─ Vesting schedule ──────────────────────────────────────

    private var scheduleCard: some View {
        IncCard {
            VStack(alignment: .leading, spacing: 0) {
                CalculatorFields.cardHeader(icon: "calendar.badge.clock", title: "Vesting schedule")
                CalculatorFields.styledMenu(label: preset.displayName) {
                    ForEach(VestingPreset.allCases) { p in
                        Button(p.displayName) { preset = p }
                    }
                }
                if preset == .custom {
                    VStack(spacing: 0) {
                        stepperRow("Duration", value: $customTotalMonths, range: 1...120, unit: "months")
                        stepperRow("Cliff", value: $customCliffMonths, range: 0...60, unit: "months")
                        stepperRow("Vest every", value: $customFreqMonths, range: 1...12, unit: "months")
                    }
                    .padding(.top, 12)
                }
            }
        }
    }

    private func stepperRow(_ label: String, value: Binding<Int>, range: ClosedRange<Int>, unit: String) -> some View {
        HStack {
            Text(label).font(.system(size: 14, weight: .medium)).foregroundColor(.incText)
            Spacer()
            Text("\(value.wrappedValue) \(unit)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.incTextDim)
                .monospacedDigit()
            Stepper("", value: value, in: range).labelsHidden()
        }
        .padding(.vertical, 6)
    }

    // ─ Vest preview (§D) ─────────────────────────────────────

    private var previewCard: some View {
        IncCard {
            VStack(alignment: .leading, spacing: 0) {
                CalculatorFields.cardHeader(icon: "chart.bar.doc.horizontal", title: "Vest distribution")
                if let draft = draftGrant {
                    VestTimelineView(grant: draft)
                } else {
                    Text("Set shares, price, and a grant date to preview vesting.")
                        .font(.system(size: 12.5))
                        .foregroundColor(.incTextMute)
                }
            }
        }
    }

    // ─ Save ──────────────────────────────────────────────────

    private var saveButton: some View {
        Button {
            Task { await save() }
        } label: {
            Group {
                if saving {
                    ProgressView().tint(.incBtnSolidText)
                } else {
                    Text(existing == nil ? "Save grant" : "Save changes")
                        .font(.system(size: 15, weight: .bold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(RoundedRectangle(cornerRadius: 14).fill(canSave ? Color.incBtnSolid : Color.incDisabled))
            .foregroundColor(.incBtnSolidText)
        }
        .disabled(!canSave || saving)
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
        .background(Color.incBg.opacity(0.94))
    }

    // ─ Logic ─────────────────────────────────────────────────

    private var currentPrice: Double? {
        if manualMode { return Double(manualPriceText) }
        return quote?.price ?? (existing?.manualPrice != true ? existing?.pricePerShare : nil)
    }

    private var schedule: RsuGrant.VestingSchedule {
        if let terms = preset.terms {
            return RsuGrant.VestingSchedule(
                presetId: preset.rawValue,
                totalMonths: terms.totalMonths,
                cliffMonths: terms.cliffMonths,
                freqMonths: terms.freqMonths
            )
        }
        return RsuGrant.VestingSchedule(
            presetId: VestingPreset.custom.rawValue,
            totalMonths: customTotalMonths,
            cliffMonths: min(customCliffMonths, customTotalMonths),
            freqMonths: customFreqMonths
        )
    }

    private var draftGrant: RsuGrant? {
        guard let shares = Double(sharesText), shares > 0, let price = currentPrice, price > 0 else { return nil }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return RsuGrant(
            id: existing?.id,
            ticker: manualMode ? nil : selectedSymbol?.symbol,
            company: manualMode ? companyName : selectedSymbol?.name,
            manualPrice: manualMode,
            sharesTotal: shares,
            pricePerShare: price,
            grantDate: f.string(from: grantDate),
            schedule: schedule
        )
    }

    private var canSave: Bool {
        guard let draft = draftGrant else { return false }
        let hasCompany = manualMode
            ? !(draft.company ?? "").trimmingCharacters(in: .whitespaces).isEmpty
            : draft.ticker != nil
        return hasCompany
    }

    private func select(_ result: StockSymbol) {
        selectedSymbol = result
        searchResults = []
        searchQuery = result.symbol
        Task { await fetchQuote(result.symbol) }
    }

    private func runSearch() async {
        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !manualMode, query.count >= 2, query != selectedSymbol?.symbol else {
            searchResults = []
            return
        }
        try? await Task.sleep(nanoseconds: 300_000_000)   // debounce
        guard !Task.isCancelled else { return }
        do {
            searchResults = try await store.equityService.searchStocks(query: query)
            lookupUnavailable = false
        } catch EquityService.EquityError.lookupUnavailable {
            lookupUnavailable = true
            manualMode = true   // §G: non-blocking flip to manual entry
        } catch {
            searchResults = []
        }
    }

    private func fetchQuote(_ symbol: String) async {
        quoteLoading = true
        defer { quoteLoading = false }
        do {
            quote = try await store.equityService.quote(symbol: symbol)
            lookupUnavailable = false
        } catch EquityService.EquityError.lookupUnavailable {
            lookupUnavailable = true
            manualMode = true
        } catch {
            quote = nil
        }
    }

    private func save() async {
        guard let draft = draftGrant else { return }
        saving = true
        let ok = await store.save(draft)
        saving = false
        if ok {
            onSaved()
            dismiss()
        }
    }

    private func notice(_ text: String, color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(color)
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.incTextDim)
        }
        .padding(.bottom, 10)
    }

    private func formatAsOf(_ iso: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: iso) else { return "" }
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f.string(from: date)
    }
}
