import Combine
import Foundation
import os

// MARK: - Action

enum TapsignerAction: String, Identifiable, CaseIterable {
    case signMessage
    case showXpub
    case changePin
    case deriveAtPath

    var id: String { rawValue }

    var title: String {
        switch self {
        case .signMessage:   return String(localized: "Sign message")
        case .showXpub:      return String(localized: "Show XPUB")
        case .changePin:     return String(localized: "Change PIN")
        case .deriveAtPath:  return String(localized: "Derive at path")
        }
    }
}

// MARK: - DerivePathParseError

enum DerivePathParseError: Error {
    case invalidComponent(String)
    case componentTooLarge(String)

    var userMessage: String {
        switch self {
        case .invalidComponent(let raw):
            return String(localized: "Invalid path component: \"\(raw)\". Use digits separated by /.")
        case .componentTooLarge(let raw):
            return String(localized: "Component \"\(raw)\" is too large. Use the unhardened number (e.g. 48, not 0x80000030).")
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

    // Sign message flow
    func confirmSignMessageScan()
    func cancelSignMessagePrompt()
    func dismissSignature()

    // Derive at path flow
    func confirmDeriveScan()
    func cancelDerivePrompt()
    func dismissDerivedPubkey()

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

    // Sign message
    var isAskingSignMessage: Bool = false
    var signMessageText: String = ""
    var signMessagePin: String = ""
    var fetchedSignature: SignedMessage?

    // Derive at path
    var isAskingDerive: Bool = false
    var derivePathInput: String = ""
    var derivePin: String = ""
    var derivedResult: DerivedPubkey?

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
        case .signMessage:
            requestSignMessage()
        case .deriveAtPath:
            requestDerive()
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

    // MARK: - Sign message

    func confirmSignMessageScan() {
        let message = uiState.signMessageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else {
            uiState.errorMessage = String(localized: "Enter a message to sign.")
            return
        }

        guard NFCReaderAvailability.isReadingAvailable else {
            Log.nfc.error("NFC reading not available on this device")
            uiState.errorMessage = "NFC is not available on this device."
            return
        }

        let cvc = uiState.signMessagePin
        Log.ui.info(
            "Sign-message scan confirmed (msg length: \(message.count), cvc length: \(cvc.count))"
        )
        uiState.isScanning = true

        let session = NFCCardSession(
            cvc: cvc,
            operation: .signMessage(message: message)
        ) { [weak self] outcome in
            Task { @MainActor [weak self] in
                self?.handle(outcome)
            }
        }
        self.session = session
        session.begin()
    }

    func cancelSignMessagePrompt() {
        clearSignMessageFields()
    }

    func dismissSignature() {
        uiState.fetchedSignature = nil
    }

    // MARK: - Derive at path

    func confirmDeriveScan() {
        let path: [UInt32]
        do {
            path = try Self.parseDerivationPath(uiState.derivePathInput)
        } catch let error as DerivePathParseError {
            uiState.errorMessage = error.userMessage
            return
        } catch {
            uiState.errorMessage = error.localizedDescription
            return
        }

        guard NFCReaderAvailability.isReadingAvailable else {
            Log.nfc.error("NFC reading not available on this device")
            uiState.errorMessage = "NFC is not available on this device."
            return
        }

        let cvc = uiState.derivePin
        Log.ui.info(
            "Derive scan confirmed (path components: \(path.count), cvc length: \(cvc.count))"
        )
        uiState.isScanning = true

        let session = NFCCardSession(
            cvc: cvc,
            operation: .derive(path: path)
        ) { [weak self] outcome in
            Task { @MainActor [weak self] in
                self?.handle(outcome)
            }
        }
        self.session = session
        session.begin()
    }

    func cancelDerivePrompt() {
        clearDeriveFields()
    }

    func dismissDerivedPubkey() {
        uiState.derivedResult = nil
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

    private func requestSignMessage() {
        clearSignMessageFields()
        uiState.isAskingSignMessage = true
    }

    private func requestDerive() {
        clearDeriveFields()
        // Pre-fill a common multisig path that triggers the bug described in
        // https://github.com/coinkite/coinkite-tap-proto/issues/56 on real cards.
        uiState.derivePathInput = "48/0/0"
        uiState.isAskingDerive = true
    }

    private func clearDeriveFields() {
        uiState.derivePathInput = ""
        uiState.derivePin = ""
    }

    private func clearChangePinFields() {
        uiState.currentPin = ""
        uiState.newPin = ""
        uiState.confirmNewPin = ""
    }

    private func clearSignMessageFields() {
        uiState.signMessageText = ""
        uiState.signMessagePin = ""
    }

    /// Parses a user-typed derivation path like "48/0/0", "m/48/0/0",
    /// "48h/0h/0h" or "48'/0'/0'" into the unhardened components expected by
    /// `tapSigner.derive(path:cvc:)` (rust-cktap applies the hardening bit
    /// internally — see `lib/src/tap_signer.rs:251`).
    ///
    /// An empty input parses to `[]`, which corresponds to deriving the master
    /// key (`m`) — the only path that is known to verify on real cards today
    /// (see https://github.com/coinkite/coinkite-tap-proto/issues/56).
    static func parseDerivationPath(_ input: String) throws -> [UInt32] {
        var trimmed = input.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("m/") { trimmed.removeFirst(2) }
        if trimmed == "m" || trimmed.isEmpty { return [] }

        let components = trimmed.split(whereSeparator: { $0 == "/" || $0 == "," })
        var result: [UInt32] = []
        for raw in components {
            var token = raw.trimmingCharacters(in: .whitespaces)
            guard !token.isEmpty else { continue }
            if token.hasSuffix("h") || token.hasSuffix("H") || token.hasSuffix("'") {
                token.removeLast()
            }
            guard let value = UInt32(token) else {
                throw DerivePathParseError.invalidComponent(String(raw))
            }
            // Hardening bit is applied inside rust-cktap; reject already-hardened input.
            guard value < 0x8000_0000 else {
                throw DerivePathParseError.componentTooLarge(String(raw))
            }
            result.append(value)
        }
        return result
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
        case .signed(let signed):
            Log.ui.info("Message signed (sig len: \(signed.signature.count))")
            clearSignMessageFields()
            uiState.fetchedSignature = signed
        case .derived(let derived):
            Log.ui.info("Derive succeeded (pubkey len: \(derived.pubkey.count))")
            clearDeriveFields()
            uiState.derivedResult = derived
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
