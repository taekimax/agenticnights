import Foundation

/// One-time removal through the system utility keeps retired Keychain APIs out
/// of the application binary. No credential is read or passed on a command line.
final class LegacyPasswordCleanup {
    private var process: Process?
    func run() {
        guard !UserDefaults.standard.bool(forKey: "legacyPasswordRemoved") else { return }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        task.arguments = ["delete-generic-password", "-s", "com.tk.agenticnights.unlock", "-a", "privacy-cover-password"]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        task.terminationHandler = { task in
            // security returns 44 (errSecItemNotFound modulo 256) if absent.
            if task.terminationStatus == 0 || task.terminationStatus == 44 {
                UserDefaults.standard.set(true, forKey: "legacyPasswordRemoved")
            }
        }
        do { try task.run(); process = task } catch { }
    }
}
