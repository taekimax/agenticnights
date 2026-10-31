// Opt-in live verification. Briefly blanks the displays and filters input.
// Uses an in-memory test credential, never the user's Keychain/settings.
import AppKit
import CoreGraphics

// Read the real bundled catalog without exporting translations or accessing the
// installed app's Application Support directory.
private let testStrings: [String: String] = {
    let path = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "Resources/Translations/ko.json"
    return (try? JSONDecoder().decode([String: String].self, from: Data(contentsOf: URL(fileURLWithPath: path)))) ?? [:]
}()
func tr(_ key: String, _ arguments: [String: String] = [:]) -> String {
    arguments.reduce(testStrings[key] ?? key) { $0.replacingOccurrences(of: "{\($1.key)}", with: $1.value) }
}

private final class MemoryPassword: UnlockPasswordStorage {
    var data: Data?
    func read() throws -> Data? { data }
    func write(_ data: Data) throws { self.data = data }
}

private final class Destination: NSWindow {
    var delivered = 0
    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown { delivered += 1 }
        super.sendEvent(event)
    }
}

private struct SavedRamp {
    let id: UInt32
    let values: [Float]
    static func read(_ id: UInt32) -> SavedRamp {
        let capacity = CGDisplayGammaTableCapacity(id)
        var r = [Float](repeating: 0, count: Int(capacity)), g = r, b = r
        var count: UInt32 = 0
        precondition(CGGetDisplayTransferByTable(id, capacity, &r, &g, &b, &count) == .success)
        return SavedRamp(id: id, values: Array(r.prefix(Int(count))) + g.prefix(Int(count)) + b.prefix(Int(count)))
    }
}

@main
private struct PrivacyLiveTests {
    static let app = NSApplication.shared
    static let delegate = Runner()
    static func main() {
        app.setActivationPolicy(.regular)
        app.delegate = delegate
        app.run()
    }
}

