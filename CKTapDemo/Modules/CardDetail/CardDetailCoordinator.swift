import Combine
import SwiftUI

// MARK: - Route

/// Navigation destinations within the CardDetail module.
///
/// Empty for now — the detail is a leaf screen. Add cases here when
/// pushing follow-up screens (e.g. a "Derive xpub" sheet, sign flow).
enum CardDetailRoute: Hashable {}

// MARK: - Coordinator

/// Manages the navigation stack for the CardDetail module.
///
/// Kept for symmetry with other modules even though no internal routes
/// exist yet — pushing onto the parent stack is done via `CardsCoordinator`.
final class CardDetailCoordinator: MainCoordinatorProtocol {

    @Published var path = NavigationPath()
}
