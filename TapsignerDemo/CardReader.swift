//
//  CardReader.swift
//  TapsignerDemo
//

import CKTap
@preconcurrency import CoreNFC
import Foundation
import Observation
import os

@Observable
@MainActor
final class CardReader {
    var isAskingPIN = false
    var pin: String = "612370"
    var lastResult: CardReadResult?
    var errorMessage: String?
    var isScanning = false

    @ObservationIgnored
    private var session: NFCCardSession?

    func startScan() {
        Log.ui.info("User tapped Scan NFC")
        pin = ""
        isAskingPIN = true
    }

    func scan() {
        guard NFCTagReaderSession.readingAvailable else {
            Log.nfc.error("NFC reading not available on this device")
            errorMessage = "NFC is not available on this device."
            return
        }

        Log.ui.info("Scan confirmed (cvc length: \(self.pin.count))")
        let cvc = pin
        isScanning = true

        let session = NFCCardSession(cvc: cvc) { [weak self] outcome in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isScanning = false
                self.session = nil
                switch outcome {
                case .success(let result):
                    Log.ui.info("Scan success: \(result.title, privacy: .public)")
                    self.lastResult = result
                case .failure(let message):
                    Log.ui.error("Scan failure: \(message, privacy: .public)")
                    self.errorMessage = message
                case .cancelled:
                    Log.ui.info("Scan cancelled by user")
                }
            }
        }
        self.session = session
        session.begin()
    }
}

// MARK: - NFCCardSession (non-isolated NFC driver)

nonisolated final class NFCCardSession:
    NSObject,
    NFCTagReaderSessionDelegate,
    @unchecked Sendable
{
    enum Outcome: Sendable {
        case success(CardReadResult)
        case failure(String)
        case cancelled
    }

    private let cvc: String
    private let completion: @Sendable (Outcome) -> Void
    private let service = CkTapCardService()

    private let lock = NSLock()
    private var session: NFCTagReaderSession?
    private var completed = false

    init(cvc: String, completion: @escaping @Sendable (Outcome) -> Void) {
        self.cvc = cvc
        self.completion = completion
    }

    func begin() {
        let configuration = NFCTagReaderSession.Configuration(pollingOption: [.iso14443])
        let session = NFCTagReaderSession(
            configuration: configuration,
            delegate: self,
            queue: nil
        )
        session.alertMessage = "Hold your card near the top of your iPhone."
        self.session = session
        Log.nfc.info("Starting NFC session (pollingOption: iso14443)")
        session.begin()
    }

    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        Log.nfc.info("NFC session became active")
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Swift.Error)
    {
        guard self.session === session else {
            Log.nfc.debug("Ignoring stale NFC invalidation")
            return
        }
        self.session = nil

        if let nfcError = error as? NFCReaderError,
            nfcError.code == .readerSessionInvalidationErrorUserCanceled
        {
            Log.nfc.info("Session invalidated: user canceled")
            finish(.cancelled)
            return
        }

        Log.nfc.error("Session invalidated: \(error.localizedDescription, privacy: .public)")
        finish(.failure(error.localizedDescription))
    }

    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        Log.nfc.info("Tag(s) detected: count=\(tags.count)")
        guard let firstTag = tags.first else {
            Log.nfc.error("No tag in detection callback")
            session.invalidate(errorMessage: "No tag detected.")
            return
        }

        Log.nfc.debug("Connecting to first tag…")
        session.connect(to: firstTag) { [weak self] error in
            guard let self else { return }
            if let error {
                Log.nfc.error("Tag connect error: \(error.localizedDescription, privacy: .public)")
                session.invalidate(
                    errorMessage: "Connection failed: \(error.localizedDescription)"
                )
                return
            }
            guard case .iso7816(let iso7816Tag) = firstTag else {
                Log.nfc.error("Tag is not ISO7816 compatible")
                session.invalidate(errorMessage: "Unsupported tag type.")
                return
            }

            Log.nfc.info("Connected to ISO7816 tag")
            Task {
                await self.process(session: session, tag: iso7816Tag)
            }
        }
    }

    private func process(session: NFCTagReaderSession, tag: NFCISO7816Tag) async {
        let transport = NFCTransport(tag: tag)
        session.alertMessage = "Reading card…"
        Log.cktap.info("Starting card read")

        do {
            let result = try await service.readCardInfo(transport: transport, cvc: cvc)
            Log.cktap.info("Card read finished: \(result.title, privacy: .public)")
            session.alertMessage = "\(result.title) read"
            session.invalidate()
            finish(.success(result))
        } catch {
            Log.cktap.error("Card read failed: \(error.localizedDescription, privacy: .public)")
            session.invalidate(errorMessage: error.localizedDescription)
            finish(.failure(error.localizedDescription))
        }
    }

    private func finish(_ outcome: Outcome) {
        lock.lock()
        let alreadyDone = completed
        completed = true
        lock.unlock()
        guard !alreadyDone else { return }
        completion(outcome)
    }
}