private final class Runner: NSObject, NSApplicationDelegate {
    var lock: PrivacyLockController!
    var window: Destination!
    var failures = 0
    var saved: [SavedRamp] = []
    var settingsWindow: SettingsWindow?
    var buttonClicks = 0
    var buttonLabel: NSTextField?
    let artifact = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "/tmp/agenticnights-privacy-live")
    func applicationDidFinishLaunching(_ notification: Notification) {
        try? FileManager.default.createDirectory(at: artifact, withIntermediateDirectories: true)
        DispatchQueue.global().asyncAfter(deadline: .now() + 120) { exit(124) }
        Task { @MainActor in await run() }
    }
    func expect(_ condition: Bool, _ name: String) {
        let line = "\(condition ? "PASS" : "FAIL"): \(name)\n"
        print(line, terminator: ""); fflush(stdout)
        if !condition { failures += 1 }
        let url = artifact.appendingPathComponent("results.txt")
        let old = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        try? (old + line).write(to: url, atomically: true, encoding: .utf8)
    }
    func pause(_ seconds: Double = 0.25) async { try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000)) }
    func key(_ code: UInt16, source: CGEventSourceStateID = .hidSystemState, flags: CGEventFlags = []) {
        let src = CGEventSource(stateID: source)!
        src.userData = 731032
        for down in [true, false] {
            let e = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: down)!
            e.flags = flags
            e.post(tap: .cghidEventTap)
        }
    }
    @objc func clicked() {
        buttonClicks += 1
        buttonLabel?.stringValue = "Clicks: \(buttonClicks)"
    }
    func typePassword(correct: Bool) async {
        // testpass1 / wrongpass; keycodes are resolved by the controller's ASCII
        // layout while the normal input method remains untouched.
        let codes: [UInt16] = correct ? [17, 14, 1, 17, 35, 0, 1, 1, 18] : [13, 15, 31, 45, 5, 35, 0, 1, 1]
        for code in codes { key(code); await pause(0.04) }
        key(36)
        await pause(0.8)
    }
    @MainActor func run() async {
        do {
            if CommandLine.arguments.contains("--settings-preview") {
                settingsWindow = SettingsWindow()
                settingsWindow?.onSave = { _, _, _ in tr("privacy.noPassword") }
                settingsWindow?.present(settings: .defaults, status: "설정 화면 검증 — 실제 설정과 암호는 저장하지 않습니다.")
                await pause(60)
                settingsWindow?.close()
                finish()
                return
            }
            expect(AXIsProcessTrusted(), "existing Accessibility access")
            guard AXIsProcessTrusted() else { finish(); return }
            let store = MemoryPassword()
            let password = UnlockPassword(storage: store)
            try password.setPassword("testpass1")
            lock = PrivacyLockController(password: password)
            lock.onError = { [weak self] message in self?.expect(false, "controller error: \(message)") }
            for screen in NSScreen.screens {
                saved.append(SavedRamp.read(screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as! UInt32))
            }
            window = Destination(contentRect: NSRect(x: 300, y: 300, width: 520, height: 260),
                styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "agenticnights Live Validation"
            window.isReleasedWhenClosed = false
            let field = NSTextField(frame: NSRect(x: 20, y: 160, width: 470, height: 30))
            field.setAccessibilityLabel("Disposable test input")
            window.contentView?.addSubview(field)
            let button = NSButton(title: "Increment", target: self, action: #selector(clicked))
            button.frame = NSRect(x: 20, y: 110, width: 120, height: 30)
            button.bezelStyle = .rounded
            window.contentView?.addSubview(button)
            buttonLabel = NSTextField(labelWithString: "Clicks: 0")
            buttonLabel?.frame = NSRect(x: 160, y: 110, width: 200, height: 30)
            window.contentView?.addSubview(buttonLabel!)
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            window.makeFirstResponder(field)
            await pause()
            if CommandLine.arguments.contains("--physical-window") { await pause(10) }
            try lock.start()
            expect(lock.isLocked && lock.isInputBlocked, "production controller starts gamma blackout and HID filter")
            expect(saved.allSatisfy { SavedRamp.read($0.id).values.allSatisfy { $0 == 0 } }, "both gamma tables are zero while locked")
            if CommandLine.arguments.contains("--physical-window") {
                var sawPrompt = false
                var sawDismissal = false
                let deadline = Date().addingTimeInterval(60)
                while lock.isLocked && Date() < deadline {
                    if lock.isShowingPrompt { sawPrompt = true }
                    if sawPrompt && !lock.isShowingPrompt { sawDismissal = true }
                    await pause(0.05)
                }
                expect(sawPrompt, "physical input opened password prompt")
                expect(sawDismissal, "prompt dismissed while protection remained active")
                expect(!lock.isLocked && !lock.isInputBlocked, "physical password entry authenticated before automatic cleanup")
                finish()
                return
            }
            if CommandLine.arguments.contains("--agent-window") {
                await pause(45)
                expect(field.stringValue.contains("agent-validation"), "actual CUA text input reached the production-protected window")
                expect(buttonClicks > 0, "actual CUA click reached the production-protected window")
                expect(lock.isLocked && lock.isInputBlocked, "actual CUA interaction preserved privacy lock")
                finish()
                return
            }
            let before = window.delivered
            key(40, source: .combinedSessionState)
            await pause()
            expect(window.delivered == before + 1, "combined-source synthetic input reaches target while locked")
            key(40, source: .privateState)
            await pause()
            expect(window.delivered == before + 2, "private-source synthetic input reaches target while locked")
            let front = NSWorkspace.shared.frontmostApplication?.processIdentifier
            key(48, flags: .maskCommand)
            await pause()
            expect(NSWorkspace.shared.frontmostApplication?.processIdentifier == front && window.delivered == before + 2,
                   "HID-tagged Command-Tab simulation is suppressed")
            key(53); await pause()
            expect(lock.isLocked && lock.isInputBlocked && !lock.isShowingPrompt, "Escape hides prompt and preserves lock")
            await typePassword(correct: false)
            expect(lock.isLocked && lock.isShowingPrompt, "wrong password keeps lock and prompt")
            key(53); await pause()
            expect(lock.isLocked && saved.allSatisfy { SavedRamp.read($0.id).values.allSatisfy { $0 == 0 } },
                   "cancel after wrong password restores blackout without unlocking")
            lock.suspend()
            expect(lock.isLocked && !lock.isInputBlocked, "session suspension preserves lock intent and releases login input")
            lock.resume()
            expect(lock.isLocked && lock.isInputBlocked, "session resume re-establishes protection")
            await typePassword(correct: true)
            expect(!lock.isLocked && !lock.isInputBlocked, "correct password unlocks via intercepted HID-tagged events")
            expect(saved.allSatisfy { SavedRamp.read($0.id).values == $0.values }, "exact original gamma ramps restored on authenticated unlock")
            // Validate existing Settings cancel semantics with the new fields.
            settingsWindow = SettingsWindow()
            var didSave = false
            settingsWindow?.onSave = { _, _, _ in didSave = true; return nil }
            settingsWindow?.present(settings: .defaults, status: "Isolated validation — no settings are saved")
            await pause()
            settingsWindow?.close()
            expect(!didSave, "closing Settings does not save password or settings")
            finish()
        } catch { expect(false, String(describing: error)); finish() }
    }
    func finish() {
        lock?.shutdown()
        expect(saved.allSatisfy { SavedRamp.read($0.id).values == $0.values }, "final gamma restoration")
        window?.close()
        exit(failures == 0 ? 0 : 1)
    }
}
