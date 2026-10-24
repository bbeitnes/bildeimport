import AppKit
import SwiftUI

@main
struct BildeimportApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel()

    var body: some Scene {
        Window("Bildeimport", id: "main") {
            ContentView()
                .environment(model)
                .onAppear { model.start() }
        }
        .windowResizability(.contentSize)
        .commands {
            // One window only: no "New window" menu item.
            CommandGroup(replacing: .newItem) {}
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Closing the window quits the app, so nothing keeps running unseen.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
