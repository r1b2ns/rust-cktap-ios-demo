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

    /// Runs the `init` (a.k.a. `new`) command on a TAPSIGNER and then reads the resulting state.
    /// Required before `read`, `xpub`, `sign`, etc. can be used on a brand new card.
    func initializeTapsigner(transport: CkTransport, cvc: String) async throws -> CardReadResult {
        Log.cktap.debug("toCktap: calling SELECT (init flow)…")
        let card = try await toCktap(transport: transport)
        guard case .tapSigner(let tapSigner) = card else {
            Log.cktap.error("Initialize requested but card is not a Tapsigner")
            throw CkTapError.UnknownCardType
        }

        Log.cktap.info("Initializing Tapsigner (this is irreversible)…")
        try await tapSigner.`init`(cvc: cvc)
        Log.cktap.info("Tapsigner init succeeded; reading full state…")

        return .tapsigner(try await readTapsigner(tapSigner, cvc: cvc))
    }

    /// Replaces the Tapsigner CVC/PIN. `newCvc` must be at least 6 characters
    /// (enforced upstream by `rust-cktap`).
    func changeTapsignerPin(
        transport: CkTransport,
        newCvc: String,
        cvc: String
    ) async throws {
        Log.cktap.debug("toCktap: calling SELECT (change flow)…")
        let card = try await toCktap(transport: transport)
        guard case .tapSigner(let tapSigner) = card else {
            Log.cktap.error("change requested but card is not a Tapsigner")
            throw CkTapError.UnknownCardType
        }
        try await tapSigner.change(newCvc: newCvc, cvc: cvc)
    }

    /// Signs an arbitrary text message using BIP-137 ("Bitcoin Signed Message")
    /// digest format.
    ///
    /// The Tapsigner FFI doesn't expose the raw `signDigest` command yet —
    /// tracked upstream as https://github.com/bitcoindevkit/rust-cktap/issues/70.
    /// Once it lands, replace the `throw` with the real call.
    func signTapsignerMessage(
        transport: CkTransport,
        message: String,
        cvc: String
    ) async throws -> SignedMessage {
        Log.cktap.debug("toCktap: calling SELECT (sign-message flow)…")
        let card = try await toCktap(transport: transport)
        guard case .tapSigner(let tapSigner) = card else {
            Log.cktap.error("sign-message requested but card is not a Tapsigner")
            throw CkTapError.UnknownCardType
        }

        // Compute the BIP-137 digest now so the implementation stays close to
        // the call site that will eventually use it.
        let digest = BitcoinMessage.digest(message)
        Log.cktap.debug("BIP-137 digest computed (\(digest.count) bytes)")

        // TODO(rust-cktap#70): replace this throw with the real signing call:
        //
        //     let result = try await tapSigner.signDigest(
        //         digest: digest,
        //         subPath: [],
        //         cvc: cvc
        //     )
        //     return SignedMessage(
        //         message: message,
        //         signature: result.signature.base64EncodedString()
        //     )
        _ = tapSigner
        _ = cvc
        throw MessageSigningError.notImplemented
    }

    /// Returns the Tapsigner's BIP-32 xpub at either the master level or the
    /// currently-selected derivation path.
    func fetchTapsignerXpub(
        transport: CkTransport,
        master: Bool,
        cvc: String
    ) async throws -> String {
        Log.cktap.debug("toCktap: calling SELECT (xpub flow)…")
        let card = try await toCktap(transport: transport)
        guard case .tapSigner(let tapSigner) = card else {
            Log.cktap.error("xpub requested but card is not a Tapsigner")
            throw CkTapError.UnknownCardType
        }
        return try await tapSigner.xpub(master: master, cvc: cvc)
    }

    // MARK: - Tapsigner

    private func readTapsigner(_ card: TapSigner, cvc: String) async throws -> TapsignerInfo {
        Log.cktap.debug("Tapsigner: fetching status…")
        let status = await card.status()
        Log.cktap.info(
            "Tapsigner status: ver=\(status.ver, privacy: .public) ident=\(status.cardIdent, privacy: .public) backups=\(status.numBackups, privacy: .public) authDelay=\(status.authDelay ?? 0) hasPath=\(status.path?.isEmpty == false)"
        )

        let baseInfo = TapsignerInfo(
            cardIdent: status.cardIdent,
            version: status.ver,
            birth: status.birth,
            numBackups: status.numBackups,
            path: status.path,
            pubkey: status.pubkey,
            authDelay: status.authDelay,
            derivedPubkey: nil,
            savedAt: Date()
        )

        // Brand new TAPSIGNER: no master key picked yet. `read(cvc:)` will fail with
        // CardError.InvalidState (406). Surface this so the UI can offer to init.
        if !baseInfo.isInitialized {
            Log.cktap.info("Tapsigner is uninitialized (status.path is empty/nil)")
            throw CardReadError.tapsignerNotInitialized(baseInfo)
        }

        guard !cvc.isEmpty else {
            Log.cktap.info("Tapsigner: no CVC supplied, skipping read()")
            return baseInfo
        }

        Log.cktap.debug("Tapsigner: calling read(cvc:)…")
        do {
            let derived = try await card.read(cvc: cvc)
            Log.cktap.info("Tapsigner: derived pubkey received")
            return TapsignerInfo(
                cardIdent: baseInfo.cardIdent,
                version: baseInfo.version,
                birth: baseInfo.birth,
                numBackups: baseInfo.numBackups,
                path: baseInfo.path,
                pubkey: baseInfo.pubkey,
                authDelay: baseInfo.authDelay,
                derivedPubkey: derived,
                savedAt: baseInfo.savedAt
            )
        } catch let error as ReadError {
            // Defensive: in case the status check above didn't catch the uninitialized state
            // (e.g. firmware quirk), translate InvalidState into the typed marker.
            if case .CkTap(let inner) = error,
                case .Card(let cardErr) = inner,
                case .InvalidState = cardErr
            {
                Log.cktap.info("Tapsigner read returned InvalidState; treating as uninitialized")
                throw CardReadError.tapsignerNotInitialized(baseInfo)
            }
            throw error
        }
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
