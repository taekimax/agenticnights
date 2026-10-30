import AppKit

final class BlackWindow: NSWindow {
    var dismiss: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) {
        // Consume the dismissing key so it cannot type into the restored app.
        dismiss?()
    }

    override func mouseDown(with event: NSEvent) { dismiss?() }
    override func rightMouseDown(with event: NSEvent) { dismiss?() }
}

final class BlackView: NSView {
    override var isOpaque: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill()
        dirtyRect.fill()
    }
}

final class CoverController {
    private(set) var windows: [BlackWindow] = []
    private var previousApplication: NSRunningApplication?
    private var previousPresentation: NSApplication.PresentationOptions = []
    private var isUpdating = false
    private(set) var isCovered = false
    var hideMenuBar = true
    var onChange: (() -> Void)?

    func show() {
        guard !isUpdating, !NSScreen.screens.isEmpty else { return }
        isUpdating = true
        defer { isUpdating = false }
        if !isCovered {
            previousApplication = NSWorkspace.shared.frontmostApplication
            if previousApplication?.processIdentifier == ProcessInfo.processInfo.processIdentifier {
                previousApplication = nil
            }
            previousPresentation = NSApp.presentationOptions
        }
        closeWindows()
        isCovered = true
        // These are normal-level windows, not a screen saver or an always-on-top
        // overlay. Activating another app dismisses them via AppDelegate.
        NSApp.activate(ignoringOtherApps: true)
        NSApp.presentationOptions = hideMenuBar ? [.hideDock, .hideMenuBar] : [.autoHideDock]
        for screen in NSScreen.screens {
            let window = BlackWindow(contentRect: screen.frame, styleMask: [.borderless],
                                     backing: .buffered, defer: false)
            window.setFrame(screen.frame, display: false)
            window.level = .normal
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            window.backgroundColor = .black
            window.isOpaque = true
            window.hasShadow = false
            window.isReleasedWhenClosed = false
            window.animationBehavior = .none
            window.isRestorable = false
            window.title = "agenticnights — 검은 화면"
            window.contentView = BlackView(frame: NSRect(origin: .zero, size: screen.frame.size))
            window.dismiss = { [weak self] in self?.hide(restorePrevious: true) }
            windows.append(window)
            window.orderFrontRegardless()
        }
        windows.first?.makeKey()
        onChange?()
    }

    func hide(restorePrevious: Bool) {
        guard isCovered else { return }
        isCovered = false
        NSApp.presentationOptions = previousPresentation
        closeWindows()
        let previous = previousApplication
        previousApplication = nil
        if restorePrevious, let previous, !previous.isTerminated {
            previous.activate(options: [.activateIgnoringOtherApps])
        }
        onChange?()
    }

    func refreshScreens() {
        guard isCovered else { return }
        if NSScreen.screens.isEmpty { hide(restorePrevious: false) }
        else { show() }
    }

    private func closeWindows() {
        for window in windows { window.orderOut(nil); window.close() }
        windows.removeAll()
    }
}
