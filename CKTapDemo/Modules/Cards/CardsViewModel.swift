import Combine
import Foundation
import SwiftUI
import os

// MARK: - Protocol

protocol CardsViewModelProtocol: ObservableObject {
    var uiState: CardsUiState { get set }

    func startScan()
    func confirmScan()
    func saveUninitialized(_ info: TapsignerInfo)
    func startInitFlow()
    func dismissUninitializedPrompt()
    func acknowledgeResult()
    func dismissError()
    func removeTapsigner(id: String)
    func removeSatsCard(id: String)
    func removeSatsChip(id: String)
}

// MARK: - UiState

nonisolated struct CardsUiState {
    var tapsigners: [TapsignerInfo] = []
    var satsCards: [SatsCardSavedInfo] = []
    var satsChips: [SatsChipInfo] = []

    var isScanning: Bool = false
    var isAskingPIN: Bool = false
    var pin: String = ""
    var pendingOperation: CardOperation = .read
    var pendingUninitialized: TapsignerInfo?
    var lastResult: CardReadResult?
    var errorMessage: String?

    var isEmpty: Bool {
        tapsigners.isEmpty && satsCards.isEmpty && satsChips.isEmpty
    }

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
}

// MARK: - ViewModel

@MainActor
final class CardsViewModel: CardsViewModelProtocol {
    @Published var uiState: CardsUiState

    private let store: CardStore
    private var session: NFCCardSession?
    private var cancellables = Set<AnyCancellable>()

    init(
        uiState: CardsUiState = .init(),
        store: CardStore? = nil
    ) {
        let store = store ?? CardStore()
        self.store = store
        var initial = uiState
        initial.tapsigners = store.tapsigners
        initial.satsCards = store.satsCards
        initial.satsChips = store.satsChips
        self.uiState = initial

        store.$tapsigners
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.uiState.tapsigners = $0 }
            .store(in: &cancellables)

        store.$satsCards
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.uiState.satsCards = $0 }
            .store(in: &cancellables)

        store.$satsChips
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.uiState.satsChips = $0 }
            .store(in: &cancellables)
    }

    // MARK: - Intents

    func startScan() {
        Log.ui.info("User tapped Scan NFC")
        uiState.pendingOperation = .read
        uiState.pin = ""
        uiState.isAskingPIN = true
    }

    func confirmScan() {
        guard NFCReaderAvailability.isReadingAvailable else {
            Log.nfc.error("NFC reading not available on this device")
            uiState.errorMessage = "NFC is not available on this device."
            return
        }

        let cvc = uiState.pin
        let operation = uiState.pendingOperation
        Log.ui.info(
            "Scan confirmed (operation: \(String(describing: operation), privacy: .public), cvc length: \(cvc.count))"
        )
        uiState.isScanning = true

        let session = NFCCardSession(cvc: cvc, operation: operation) { [weak self] outcome in
            Task { @MainActor [weak self] in
                self?.handle(outcome)
            }
        }
        self.session = session
        session.begin()
    }

    func saveUninitialized(_ info: TapsignerInfo) {
        Log.ui.info("User declined Tapsigner init; saving uninitialized status")
        uiState.pendingUninitialized = nil
        commitResult(.tapsigner(info))
    }

    func startInitFlow() {
        Log.ui.info("User accepted Tapsigner init; requesting CVC")
        uiState.pendingUninitialized = nil
        uiState.pendingOperation = .initialize
        uiState.pin = ""
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            self?.uiState.isAskingPIN = true
        }
    }

    func dismissUninitializedPrompt() {
        uiState.pendingUninitialized = nil
    }

    func acknowledgeResult() {
        uiState.lastResult = nil
    }

    func dismissError() {
        uiState.errorMessage = nil
    }

    func removeTapsigner(id: String) {
        store.removeTapsigner(id: id)
    }

    func removeSatsCard(id: String) {
        store.removeSatsCard(id: id)
    }

    func removeSatsChip(id: String) {
        store.removeSatsChip(id: id)
    }

    // MARK: - Private

    private func handle(_ outcome: NFCCardSession.Outcome) {
        uiState.isScanning = false
        session = nil
        uiState.pendingOperation = .read

        switch outcome {
        case .success(let result):
            Log.ui.info("Scan success: \(result.title, privacy: .public)")
            commitResult(result)
        case .uninitialized(let info):
            Log.ui.info("Scan returned uninitialized Tapsigner")
            uiState.pendingUninitialized = info
        case .failure(let message):
            Log.ui.error("Scan failure: \(message, privacy: .public)")
            uiState.errorMessage = message
        case .cancelled:
            Log.ui.info("Scan cancelled by user")
        }
    }

    private func commitResult(_ result: CardReadResult) {
        uiState.lastResult = result
        store.save(result)
    }
}

// MARK: - NFC availability shim

/// Wraps `NFCTagReaderSession.readingAvailable` so the view-model doesn't import CoreNFC.
private enum NFCReaderAvailability {
    static var isReadingAvailable: Bool {
        #if canImport(CoreNFC)
        return _CoreNFCAvailability.isReadingAvailable
        #else
        return false
        #endif
    }
}

#if canImport(CoreNFC)
import CoreNFC

private enum _CoreNFCAvailability {
    static var isReadingAvailable: Bool { NFCTagReaderSession.readingAvailable }
}
#endif
