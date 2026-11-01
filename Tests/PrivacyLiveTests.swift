// Opt-in checks that change physical gamma/backlight. Never run as a unit test.
// --authentication opens the real macOS authentication UI; a human supplies
// Touch ID, the Mac password or Cancel. No simulated credential is accepted.
import AppKit
import CoreGraphics

private let testStrings: [String: String] = {
    let path = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "Resources/Translations/en.json"
    return (try? JSONDecoder().decode([String: String].self,
            from: Data(contentsOf: URL(fileURLWithPath: path)))) ?? [:]
}()
func tr(_ key: String, _ arguments: [String: String] = [:]) -> String {
    arguments.reduce(testStrings[key] ?? key) { $0.replacingOccurrences(of: "{\($1.key)}", with: $1.value) }
}

private struct SavedRamp {
    let id: CGDirectDisplayID
    let values: [Float]
    static func read(_ id: CGDirectDisplayID) -> SavedRamp? {
        let capacity = CGDisplayGammaTableCapacity(id)
        guard capacity > 0 else { return nil }
        var red = [Float](repeating: 0, count: Int(capacity)), green = red, blue = red
        var count: UInt32 = 0
        guard CGGetDisplayTransferByTable(id, capacity, &red, &green, &blue, &count) == .success,
              count > 0, count <= capacity else { return nil }
        return SavedRamp(id: id, values: Array(red.prefix(Int(count)))
            + green.prefix(Int(count)) + blue.prefix(Int(count)))
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
    let cover = PrivacyLockController()
    var failures = 0
    var finished = false
    var saved: [SavedRamp] = []
    let artifact = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "/tmp/agenticnights-privacy-live")

    func applicationDidFinishLaunching(_ notification: Notification) {
        try? FileManager.default.createDirectory(at: artifact, withIntermediateDirectories: true)
        cover.onError = { [weak self] error in self?.expect(false, "controller error: \(error)") }
        DispatchQueue.main.asyncAfter(deadline: .now() + 90) { [weak self] in
            guard let self, !self.finished else { return }
            self.log("NOT RUN: human authentication was not completed within 90 seconds")
            self.finish()
        }
        Task { @MainActor in await run() }
    }

    func log(_ line: String) {
        print(line); fflush(stdout)
        let url = artifact.appendingPathComponent("results.txt")
        let old = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        try? (old + line + "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    func expect(_ condition: Bool, _ name: String) {
        log("\(condition ? "PASS" : "FAIL"): \(name)")
        if !condition { failures += 1 }
    }

    func pause() async { try? await Task.sleep(nanoseconds: 300_000_000) }
    var gammaIsZero: Bool {
        !saved.isEmpty && saved.allSatisfy { ramp in
            guard let current = SavedRamp.read(ramp.id) else { return false }
            return current.values.allSatisfy { $0 == 0 }
        }
    }
    var gammaIsRestored: Bool {
        !saved.isEmpty && saved.allSatisfy { SavedRamp.read($0.id)?.values == $0.values }
    }

    @MainActor func run() async {
        log("NOT RUN: physical panel appearance, Touch ID versus password choice, Cmd-Tab, VoiceOver and agent input require separately recorded human observations")
        saved = NSScreen.screens.compactMap { screen in
            guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32 else { return nil }
            return SavedRamp.read(id)
        }
        expect(!saved.isEmpty, "original gamma ramps captured")
        guard !saved.isEmpty else { finish(); return }
        do {
            let authentication = CommandLine.arguments.contains("--authentication")
            try cover.start(requireAuthentication: authentication)
            expect(cover.isCovered && cover.isLocked == authentication, "requested blackout state is active")
            expect(gammaIsZero, "active display gamma ramps are zero")
            if authentication {
                cover.onUnlock = { [weak self] in
                    guard let self else { return }
                    self.expect(!self.cover.isCovered && !self.cover.isAuthenticating,
                                "real LocalAuthentication success ends blackout")
                    self.finish()
                }
                cover.onAuthenticationCancelled = { [weak self] in
                    guard let self else { return }
                    self.expect(self.cover.isCovered && !self.cover.isAuthenticating,
                                "cancelled or failed system authentication preserves blackout intent")
                    self.expect(self.gammaIsZero, "gamma is zero after authentication cancellation")
                    self.finish()
                }
                log("MANUAL: authenticate with Touch ID/Mac password, or cancel/switch apps; the callback records only the actual resulting state")
                cover.requestUnlock()
                return
            }
            cover.suspend()
            expect(cover.isCovered && !cover.isLocked && gammaIsRestored,
                   "ordinary blackout suspension retains intent and restores gamma")
            cover.resume()
            expect(cover.isCovered && gammaIsZero, "resume reapplies ordinary blackout")
            cover.refreshScreens()
            await pause()
            expect(gammaIsZero, "display refresh preserves blackout")
            cover.requestUnlock()
            expect(!cover.isCovered && gammaIsRestored, "ordinary unlock restores original gamma")
            finish()
        } catch {
            expect(false, String(describing: error))
            finish()
        }
    }

    func finish() {
        guard !finished else { return }
        finished = true
        cover.onAuthenticationCancelled = nil
        cover.shutdown()
        expect(gammaIsRestored, "final original gamma restoration")
        exit(failures == 0 ? 0 : 1)
    }
}
