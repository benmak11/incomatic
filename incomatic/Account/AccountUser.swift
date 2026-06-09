//
//  AccountUser.swift
//  incomatic
//
//
//  Created by Ben Makusha on 06/09/2026
//
//  Account profile mirror of the backend's AppleSignInResponse.user.
//

import Foundation

struct AccountUser: Codable, Equatable {
    let id: String
    let displayName: String?

    var initials: String {
        guard let name = displayName, !name.isEmpty else { return "?" }
        let parts = name.split(separator: " ", omittingEmptySubsequences: true).prefix(2)
        let letters = parts.compactMap { $0.first.map(String.init) }.joined()
        return letters.isEmpty ? "?" : letters.uppercased()
    }
}
