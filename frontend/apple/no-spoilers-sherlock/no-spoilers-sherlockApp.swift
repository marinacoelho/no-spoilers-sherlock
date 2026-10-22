import SwiftUI
import AppCore
import FirebaseCore
import FirebaseAppCheck

@main
struct NoSpoilersSherlockApp: App {
    init() {
        let providerFactory = AppCheckDebugProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)
        if FirebaseApp.app() == nil,
           Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
