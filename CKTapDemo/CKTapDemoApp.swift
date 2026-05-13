import SwiftUI

@main
struct CKTapDemoApp: App {
    var body: some Scene {
        WindowGroup {
            CardsViewFactory.build()
        }
    }
}
