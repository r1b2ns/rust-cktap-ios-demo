//
//  CkTapCardService.swift
//  TapsignerDemo
//

import CKTap
import Foundation
import os

nonisolated final class CkTapCardService: Sendable {

    func readCardInfo(transport: CkTransport, cvc: String) async throws -> CardReadResult {
        Log.cktap.debug("toCktap: calling SELECT…")
        let card = try await toCktap(transport: transport)
        switch card {
        case .tapSigner(let tapSigner):
            Log.cktap.info("Card identified as Tapsigner")
            return .tapsigner(try await readTapsigner(tapSigner, cvc: cvc))
        case .satsCard(let satsCard):
            Log.cktap.info("Card identified as SatsCard")
            return .satsCard(try await readSatsCard(satsCard))
        case .satsChip(let satsChip):
            Log.cktap.info("Card identified as SatsChip")
            return .satsChip(try await readSatsChip(satsChip))
        }
    }

    // MARK: - Tapsigner

    private func readTapsigner(_ card: TapSigner, cvc: String) async throws -> TapsignerInfo {
        Log.cktap.debug("Tapsigner: fetching status…")
        let status = await card.status()
        Log.cktap.info(
            "Tapsigner status: ver=\(status.ver, privacy: .public) ident=\(status.cardIdent, privacy: .public) backups=\(status.numBackups, privacy: .public) authDelay=\(status.authDelay ?? 0)"
        )

        var derived: String?
        if !cvc.isEmpty {
            Log.cktap.debug("Tapsigner: calling read(cvc:)…")
            derived = try await card.read(cvc: cvc)
            Log.cktap.info("Tapsigner: derived pubkey received")
        } else {
            Log.cktap.info("Tapsigner: no CVC supplied, skipping read()")
        }

        return TapsignerInfo(
            cardIdent: status.cardIdent,
            version: status.ver,
            birth: status.birth,
            numBackups: status.numBackups,
            path: status.path,
            pubkey: status.pubkey,
            authDelay: status.authDelay,
            derivedPubkey: derived,
            savedAt: Date()
        )
    }

    // MARK: - SatsCard

    private func readSatsCard(_ card: SatsCard) async throws -> SatsCardSavedInfo {
        Log.cktap.debug("SatsCard: fetching status…")
        let status = await card.status()
        Log.cktap.info(
            "SatsCard status: ver=\(status.ver, privacy: .public) ident=\(status.cardIdent, privacy: .public) activeSlot=\(status.activeSlot)/\(status.numSlots)"
        )

        Log.cktap.debug("SatsCard: calling address()…")
        var address: String? = status.addr
        do {
            address = try await card.address()
            Log.cktap.info("SatsCard: address() returned")
        } catch {
            Log.cktap.error(
                "SatsCard address() failed: \(error.localizedDescription, privacy: .public)"
            )
        }

        return SatsCardSavedInfo(
            cardIdent: status.cardIdent,
            version: status.ver,
            birth: status.birth,
            activeSlot: status.activeSlot,
            numSlots: status.numSlots,
            pubkey: status.pubkey,
            address: address,
            authDelay: status.authDelay,
            savedAt: Date()
        )
    }

    // MARK: - SatsChip

    private func readSatsChip(_ card: SatsChip) async throws -> SatsChipInfo {
        Log.cktap.debug("SatsChip: fetching status…")
        let status = await card.status()
        Log.cktap.info(
            "SatsChip status: ver=\(status.ver, privacy: .public) ident=\(status.cardIdent, privacy: .public)"
        )

        return SatsChipInfo(
            cardIdent: status.cardIdent,
            version: status.ver,
            birth: status.birth,
            pubkey: status.pubkey,
            path: status.path,
            savedAt: Date()
        )
    }
}
