import Combine
import SwiftUI

// MARK: - Route

/// Navigation destinations within the Cards module.
///
/// Empty for now — UI flows are handled via alerts. Add new cases here when
/// pushing detail screens onto the stack.
enum CardsRoute: Hashable {}

// MARK: - Coordinator

/// Manages the navigation stack for the Cards module.
///
/// Exposed via `environmentObject` so any view in the module
/// can trigger transitions without direct coupling.
final class CardsCoordinator: MainCoordinatorProtocol {

    @Published var path = NavigationPath()
}
