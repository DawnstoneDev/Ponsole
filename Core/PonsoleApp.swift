import SwiftUI

@main
struct PonsoleApp: App {
    var body: some Scene {
        WindowGroup("Ponsole") {
            ContentView()
        }
        .defaultSize(width: 1180, height: 760)
        .commands {
            SidebarCommands()
        }
    }
}
