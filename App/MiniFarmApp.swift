import SwiftUI

@main
struct MiniFarmApp: App {
    var body: some Scene {
        WindowGroup {
            FarmRootView()
                .preferredColorScheme(.light)
        }
    }
}
