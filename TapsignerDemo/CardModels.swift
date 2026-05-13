//
//  CardModels.swift
//  TapsignerDemo
//

import Foundation

nonisolated struct TapsignerInfo: Codable, Identifiable, Hashable, Sendable {
    var id: String { cardIdent }
    let cardIdent: String
    let version: String
    let birth: UInt32
    let numBackups: UInt32
    let path: [UInt32]?
    let pubkey: String
    let authDelay: UInt8?
    let derivedPubkey: String?
    let savedAt: Date
}

nonisolated struct SatsCardSavedInfo: Codable, Identifiable, Hashable, Sendable {
    var id: String { cardIdent }
    let cardIdent: String
    let version: String
    let birth: UInt32
    let activeSlot: UInt8
    let numSlots: UInt8
    let pubkey: String
    let address: String?
    let authDelay: UInt8?
    let savedAt: Date
}

nonisolated struct SatsChipInfo: Codable, Identifiable, Hashable, Sendable {
    var id: String { cardIdent }
    let cardIdent: String
    let version: String
    let birth: UInt32
    let pubkey: String
    let path: [UInt32]?
    let savedAt: Date
}

nonisolated enum CardReadResult: Sendable, Hashable {
    case tapsigner(TapsignerInfo)
    case satsCard(SatsCardSavedInfo)
    case satsChip(SatsChipInfo)

    var title: String {
        switch self {
        case .tapsigner: return "Tapsigner"
        case .satsCard: return "SatsCard"
        case .satsChip: return "SatsChip"
        }
    }

    var displayText: String {
        switch self {
        case .tapsigner(let info): return info.displayText
        case .satsCard(let info): return info.displayText
        case .satsChip(let info): return info.displayText
        }
    }
}

extension TapsignerInfo {
    var displayText: String {
        var lines: [String] = []
        lines.append("Card Ident: \(cardIdent)")
        lines.append("Version: \(version)")
        lines.append("Birth: \(birth)")
        lines.append("Backups: \(numBackups)")
        if let path, !path.isEmpty {
            lines.append("Path: m/\(path.map(String.init).joined(separator: "/"))")
        } else {
            lines.append("Path: (uninitialized)")
        }
        lines.append("Card Pubkey: \(pubkey)")
        if let delay = authDelay, delay > 0 {
            lines.append("Auth Delay: \(delay)s")
        }
        if let derivedPubkey {
            lines.append("")
            lines.append("Derived Pubkey: \(derivedPubkey)")
        }
        return lines.joined(separator: "\n")
    }
}

extension SatsCardSavedInfo {
    var displayText: String {
        var lines: [String] = []
        lines.append("Card Ident: \(cardIdent)")
        lines.append("Version: \(version)")
        lines.append("Birth: \(birth)")
        lines.append("Active Slot: \(activeSlot) of \(numSlots)")
        lines.append("Card Pubkey: \(pubkey)")
        if let delay = authDelay, delay > 0 {
            lines.append("Auth Delay: \(delay)s")
        }
        if let address {
            lines.append("Active Address: \(address)")
        }
        return lines.joined(separator: "\n")
    }
}

extension SatsChipInfo {
    var displayText: String {
        var lines: [String] = []
        lines.append("Card Ident: \(cardIdent)")
        lines.append("Version: \(version)")
        lines.append("Birth: \(birth)")
        lines.append("Card Pubkey: \(pubkey)")
        if let path, !path.isEmpty {
            lines.append("Path: m/\(path.map(String.init).joined(separator: "/"))")
        }
        return lines.joined(separator: "\n")
    }
}
