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
    enum Operation: Sendable {
        case read
        case initialize
    }

    var isAskingPIN = false
    var pin: String = "612370"
    var pendingOperation: Operation = .read
    var pendingUninitialized: TapsignerInfo?
    var lastResult: CardReadResult?
    var errorMessage: String?
    var isScanning = false

    @ObservationIgnored
    private var session: NFCCardSession?

    var pinAlertTitle: String {
        switch pendingOperation {
        case .read: return "Card PIN"
        case .initialize: return "Initialize Tapsigner"
        }
    }

    var pinAlertMessage: String {
        switch pendingOperation {
        case .read:
            return "Enter the CVC for Tapsigner. Leave empty for SatsCard."
        case .initialize:
            return "Re-enter the Tapsigner CVC. Tapping Scan will initialize the card. This is irreversible."
        }
    }

    var pinAlertConfirm: String {
        switch pendingOperation {
        case .read: return "Scan"
        case .initialize: return "Initialize"
        }
    }

    func startScan() {
        Log.ui.info("User tapped Scan NFC")
        pendingOperation = .read
        pin = ""
        isAskingPIN = true
    }

    /// User answered "No" to the init prompt — keep the partially-read card in the list.
    func saveUninitialized(_ info: TapsignerInfo) {
        Log.ui.info("User declined Tapsigner init; saving uninitialized status")
        pendingUninitialized = nil
        lastResult = .tapsigner(info)
    }

    /// User answered "Yes" — request the CVC again and start a second NFC scan that runs `init`.
    func startInitFlow() {
        Log.ui.info("User accepted Tapsigner init; requesting CVC")
        pendingUninitialized = nil
        pendingOperation = .initialize
        pin = ""
        // Delay slightly so the previous alert can fully dismiss before this one appears.
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            self?.isAskingPIN = true
        }
    }

    func scan() {
        guard NFCTagReaderSession.readingAvailable else {
            Log.nfc.error("NFC reading not available on this device")
            errorMessage = "NFC is not available on this device."
            return
        }

        let cvc = pin
        let operation = pendingOperation
        Log.ui.info(
            "Scan confirmed (operation: \(String(describing: operation), privacy: .public), cvc length: \(cvc.count))"
        )
        isScanning = true

        let session = NFCCardSession(cvc: cvc, operation: operation) { [weak self] outcome in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isScanning = false
                self.session = nil
                self.pendingOperation = .read

                switch outcome {
                case .success(let result):
                    Log.ui.info("Scan success: \(result.title, privacy: .public)")
                    self.lastResult = result
                case .uninitialized(let info):
                    Log.ui.info("Scan returned uninitialized Tapsigner")
                    self.pendingUninitialized = info
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
        case uninitialized(TapsignerInfo)
        case failure(String)
        case cancelled
    }

    private let cvc: String
    private let operation: CardReader.Operation
    private let completion: @Sendable (Outcome) -> Void
    private let service = CkTapCardService()

    private let lock = NSLock()
    private var session: NFCTagReaderSession?
    private var completed = false

    init(
        cvc: String,
        operation: CardReader.Operation,
        completion: @escaping @Sendable (Outcome) -> Void
    ) {
        self.cvc = cvc
        self.operation = operation
        self.completion = completion
    }

    func begin() {
        let configuration = NFCTagReaderSession.Configuration(pollingOption: [.iso14443])
        let session = NFCTagReaderSession(
            configuration: configuration,
            delegate: self,
            queue: nil
        )
        let prompt: String
        switch operation {
        case .read:
            prompt = "Hold your card near the top of your iPhone."
        case .initialize:
            prompt = "Hold the Tapsigner near the top of your iPhone to initialize it."
        }
        session.alertMessage = prompt
        self.session = session
        Log.nfc.info(
            "Starting NFC session (operation: \(String(describing: self.operation), privacy: .public))"
        )
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

        do {
            let result: CardReadResult
            switch operation {
            case .read:
                session.alertMessage = "Reading card…"
                Log.cktap.info("Starting card read")
                result = try await service.readCardInfo(transport: transport, cvc: cvc)
            case .initialize:
                session.alertMessage = "Initializing Tapsigner…"
                Log.cktap.info("Starting Tapsigner initialization")
                result = try await service.initializeTapsigner(transport: transport, cvc: cvc)
            }

            Log.cktap.info("Operation finished: \(result.title, privacy: .public)")
            session.alertMessage = "\(result.title) read"
            session.invalidate()
            finish(.success(result))
        } catch CardReadError.tapsignerNotInitialized(let info) {
            Log.cktap.info("Tapsigner not initialized — surfacing to UI")
            session.alertMessage = "Tapsigner not initialized"
            session.invalidate()
            finish(.uninitialized(info))
        } catch {
            Log.cktap.error("Operation failed: \(error.localizedDescription, privacy: .public)")
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
