//
//
//  CurrencyFormatting.swift
//  incomatic
//
//  Created by Ben Makusha on 05/28/2026
//

import Foundation

func formatCurrency(_ amount: Double) -> String {
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.currencyCode = "USD"
    return f.string(from: NSNumber(value: amount)) ?? "$\(amount)"
}

func formatSigned(_ amount: Double) -> String {
    if amount < 0 { return "−" + formatCurrency(-amount) }
    return formatCurrency(amount)
}
