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
        shortcutReplacement()
        print("PASS: AppKit shortcut registration and replacement")
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
