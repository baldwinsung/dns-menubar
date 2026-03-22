import AppKit
import SwiftUI

final class PreferencesWindowController: NSWindowController {
    convenience init(store: MappingStore, onSave: @escaping () -> Void) {
        let hostingController = NSHostingController(rootView: PreferencesView(store: store, onSave: onSave))
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Preferences"
        window.styleMask = [.titled, .closable, .resizable]
        window.center()
        self.init(window: window)
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }
}
