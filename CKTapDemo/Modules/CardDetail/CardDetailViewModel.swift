import Combine
import Foundation
import os

// MARK: - Action

enum TapsignerAction: String, Identifiable, CaseIterable {
    case showXpub
    case changePin

    var id: String { rawValue }

    var title: String {
        switch self {
        case .showXpub:  return String(localized: "Show XPUB")
        case .changePin: return String(localized: "Change PIN")
        }
    }
}

// MARK: - Protocol

protocol CardDetailViewModelProtocol: ObservableObject {
    var uiState: CardDetailUiState { get set }

    func perform(_ action: TapsignerAction)

    // XPUB flow
    func confirmXpubScan()
    func cancelXpubPrompt()
    func dismissXpub()

    // Change PIN flow
    func confirmChangePinScan()
    func cancelChangePinPrompt()
    func dismissChangePinSuccess()

    func dismissError()
}

// MARK: - UiState

nonisolated struct CardDetailUiState {
    let card: CardReadResult

    // Shared
    var isScanning: Bool = false
    var errorMessage: String?

    // XPUB
    var pin: String = ""
    var isAskingPIN: Bool = false
    var fetchedXpub: String?

    // Change PIN
    var isAskingChangePin: Bool = false
    var currentPin: String = ""
    var newPin: String = ""
    var confirmNewPin: String = ""
    var pinChangeSucceeded: Bool = false

    var title: String { card.title }

    var tapsigner: TapsignerInfo? {
        if case .tapsigner(let info) = card { return info }
        return nil
    }

    var satsCard: SatsCardSavedInfo? {
        if case .satsCard(let info) = card { return info }
        return nil
    }

    var satsChip: SatsChipInfo? {
        if case .satsChip(let info) = card { return info }
        return nil
    }
}

// MARK: - ViewModel

@MainActor
final class CardDetailViewModel: CardDetailViewModelProtocol {
    @Published var uiState: CardDetailUiState

    private var session: NFCCardSession?

    /// Minimum CVC/PIN length accepted by `rust-cktap`'s `change` command.
    static let minimumPinLength = 6

    init(card: CardReadResult) {
        self.uiState = CardDetailUiState(card: card)
    }

    // MARK: - Intents

    func perform(_ action: TapsignerAction) {
        Log.ui.info("Tapsigner action selected: \(action.rawValue, privacy: .public)")
        switch action {
        case .showXpub:
            requestShowXpub()
        case .changePin:
            requestChangePin()
        }
    }

    // MARK: - XPUB

    func confirmXpubScan() {
        guard NFCReaderAvailability.isReadingAvailable else {
            Log.nfc.error("NFC reading not available on this device")
            uiState.errorMessage = "NFC is not available on this device."
            return
        }

        let cvc = uiState.pin
        Log.ui.info("XPUB scan confirmed (cvc length: \(cvc.count))")
        uiState.isScanning = true

        let session = NFCCardSession(
            cvc: cvc,
            operation: .fetchXpub(master: false)
        ) { [weak self] outcome in
            Task { @MainActor [weak self] in
                self?.handle(outcome)
            }
        }
        self.session = session
        session.begin()
    }

    func cancelXpubPrompt() {
        uiState.pin = ""
    }

    func dismissXpub() {
        uiState.fetchedXpub = nil
    }

    // MARK: - Change PIN

    func confirmChangePinScan() {
        if let validation = validateChangePin() {
            uiState.errorMessage = validation
            return
        }

        guard NFCReaderAvailability.isReadingAvailable else {
            Log.nfc.error("NFC reading not available on this device")
            uiState.errorMessage = "NFC is not available on this device."
            return
        }

        let currentCvc = uiState.currentPin
        let newCvc = uiState.newPin
        Log.ui.info(
            "Change PIN scan confirmed (current length: \(currentCvc.count), new length: \(newCvc.count))"
        )
        uiState.isScanning = true

        let session = NFCCardSession(
            cvc: currentCvc,
            operation: .changePin(newCvc: newCvc)
        ) { [weak self] outcome in
            Task { @MainActor [weak self] in
                self?.handle(outcome)
            }
        }
        self.session = session
        session.begin()
    }

    func cancelChangePinPrompt() {
        clearChangePinFields()
    }

    func dismissChangePinSuccess() {
        uiState.pinChangeSucceeded = false
    }

    // MARK: - Error

    func dismissError() {
        uiState.errorMessage = nil
    }

    // MARK: - Private

    private func requestShowXpub() {
        uiState.pin = ""
        uiState.isAskingPIN = true
    }

    private func requestChangePin() {
        clearChangePinFields()
        uiState.isAskingChangePin = true
    }

    private func clearChangePinFields() {
        uiState.currentPin = ""
        uiState.newPin = ""
        uiState.confirmNewPin = ""
    }

    private func validateChangePin() -> String? {
        if uiState.currentPin.isEmpty {
            return String(localized: "Enter your current PIN.")
        }
        if uiState.newPin.count < Self.minimumPinLength {
            return String(localized: "New PIN must be at least \(Self.minimumPinLength) characters.")
        }
        if uiState.newPin != uiState.confirmNewPin {
            return String(localized: "New PINs don't match.")
        }
        if uiState.newPin == uiState.currentPin {
            return String(localized: "New PIN must be different from the current one.")
        }
        return nil
    }

    private func handle(_ outcome: NFCCardSession.Outcome) {
        uiState.isScanning = false
        session = nil

        switch outcome {
        case .xpub(let xpub):
            Log.ui.info("XPUB received (len: \(xpub.count))")
            uiState.fetchedXpub = xpub
        case .pinChanged:
            Log.ui.info("PIN change succeeded")
            clearChangePinFields()
            uiState.pinChangeSucceeded = true
        case .failure(let message):
            Log.ui.error("Tapsigner action failure: \(message, privacy: .public)")
            uiState.errorMessage = message
        case .cancelled:
            Log.ui.info("Tapsigner action cancelled by user")
        case .success, .uninitialized:
            Log.ui.info("Unexpected outcome in card-detail flow")
        }
    }
}
