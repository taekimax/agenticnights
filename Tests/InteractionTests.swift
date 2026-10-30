import AppKit
import Carbon

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}

@main
enum InteractionTests {
    static func main() {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
        movementDismissal()
        shortcutReplacement()
        print("PASS: 2 AppKit interaction tests (in-process events and real hotkey registration)")
    }

    static func movementDismissal() {
        let window = BlackWindow(contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
                                 styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        var dismissals = 0
        window.dismiss = { dismissals += 1 }
        window.shownAt = 100
        func movement(at timestamp: TimeInterval) -> NSEvent {
            NSEvent.mouseEvent(with: .mouseMoved, location: NSPoint(x: 20, y: 20), modifierFlags: [],
                timestamp: timestamp, windowNumber: window.windowNumber, context: nil,
                eventNumber: 1, clickCount: 0, pressure: 0)!
        }
        window.sendEvent(movement(at: 99))
        expect(dismissals == 0, "Movement queued before showing must not immediately dismiss")
        window.sendEvent(movement(at: 101))
        expect(dismissals == 1, "Movement must dismiss by default")
        window.dismissOnMouseMove = false
        window.sendEvent(movement(at: 102))
        expect(dismissals == 1, "Opting out must keep the cover on movement")
        let key = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
            timestamp: 103, windowNumber: window.windowNumber, context: nil,
            characters: "x", charactersIgnoringModifiers: "x", isARepeat: false, keyCode: 7)!
        window.keyDown(with: key)
        expect(dismissals == 2, "A key must still dismiss while movement is disabled")
        window.close()
        print("PASS: movement default, stale movement, opt-out, and keyboard fallback")
    }

    static func shortcutReplacement() {
        let modifiers = KeyboardShortcut.command | KeyboardShortcut.option | KeyboardShortcut.control | KeyboardShortcut.shift
        let first = KeyboardShortcut(keyCode: 79, modifiers: modifiers)
        let occupied = KeyboardShortcut(keyCode: 80, modifiers: modifiers)
        let owner = GlobalShortcut(shortcut: first) {}
        let other = GlobalShortcut(shortcut: occupied) {}
        expect(owner.registrationStatus == noErr && other.registrationStatus == noErr, "Test combinations unavailable in this session")
        expect(owner.replace(with: occupied) != noErr, "A conflicting shortcut must be rejected")
        do {
            let probe = GlobalShortcut(shortcut: first) {}
            expect(probe.registrationStatus != noErr, "Failed replacement must preserve the original registration")
        }
        owner.suspend()
        do {
            let probe = GlobalShortcut(shortcut: first) {}
            expect(probe.registrationStatus == noErr, "Recorder must release the saved combo for key capture")
        }
        owner.resume(first)
        expect(owner.registrationStatus == noErr, "Canceling capture must restore the saved combo")
        let replacement = KeyboardShortcut(keyCode: 90, modifiers: modifiers)
        expect(owner.replace(with: replacement) == noErr, "An available shortcut must replace the original")
        let probe = GlobalShortcut(shortcut: first) {}
        expect(probe.registrationStatus == noErr, "Successful replacement must release the old combo")
        print("PASS: conflict recovery, recording suspend/resume, and shortcut replacement")
    }
}
