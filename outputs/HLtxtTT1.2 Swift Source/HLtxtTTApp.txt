import SwiftUI

@main
struct HLtxtTTApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: OverlayWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let model = OverlayModel()
        windowController = OverlayWindowController(model: model)
        windowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
