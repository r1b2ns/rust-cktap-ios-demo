import Combine
import SwiftUI

// MARK: - Route

/// Navigation destinations within the Cards module.
enum CardsRoute: Hashable {
    case cardDetail(CardReadResult)
}

// MARK: - Coordinator

/// Manages the navigation stack for the Cards module.
///
/// Exposed via `environmentObject` so any view in the module
/// can trigger transitions without direct coupling.
final class CardsCoordinator: MainCoordinatorProtocol {

    @Published var path = NavigationPath()

    // MARK: - Navigation

    func navigateToDetail(_ card: CardReadResult) {
        path.append(CardsRoute.cardDetail(card))
    }
}
