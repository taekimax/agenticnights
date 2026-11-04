// Real Sparkle smoke app; Scripts/test-updates.py supplies isolated bundles and automated choices.
import AppKit
import Sparkle

@MainActor
final class Smoke: NSObject, NSApplicationDelegate, SPUUserDriver, SPUUpdaterDelegate {
    var updater: SPUUpdater!
    let result = URL(fileURLWithPath: Bundle.main.object(forInfoDictionaryKey: "SmokeResult") as! String)
    let mode = Bundle.main.object(forInfoDictionaryKey: "SmokeMode") as! String
    func record(_ text: String) {
        let data = Data((text + "\n").utf8)
        if !FileManager.default.fileExists(atPath: result.path) { FileManager.default.createFile(atPath: result.path, contents: nil) }
        if let file = try? FileHandle(forWritingTo: result) { _ = try? file.seekToEnd(); try? file.write(contentsOf: data); try? file.close() }
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        if Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String == "2" {
            record("PASS: replaced app launched, version 2")
            NSApp.terminate(nil)
            return
        }
        updater = SPUUpdater(hostBundle: Bundle.main, applicationBundle: Bundle.main, userDriver: self, delegate: self)
        do { try updater.start(); updater.checkForUpdates() }
        catch { record("FAIL: start \(error)"); NSApp.terminate(nil) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 45) { self.record("FAIL: timeout"); NSApp.terminate(nil) }
    }
    func show(_ request: SPUUpdatePermissionRequest, reply: @escaping (SUUpdatePermissionResponse) -> Void) {
        reply(SUUpdatePermissionResponse(automaticUpdateChecks: false, sendSystemProfile: false))
    }
    func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) { record("Checking feed") }
    func showUpdateFound(with appcastItem: SUAppcastItem, state: SPUUserUpdateState, reply: @escaping (SPUUserUpdateChoice) -> Void) {
        record("Found version \(appcastItem.versionString)")
        reply(mode == "cancel" ? .dismiss : .install)
    }
    func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {}
    func showUpdateReleaseNotesFailedToDownloadWithError(_ error: Error) {}
    func showUpdateNotFoundWithError(_ error: Error, acknowledgement: @escaping () -> Void) {
        record("FAIL: no update \(error)"); acknowledgement(); NSApp.terminate(nil)
    }
    func showUpdaterError(_ error: Error, acknowledgement: @escaping () -> Void) {
        record("ERROR: \((error as NSError))"); acknowledgement(); NSApp.terminate(nil)
    }
    func showDownloadInitiated(cancellation: @escaping () -> Void) { record("Downloading") }
    func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {}
    func showDownloadDidReceiveData(ofLength length: UInt64) {}
    func showDownloadDidStartExtractingUpdate() { record("Download finished; validating/extracting") }
    func showExtractionReceivedProgress(_ progress: Double) {}
    func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) { record("Ready to install"); reply(.install) }
    func showInstallingUpdate(withApplicationTerminated applicationTerminated: Bool, retryTerminatingApplication: @escaping () -> Void) { record("Installing") }
    func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement: @escaping () -> Void) { acknowledgement() }
    func dismissUpdateInstallation() { record("Session dismissed") }
    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: Error?) {
        if mode == "cancel" { record("PASS: cancel kept version 1"); NSApp.terminate(nil) }
    }
}
@main
struct UpdateSmokeTests {
@MainActor static func main() {
    let app = NSApplication.shared
    let delegate = Smoke()
    app.setActivationPolicy(.accessory)
    app.delegate = delegate
    withExtendedLifetime(delegate) { app.run() }
}
}
