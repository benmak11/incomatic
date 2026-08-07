//
//
//  CalculatorEnums.swift
//  incomatic
//
//  Created by Ben Makusha on 05/28/2026
//
//  Enums + small data types shared by Calculator screens.
//

import Foundation

enum PayFrequency: String, CaseIterable, Codable {
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

enum FilingStatus: String, CaseIterable, Codable {
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

enum IncomeType: String, CaseIterable, Codable {
    case salary, hourly
    var displayName: String {
        switch self {
        case .salary: return "Salary"
        case .hourly: return "Hourly"
        }
    }
}

enum SalaryBasis: String, CaseIterable, Codable {
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

struct CustomDeduction: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String = ""
    var amount: String = ""
}
