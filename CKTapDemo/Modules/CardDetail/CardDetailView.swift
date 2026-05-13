import SwiftUI

// MARK: - Factory

struct CardDetailViewFactory {
    /// Module entry point.
    /// Returns a view bound to its own coordinator and viewModel for the given card.
    static func build(card: CardReadResult) -> some View {
        CardDetailEntry(card: card)
    }
}

// MARK: - Entry point (@StateObject owner)

private struct CardDetailEntry: View {
    @StateObject private var coordinator = CardDetailCoordinator()
    @StateObject private var viewModel: CardDetailViewModel

    init(card: CardReadResult) {
        _viewModel = StateObject(wrappedValue: CardDetailViewModel(card: card))
    }

    var body: some View {
        CardDetailView(viewModel: viewModel)
            .environmentObject(coordinator)
    }
}

// MARK: - View

struct CardDetailView<ViewModel: CardDetailViewModelProtocol>: View {

    @ObservedObject var viewModel: ViewModel

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        Form {
            if let info = viewModel.uiState.tapsigner {
                TapsignerDetailSection(info: info)
            }
            if let info = viewModel.uiState.satsCard {
                SatsCardDetailSection(info: info)
            }
            if let info = viewModel.uiState.satsChip {
                SatsChipDetailSection(info: info)
            }
        }
        .navigationTitle(viewModel.uiState.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.uiState.tapsigner != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(TapsignerAction.allCases) { action in
                            Button(action.title) {
                                viewModel.perform(action)
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .accessibilityLabel("Tapsigner actions")
                }
            }
        }
        .alert(
            "Tapsigner PIN",
            isPresented: $viewModel.uiState.isAskingPIN
        ) {
            SecureField("CVC / PIN", text: $viewModel.uiState.pin)
                .textContentType(.password)
                .keyboardType(.numberPad)

            Button("Cancel", role: .cancel) {
                viewModel.cancelXpubPrompt()
            }
            Button("Read") {
                viewModel.confirmXpubScan()
            }
        } message: {
            Text("Enter the Tapsigner CVC to read its XPUB.")
        }
        .alert(
            "XPUB",
            isPresented: Binding(
                get: { viewModel.uiState.fetchedXpub != nil },
                set: { if !$0 { viewModel.dismissXpub() } }
            ),
            presenting: viewModel.uiState.fetchedXpub
        ) { xpub in
            Button("Copy") {
                UIPasteboard.general.string = xpub
                UISelectionFeedbackGenerator().selectionChanged()
            }
            Button("OK", role: .cancel) {
                viewModel.dismissXpub()
            }
        } message: { xpub in
            Text(xpub)
        }
        .alert(
            "Error",
            isPresented: Binding(
                get: { viewModel.uiState.errorMessage != nil },
                set: { if !$0 { viewModel.dismissError() } }
            ),
            presenting: viewModel.uiState.errorMessage
        ) { _ in
            Button("OK") { viewModel.dismissError() }
        } message: { message in
            Text(message)
        }
    }
}

// MARK: - Preview

#Preview("Tapsigner") {
    NavigationStack {
        CardDetailViewFactory.build(card: .tapsigner(
            TapsignerInfo(
                cardIdent: "XDXKQ-2VYUC-A4QLF-NCFVA",
                version: "1.0.4",
                birth: 826_000,
                numBackups: 3,
                path: [2_147_483_732, 2_147_483_648, 2_147_483_648],
                pubkey: "03c2c1a8d3e5f7b9c2e4d6a8b0c2d4e6f8a0b2c4d6e8f0a2c4e6d8a0b2c4d6e8f0",
                authDelay: 0,
                derivedPubkey: "029a8b7c6d5e4f3a2b1c0d9e8f7a6b5c4d3e2f1a0b9c8d7e6f5a4b3c2d1e0f9a8b",
                savedAt: Date()
            )
        ))
    }
}

#Preview("SatsCard") {
    NavigationStack {
        CardDetailViewFactory.build(card: .satsCard(
            SatsCardSavedInfo(
                cardIdent: "XDXKQ-2VYUC-A4QLF-NCFVA",
                version: "1.0.4",
                birth: 826_000,
                activeSlot: 1,
                numSlots: 10,
                pubkey: "03c2c1a8d3e5f7b9c2e4d6a8b0c2d4e6f8a0b2c4d6e8f0a2c4e6d8a0b2c4d6e8f0",
                address: "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh",
                authDelay: nil,
                savedAt: Date()
            )
        ))
    }
}
