import SwiftUI

@main
struct CinemanaProApp: App {
    @StateObject private var environment = AppEnvironment()
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(environment).preferredColorScheme(.dark)
        }
    }
}
