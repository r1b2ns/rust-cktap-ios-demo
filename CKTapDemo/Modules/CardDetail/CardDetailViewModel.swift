import Combine
import Foundation
import os

// MARK: - Action

enum TapsignerAction: String, Identifiable, CaseIterable {
    case signMessage
    case showXpub
    case changePin
    case backupKey

    var id: String { rawValue }

    var title: String {
        switch self {
        case .signMessage: return String(localized: "Sign message")
        case .showXpub:    return String(localized: "Show XPUB")
        case .changePin:   return String(localized: "Change PIN")
        case .backupKey:   return String(localized: "Back up key")
        }
    }
}

// MARK: - Protocol

protocol CardDetailViewModelProtocol: ObservableObject {
    var uiState: CardDetailUiState { get set }

    func perform(_ action: TapsignerAction)
    func confirmXpubScan()
    func cancelXpubPrompt()
    func dismissXpub()
    func dismissError()
}

// MARK: - UiState

nonisolated struct CardDetailUiState {
    let card: CardReadResult

    var pin: String = ""
    var isAskingPIN: Bool = false
    var isScanning: Bool = false
    var fetchedXpub: String?
    var errorMessage: String?

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

    init(card: CardReadResult) {
        self.uiState = CardDetailUiState(card: card)
    }

    // MARK: - Intents

    func perform(_ action: TapsignerAction) {
        Log.ui.info("Tapsigner action selected: \(action.rawValue, privacy: .public)")
        switch action {
        case .showXpub:
            requestShowXpub()
        case .signMessage, .changePin, .backupKey:
            // Implementations land here as features are built.
            break
        }
    }

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

    func dismissError() {
        uiState.errorMessage = nil
    }

    // MARK: - Private

    private func requestShowXpub() {
        uiState.pin = ""
        uiState.isAskingPIN = true
    }

    private func handle(_ outcome: NFCCardSession.Outcome) {
        uiState.isScanning = false
        session = nil

        switch outcome {
        case .xpub(let xpub):
            Log.ui.info("XPUB received (len: \(xpub.count))")
            uiState.fetchedXpub = xpub
        case .failure(let message):
            Log.ui.error("XPUB scan failure: \(message, privacy: .public)")
            uiState.errorMessage = message
        case .cancelled:
            Log.ui.info("XPUB scan cancelled by user")
        case .success, .uninitialized:
            Log.ui.info("Unexpected outcome in XPUB flow")
        }
    }
}
