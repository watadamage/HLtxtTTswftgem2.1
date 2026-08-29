import AppKit
import SwiftUI

private final class InteractiveOverlayWindow: NSWindow {
    // A status-level utility window must explicitly be allowed to become key,
    // otherwise embedded AppKit controls can display text but not accept a
    // selection, caret, keyboard input, or mouse editing gestures.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class OverlayWindowController: NSWindowController, NSWindowDelegate {
    init(model: OverlayModel) {
        let frame = NSRect(x: 120, y: 120, width: 440, height: 650)
        let window = InteractiveOverlayWindow(
            contentRect: frame,
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = "HLtxtTTswft2.2"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        // Keep the document editor's empty areas available for normal mouse
        // selection and dragging rather than treating them as window drags.
        window.isMovableByWindowBackground = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        // statusBar is above regular and floating application windows.  It remains below
        // system alerts, which prevents the utility from obscuring security UI.
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.hidesOnDeactivate = false
        window.minSize = NSSize(width: 380, height: 570)
        window.setFrameAutosaveName("HLtxtTTswft22Overlay")

        model.attach(window: window)
        window.contentView = NSHostingView(rootView: OverlayView(model: model))
        super.init(window: window)
        window.delegate = self
        // Keep the standard traffic-light actions available even when the overlay is
        // inactive and above another application.
        let closeButton = window.standardWindowButton(.closeButton)
        closeButton?.isEnabled = true
        closeButton?.target = self
        closeButton?.action = #selector(closeWindow)
        let minimizeButton = window.standardWindowButton(.miniaturizeButton)
        minimizeButton?.isEnabled = true
        minimizeButton?.target = self
        minimizeButton?.action = #selector(minimizeWindow)
        shouldCascadeWindows = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    @objc private func closeWindow(_ sender: Any?) {
        NSApp.terminate(nil)
    }

    @objc private func minimizeWindow(_ sender: Any?) {
        window?.miniaturize(nil)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        closeWindow(nil)
        return false
    }
}
