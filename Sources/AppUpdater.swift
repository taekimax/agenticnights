import AppKit
@preconcurrency import Sparkle

/// Main-thread AppKit owner. Sparkle owns the schedule, preferences, validation and UI.
final class AppUpdater: NSObject, SPUUpdaterDelegate {
    var canBeginUpdate: () -> Bool = { true }
    var onChange: (() -> Void)?
    private var controller: SPUStandardUpdaterController!
    private var deferredCheck = false

    override init() {
        super.init()
        controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: nil)
    }

    var blocksBlackout: Bool { controller.updater.sessionInProgress }
    var canCheck: Bool { canBeginUpdate() && controller.updater.canCheckForUpdates }
    var automaticallyChecks: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }

    func start() { controller.startUpdater() }
    func check() {
        guard canCheck else { return }
        controller.checkForUpdates(nil)
    }

    func resumeIfPossible() {
        guard deferredCheck, canBeginUpdate(), !blocksBlackout, automaticallyChecks else { return }
        // Leave the caller's state transition before starting a new Sparkle cycle.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.deferredCheck, self.canBeginUpdate(), !self.blocksBlackout,
                  self.automaticallyChecks else { return }
            self.deferredCheck = false
            self.controller.updater.checkForUpdatesInBackground()
        }
    }

    func updater(_ updater: SPUUpdater, mayPerform updateCheck: SPUUpdateCheck) throws {
        guard canBeginUpdate() else {
            deferredCheck = true
            throw NSError(domain: "com.tk.agenticnights.Updater", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: tr("update.endBlackout")])
        }
        DispatchQueue.main.async { [weak self] in self?.onChange?() }
    }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: Error?) {
        DispatchQueue.main.async { [weak self] in self?.onChange?() }
    }
}
