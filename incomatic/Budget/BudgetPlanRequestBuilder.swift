//
//  BudgetPlanRequestBuilder.swift
//  incomatic
//
//  Created by Ben Makusha on 07/24/2026
//
//  Pure function that maps the latest calculation result + RSU grants into a
//  POST /v1/budget/plan request — specifically, the dated `[Windfall]` list
//  and the per-period net income BudgetEngine.buildPlan also consumes
//  directly (same windfalls/netIncomePerPeriod feed both the server AI call
//  and the client-side simulation, so they can never disagree with each
//  other about what money exists and when).
//

import Foundation

func buildBudgetPlanRequest(
    budget: Budget,
    state: CalculatorState,
    result: ViewFriendlyResponse,
    grants: [RsuGrant],
    today: Date = Date(),
    calendar: Calendar = .current
) -> BudgetPlanRequest {
    func isoDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    var windfalls: [Windfall] = []
    var commissionNetPerPeriod = 0.0

    if let supplemental = result.supplemental {
        let totalGross = supplemental.bonusGross + supplemental.commissionGross + supplemental.rsuGross
        if totalGross > 0 {
            // Effective net-of-tax rate the server actually applied to this
            // year's supplemental income (flat federal supplemental rate +
            // FICA stacking) — reused per-source below instead of
            // re-deriving a flat estimate client-side (see
            // project_bonus_card_estimate memory for why that pattern was
            // retired in favor of server-truth figures).
            let netRate = supplemental.net / totalGross

            if supplemental.bonusGross > 0 {
                // Falls back to year-end when the state has no specific
                // date but the backend still included it — mirrors the
                // backend's own "lenient parse falls back to tax year" rule.
                let bonusDate = state.bonusDate
                    ?? calendar.date(from: DateComponents(year: AppConfig.taxYear, month: 12, day: 31))
                    ?? today
                windfalls.append(Windfall(
                    label: "Bonus",
                    netAmount: supplemental.bonusGross * netRate,
                    date: isoDate(bonusDate)
                ))
            }

            // Commission has no discrete payout date in the UI model —
            // spread its net evenly across periods instead of inventing a
            // date for a one-time Windfall entry.
            if supplemental.commissionGross > 0 {
                let commissionNet = supplemental.commissionGross * netRate
                commissionNetPerPeriod = commissionNet / state.payFrequency.periodsPerYear
            }

            // RSU — one windfall per future vest event (not one aggregate
            // lump), proportioned across the server's single aggregate
            // rsuGross/net figure by each event's share of the total future
            // vesting value, since the backend only ever sees one annual
            // rsuVesting number, not per-grant/per-date detail.
            if supplemental.rsuGross > 0 {
                let futureEvents = grants.flatMap { grant in
                    VestMath.vestEvents(for: grant, calendar: calendar)
                        .filter { $0.date > today }
                        .map { (event: $0, grant: grant) }
                }
                let totalFutureGross = futureEvents.reduce(0.0) { $0 + $1.event.shares * $1.grant.pricePerShare }
                if totalFutureGross > 0 {
                    let rsuNet = supplemental.rsuGross * netRate
                    for (event, grant) in futureEvents {
                        let eventGross = event.shares * grant.pricePerShare
                        windfalls.append(Windfall(
                            label: grant.ticker ?? grant.company ?? "RSU vest",
                            netAmount: rsuNet * (eventGross / totalFutureGross),
                            date: isoDate(event.date)
                        ))
                    }
                }
            }
        }
    }

    return BudgetPlanRequest(
        budget: budget,
        payFrequency: state.payFrequency.apiValue,
        netIncomePerPeriod: result.netPay.perPayPeriod + commissionNetPerPeriod,
        windfalls: windfalls
    )
}
