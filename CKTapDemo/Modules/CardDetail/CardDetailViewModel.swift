import Combine
import Foundation
import os

// MARK: - Action

enum TapsignerAction: String, Identifiable, CaseIterable {
    case signMessage
    case topUpXpubs
    case changePin
    case backupKey

    var id: String { rawValue }

    var title: String {
        switch self {
        case .signMessage: return String(localized: "Sign message")
        case .topUpXpubs:  return String(localized: "Top up XPUBs")
        case .changePin:   return String(localized: "Change PIN")
        case .backupKey:   return String(localized: "Back up key")
        }
    }
}

// MARK: - Protocol

protocol CardDetailViewModelProtocol: ObservableObject {
    var uiState: CardDetailUiState { get set }

    func presentActions()
    func dismissActions()
    func perform(_ action: TapsignerAction)
}

// MARK: - UiState

nonisolated struct CardDetailUiState {
    let card: CardReadResult
    var isActionsPresented: Bool = false

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

    init(card: CardReadResult) {
        self.uiState = CardDetailUiState(card: card)
    }

    // MARK: - Intents

    func presentActions() {
        uiState.isActionsPresented = true
    }

    func dismissActions() {
        uiState.isActionsPresented = false
    }

    func perform(_ action: TapsignerAction) {
        Log.ui.info("Tapsigner action selected: \(action.rawValue, privacy: .public)")
        // Implementations land here as features are built.
        switch action {
        case .signMessage:
            break
        case .topUpXpubs:
            break
        case .changePin:
            break
        case .backupKey:
            break
        }
    }
}
