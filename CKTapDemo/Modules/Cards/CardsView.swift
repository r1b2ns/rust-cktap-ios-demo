import SwiftUI

// MARK: - Factory

struct CardsViewFactory {
    /// Module entry point.
    /// Returns a view that internally manages the lifecycle of the coordinator and viewModel.
    static func build() -> some View {
        CardsEntry()
    }
}

// MARK: - Entry point (@StateObject owner)

/// Private view that holds the lifecycle of `coordinator` and `viewModel`,
/// ensuring both survive re-renders from the parent.
private struct CardsEntry: View {
    @StateObject private var coordinator = CardsCoordinator()
    @StateObject private var viewModel = CardsViewModel()

    var body: some View {
        CardsView(viewModel: viewModel)
            .environmentObject(coordinator)
    }
}

// MARK: - View

struct CardsView<ViewModel: CardsViewModelProtocol>: View {

    @ObservedObject var viewModel: ViewModel
    @EnvironmentObject private var coordinator: CardsCoordinator

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            rootContent
                .navigationDestinations()
        }
        .alert(
            viewModel.uiState.pinAlertTitle,
            isPresented: $viewModel.uiState.isAskingPIN
        ) {
            SecureField("CVC / PIN", text: $viewModel.uiState.pin)
                .textContentType(.password)
                .keyboardType(.numberPad)

            Button("Cancel", role: .cancel) {}
            Button(viewModel.uiState.pinAlertConfirm) {
                viewModel.confirmScan()
            }
        } message: {
            Text(viewModel.uiState.pinAlertMessage)
        }
        .alert(
            "Tapsigner not initialized",
            isPresented: Binding(
                get: { viewModel.uiState.pendingUninitialized != nil },
                set: { if !$0 { viewModel.dismissUninitializedPrompt() } }
            ),
            presenting: viewModel.uiState.pendingUninitialized
        ) { info in
            Button("No", role: .cancel) {
                viewModel.saveUninitialized(info)
            }
            Button("Yes") {
                viewModel.startInitFlow()
            }
        } message: { _ in
            Text("Do you want to init now?")
        }
        .alert(
            viewModel.uiState.lastResult?.title ?? "Card",
            isPresented: Binding(
                get: { viewModel.uiState.lastResult != nil },
                set: { if !$0 { viewModel.acknowledgeResult() } }
            ),
            presenting: viewModel.uiState.lastResult
        ) { _ in
            Button("OK") { viewModel.acknowledgeResult() }
        } message: { result in
            Text(result.displayText)
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

    @ViewBuilder
    private var rootContent: some View {
        if viewModel.uiState.isEmpty {
            EmptyStateView(
                isScanning: viewModel.uiState.isScanning,
                onScan: viewModel.startScan
            )
        } else {
            SavedCardsListView(
                tapsigners: viewModel.uiState.tapsigners,
                satsCards: viewModel.uiState.satsCards,
                satsChips: viewModel.uiState.satsChips,
                isScanning: viewModel.uiState.isScanning,
                onScan: viewModel.startScan,
                onRemoveTapsigner: viewModel.removeTapsigner(id:),
                onRemoveSatsCard: viewModel.removeSatsCard(id:),
                onRemoveSatsChip: viewModel.removeSatsChip(id:)
            )
        }
    }
}

// MARK: - Navigation destinations

private extension View {
    @ViewBuilder
    func navigationDestinations() -> some View {
        self.navigationDestination(for: CardsRoute.self) { _ in
            EmptyView()
        }
    }
}

// MARK: - Preview

#Preview {
    CardsViewFactory.build()
}
