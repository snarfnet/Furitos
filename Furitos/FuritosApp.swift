import SwiftUI
import GoogleMobileAds

@main
struct FuritosApp: App {
    init() {
        MobileAds.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}
