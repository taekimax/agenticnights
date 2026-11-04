import AppKit
import LocalAuthentication
import OSLog

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let log = Logger(subsystem: "com.tk.agenticnights", category: "App")
    private let privacy = PrivacyLockController()
    private let legacyCleanup = LegacyPasswordCleanup()
    private let sleepPrevention = SleepPrevention()
    private var schedule = VeilSchedule()
    private var userActivity = UserActivity()
    private var settings = VeilSettings.defaults
    private var statusItem: NSStatusItem!
    private var idleTimer: Timer?
    private var awakeTimer: Timer?
    private var terminationSignal: DispatchSourceSignal?
    private var shortcut: GlobalShortcut?
    private var settingsWindow: SettingsWindow?
    private var updates: AppUpdater!
    private var observers: [NSObjectProtocol] = []
    private var sessionActive = true
    private var sleeping = false
    private var displaySleeping = false
    private var menuIsOpen = false
    private var screenLocked = false
    private var systemTerminating = false
    private var quitAfterUnlock = false
    private var terminating = false
    private var privacyError: String?
    private var dismissalMouseNumber: Int64?
    private var lastStatusData: Data?
    private var settingsAuthentication: LAContext?
    private let statusURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/agenticnights/status.json")
    private var sessionAvailable: Bool { sessionActive && !sleeping && !displaySleeping && !screenLocked }

    func applicationDidFinishLaunching(_ notification: Notification) {
        signal(SIGTERM, SIG_IGN)
        terminationSignal = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        terminationSignal?.setEventHandler { NSApp.terminate(nil) }
        terminationSignal?.resume()
        let firstLaunch = UserDefaults.standard.data(forKey: "settings") == nil
        if let data = UserDefaults.standard.data(forKey: "settings"),
           let loaded = try? JSONDecoder().decode(VeilSettings.self, from: data) {
            settings = loaded.validated()
        }
        persistSettings()
        legacyCleanup.run()
        installMainMenu()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.autosaveName = "ScreenProtection"
        statusItem.button?.target = self
        statusItem.button?.action = #selector(iconClicked(_:))
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        // A click that ends blackout or opens authentication is consumed by that request.
        // Clicks while the prompt is already open start nothing and stay usable.
        privacy.onPhysicalClick = { [weak self] event in
            guard let self, !self.privacy.isAuthenticating else { return }
            self.dismissalMouseNumber = event.cgEvent?.getIntegerValueField(.mouseEventNumber)
        }
        privacy.onChange = { [weak self] in self?.refreshStatus() }
        privacy.onError = { [weak self] error in
            self?.privacyError = error
            self?.log.error("Blackout: \(error, privacy: .public)")
            self?.refreshStatus()
        }
        privacy.onAuthenticationCancelled = { [weak self] in self?.quitAfterUnlock = false }
        privacy.onUnlock = { [weak self] in
            guard let self, !self.terminating else { return }
            self.userActivity.reset()
            self.schedule.reset()
            self.privacyError = nil
            // Unlock can complete synchronously inside applicationShouldTerminate.
            if self.quitAfterUnlock { self.quitAfterUnlock = false; DispatchQueue.main.async { NSApp.terminate(nil) } }
            else { self.updateState() }
        }
        shortcut = GlobalShortcut(shortcut: settings.shortcut) { [weak self] in self?.toggleCover() }
        updates = AppUpdater()
        updates.canBeginUpdate = { [weak self] in
            guard let self else { return false }
            return self.sessionAvailable && !self.privacy.isCovered && self.settingsAuthentication == nil && !self.terminating
        }
        updates.onChange = { [weak self] in self?.updateState() }
        observeSystem()
        updateState()
        updates.start()
        if firstLaunch { showSettings() }
    }

    @objc private func iconClicked(_ button: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let dismissedByThisClick = isPhysicalClick(sourceStateID: event?.cgEvent?.getIntegerValueField(.eventSourceStateID)) &&
            dismissalMouseNumber != nil &&
            dismissalMouseNumber == event?.cgEvent?.getIntegerValueField(.mouseEventNumber)
        dismissalMouseNumber = nil
        guard !dismissedByThisClick else { return }
        let opensMenu = event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true ||
            event?.modifierFlags.contains(.option) == true || settings.iconAction == .openMenu
        if opensMenu {
            let menu = NSMenu()
            menu.autoenablesItems = false
            menu.delegate = self
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.minY - 4), in: button)
        } else {
            switch settings.iconAction {
            case .openMenu: break
            case .blackOut: if !privacy.isCovered { showCover() }
            case .toggleSleep: toggleAwakeEnabled()
            }
        }
    }

    private func installMainMenu() {
        let main = NSMenu()
        let item = NSMenuItem()
        let appMenu = NSMenu(title: "agenticnights")
        appMenu.autoenablesItems = false
        appMenu.delegate = self
        item.submenu = appMenu
        main.addItem(item)
        let editItem = NSMenuItem(title: tr("menu.edit"), action: nil, keyEquivalent: "")
        let edit = NSMenu(title: tr("menu.edit"))
        for (title, action, key) in [(tr("menu.undo"), "undo:", "z"), (tr("menu.cut"), "cut:", "x"),
                                     (tr("menu.copy"), "copy:", "c"), (tr("menu.paste"), "paste:", "v"),
                                     (tr("menu.selectAll"), "selectAll:", "a")] {
            edit.addItem(withTitle: title, action: Selector(action), keyEquivalent: key)
        }
        editItem.submenu = edit
        main.addItem(editItem)
        NSApp.mainMenu = main
    }

    private func observeSystem() {
        let workspace = NSWorkspace.shared.notificationCenter
        func observe(_ name: Notification.Name, _ body: @escaping (AppDelegate) -> Void) {
            observers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                guard let self else { return }; body(self)
            })
        }
        observe(NSWorkspace.willSleepNotification) { $0.sleeping = true; $0.suspend() }
        observe(NSWorkspace.screensDidSleepNotification) { $0.displaySleeping = true; $0.suspend() }
        observe(NSWorkspace.didWakeNotification) { $0.sleeping = false; $0.returnToSession() }
        observe(NSWorkspace.screensDidWakeNotification) { $0.displaySleeping = false; $0.returnToSession() }
        observe(NSWorkspace.sessionDidResignActiveNotification) { $0.sessionActive = false; $0.suspend() }
        observe(NSWorkspace.sessionDidBecomeActiveNotification) { $0.sessionActive = true; $0.returnToSession() }
        observe(NSWorkspace.willPowerOffNotification) { $0.systemTerminating = true }
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
                self?.privacy.refreshScreens()
            })
        let distributed = DistributedNotificationCenter.default()
        observers.append(distributed.addObserver(forName: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil, queue: .main) { [weak self] _ in self?.screenLocked = true; self?.suspend() })
        observers.append(distributed.addObserver(forName: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil, queue: .main) { [weak self] _ in self?.screenLocked = false; self?.returnToSession() })
        observers.append(NotificationCenter.default.addObserver(forName: NSNotification.Name.NSSystemClockDidChange,
            object: nil, queue: .main) { [weak self] _ in self?.updateState() })
    }

    private func suspend() {
        idleTimer?.invalidate(); idleTimer = nil
        privacy.suspend()
        schedule.reset()
        // Sleep prevention and its deadline are independent of blackout/session state.
        updateAwake(now: Date())
        refreshStatus()
    }

    private func returnToSession() {
        schedule.reset()
        userActivity.reset()
        if sessionAvailable { privacy.resume() }
        updateState()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }

    private func updateState() {
        guard !terminating else { return }
        idleTimer?.invalidate(); idleTimer = nil
        let now = Date()
        updateAwake(now: now)
        if sessionAvailable && settings.enabled && !privacy.isCovered && !menuIsOpen && !updates.blocksBlackout && settingsWindow?.window?.isVisible != true {
            if schedule.tick(now: now, settings: settings, idleSeconds: userActivity.idleSeconds()) { showCover() }
            if !privacy.isCovered, let next = schedule.nextCover {
                let delay = max(0.1, next.timeIntervalSinceNow)
                let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in self?.updateState() }
                timer.tolerance = min(5, delay * 0.1)
                idleTimer = timer
                RunLoop.main.add(timer, forMode: .common)
            }
        }
        refreshStatus()
        updates.resumeIfPossible()
    }

    private func updateAwake(now: Date) {
        awakeTimer?.invalidate(); awakeTimer = nil
        let previous = settings.awake
        let active = settings.awake.update(at: now)
        if settings.awake != previous { persistSettings() }
        if active { sleepPrevention.start(settings: settings.awake, now: now) }
        else { sleepPrevention.stop() }
        if let deadline = settings.awake.expiresAt {
            let delay = max(0.01, deadline.timeIntervalSince(now))
            let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in self?.updateState() }
            timer.tolerance = min(1, delay * 0.1)
            awakeTimer = timer
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private var coverStatusText: String {
        if let privacyError { return tr("error.blackout", ["error": privacyError]) }
        return tr(privacy.isCovered ? "status.blackedOut" : (settings.enabled ? "menu.autoBlackout" : "status.off"))
    }

    private var awakeStatusText: String {
        if !settings.awake.enabled { return tr("status.off") }
        if let error = sleepPrevention.lastError { return error }
        if let deadline = settings.awake.expiresAt {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: Localization.shared.language)
            formatter.timeStyle = .short
            formatter.dateStyle = .none
            let key = Calendar.current.isDateInTomorrow(deadline) ? "status.onUntilTomorrow" : "status.onUntil"
            return tr(key, ["time": formatter.string(from: deadline)])
        }
        return tr("status.onNoLimit")
    }

    private func refreshStatus() {
        guard let button = statusItem?.button else { return }
        let enabled = settings.enabled || settings.awake.enabled || privacy.isCovered
        button.image = NSImage(systemSymbolName: enabled ? "moon.fill" : "moon", accessibilityDescription: "agenticnights")
        button.image?.isTemplate = true
        button.appearsDisabled = !enabled
        button.toolTip = coverStatusText + "\n" + tr("sleep.title") + ": " + awakeStatusText + "\n" + tr("icon.hint")
        button.setAccessibilityLabel("agenticnights")
        settingsWindow?.updateStatus(awakeStatusText, settings: settings)
        writeStatus()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        @discardableResult func add(_ key: String, _ action: Selector?, checked: Bool? = nil) -> NSMenuItem {
            let item = menu.addItem(withTitle: tr(key), action: action, keyEquivalent: "")
            item.target = self
            if let checked { item.state = checked ? .on : .off }
            return item
        }
        let blackoutKey = privacy.isCovered ? (settings.requireAuthentication ? "menu.endBlackoutAuth" : "menu.endBlackout") : "menu.blackOut"
        add(blackoutKey, #selector(toggleCover)).isEnabled = updates?.blocksBlackout != true
        menu.addItem(.separator())
        add("menu.autoBlackout", #selector(toggleEnabled), checked: settings.enabled)
        let interval = add("menu.autoDelay", nil)
        interval.title = tr("menu.autoDelay", ["minutes": String(settings.intervalMinutes)])
        let intervals = NSMenu(); intervals.autoenablesItems = false
        for minutes in [5, 10, 15, 30, 60] {
            let item = intervals.addItem(withTitle: tr("menu.minutes", ["minutes": String(minutes)]), action: #selector(setInterval(_:)), keyEquivalent: "")
            item.target = self; item.tag = minutes
            item.state = settings.intervalMinutes == minutes ? .on : .off
        }
        let customDelay = intervals.addItem(withTitle: tr("menu.custom"), action: #selector(showDelaySettings), keyEquivalent: "")
        customDelay.target = self
        interval.submenu = intervals
        menu.addItem(.separator())
        add("menu.preventSleep", #selector(toggleAwakeEnabled), checked: settings.awake.enabled)
        let status = menu.addItem(withTitle: awakeStatusText, action: nil, keyEquivalent: "")
        status.isEnabled = false
        let duration = add("menu.duration", nil)
        let durations = NSMenu(); durations.autoenablesItems = false
        for minutes in [0, 30, 60, 120] {
            let title = minutes == 0 ? tr("menu.noLimit") : tr("menu.minutes", ["minutes": String(minutes)])
            let item = durations.addItem(withTitle: title, action: #selector(setAwakeTimer(_:)), keyEquivalent: "")
            item.target = self; item.tag = minutes
            item.state = (minutes == 0 ? !settings.awake.timerEnabled : settings.awake.timerEnabled && settings.awake.durationMinutes == minutes) ? .on : .off
        }
        let customDuration = durations.addItem(withTitle: tr("menu.custom"), action: #selector(showDurationSettings), keyEquivalent: "")
        customDuration.target = self
        duration.submenu = durations
        add("menu.keepDisplayOn", #selector(toggleDisplay), checked: settings.awake.keepDisplayOn)
        menu.addItem(.separator())
        let preferences = add("menu.settings", #selector(showSettings)); preferences.keyEquivalent = ","
        add("menu.checkUpdates", #selector(checkForUpdates)).isEnabled = updates?.canCheck == true
        add("menu.autoUpdates", #selector(toggleAutomaticUpdates), checked: updates?.automaticallyChecks == true)
        let quit = add("menu.quit", #selector(NSApplication.terminate(_:))); quit.target = NSApp; quit.keyEquivalent = "q"
    }

    func menuWillOpen(_ menu: NSMenu) { menuIsOpen = true; idleTimer?.invalidate(); idleTimer = nil }
    func menuDidClose(_ menu: NSMenu) { menuIsOpen = false; updateState() }

    @objc private func checkForUpdates() { updates.check() }
    @objc private func toggleAutomaticUpdates() {
        updates.automaticallyChecks.toggle()
        refreshStatus()
    }

    @objc private func setInterval(_ sender: NSMenuItem) {
        var updated = settings; updated.intervalMinutes = sender.tag; _ = applySettings(updated)
    }
    @objc private func setAwakeTimer(_ sender: NSMenuItem) {
        var updated = settings; updated.awake.timerEnabled = sender.tag != 0
        if sender.tag > 0 { updated.awake.durationMinutes = sender.tag }
        _ = applySettings(updated)
    }
    @objc private func toggleDisplay() {
        var updated = settings; updated.awake.keepDisplayOn.toggle(); _ = applySettings(updated)
    }
    @objc private func toggleEnabled() {
        var updated = settings; updated.enabled.toggle(); _ = applySettings(updated)
    }
    @objc private func toggleAwakeEnabled() {
        var updated = settings; updated.awake.enabled.toggle(); _ = applySettings(updated)
    }

    @objc private func showCover() {
        guard sessionAvailable, !privacy.isCovered, !updates.blocksBlackout else { return }
        // Blackout closes Settings; its pending prompt must not linger offscreen.
        settingsAuthentication?.invalidate(); settingsAuthentication = nil
        settingsWindow?.close()
        idleTimer?.invalidate(); idleTimer = nil
        do {
            try privacy.start(requireAuthentication: settings.requireAuthentication)
            privacyError = nil
        } catch {
            privacyError = error.localizedDescription
            log.error("Could not start blackout: \(error.localizedDescription, privacy: .public)")
        }
        schedule.didCover(at: Date(), settings: settings)
        refreshStatus()
    }

    @objc private func toggleCover() {
        if privacy.isCovered { privacy.requestUnlock() }
        else { showCover() }
    }

    @objc private func showSettings() { presentSettings() }
    @objc private func showDelaySettings() { presentSettings(focus: .delay) }
    @objc private func showDurationSettings() { presentSettings(focus: .duration) }
    private func presentSettings(focus: SettingsWindow.Focus? = nil) {
        guard !privacy.isLocked else { privacy.requestUnlock(); return }
        privacy.shutdown()
        idleTimer?.invalidate(); idleTimer = nil
        if settingsWindow == nil {
            settingsWindow = SettingsWindow()
            settingsWindow?.onChange = { [weak self] settings in self?.applySettings(settings) }
            settingsWindow?.onRecordingChanged = { [weak self] recording in
                guard let self else { return }
                if recording { self.shortcut?.suspend() }
                else { self.shortcut?.resume(self.settings.shortcut); self.refreshStatus() }
            }
            settingsWindow?.onClose = { [weak self] in
                DispatchQueue.main.async { self?.updateState() }
            }
            settingsWindow?.loginItemStatus = {
                let state = LaunchAtLogin.state
                return LoginItemStatus(enabled: state == .enabled, needsApproval: state == .requiresApproval,
                                       available: state != .unavailable)
            }
            settingsWindow?.onLoginItemChange = { [weak self] enabled in
                let error = LaunchAtLogin.set(enabled)
                if let error { self?.log.error("Login item: \(error, privacy: .public)") }
                self?.refreshStatus()
                return error.map { tr("error.startup", ["error": $0]) }
            }
            settingsWindow?.onOpenLoginItems = { LaunchAtLogin.openSystemSettings() }
        }
        settingsWindow?.present(settings: settings, status: awakeStatusText, focus: focus)
        refreshStatus()
    }

    private func applySettings(_ newSettings: VeilSettings, authenticated: Bool = false) -> String? {
        let old = settings
        let candidate = newSettings.validated()
        // Only turning account authentication off is protected. Every other
        // setting, including sleep prevention, changes without a prompt.
        if old.requireAuthentication && !candidate.requireAuthentication && !authenticated {
            return authenticateDisablingProtection()
        }
        if candidate.requireAuthentication && !old.requireAuthentication,
           let reason = PrivacyLockController.authenticationUnavailableReason() { return reason }
        if candidate.shortcut != old.shortcut || shortcut?.registrationStatus != noErr {
            guard shortcut?.replace(with: candidate.shortcut) == noErr else { return tr("error.shortcut") }
        }
        settings = candidate
        let restartTimer = old.awake.enabled != settings.awake.enabled ||
            old.awake.timerEnabled != settings.awake.timerEnabled || old.awake.durationMinutes != settings.awake.durationMinutes
        settings.awake.expiresAt = restartTimer ? nil : old.awake.expiresAt
        if old.enabled != settings.enabled || old.intervalMinutes != settings.intervalMinutes { schedule.reset() }
        persistSettings()
        updateState()
        return nil
    }

    /// Returns "" while the system prompt is open: SettingsWindow keeps the
    /// previous value without an error and receives the result via updateStatus.
    private func authenticateDisablingProtection() -> String? {
        guard settingsAuthentication == nil else { return "" }
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            context.invalidate()
            // Nobody can authenticate an account without a login password.
            guard PrivacyLockController.isPasscodeNotSet(error) else {
                return (error ?? LAError(.passcodeNotSet) as NSError).localizedDescription
            }
            var updated = settings; updated.requireAuthentication = false
            return applySettings(updated, authenticated: true)
        }
        settingsAuthentication = context
        context.evaluatePolicy(.deviceOwnerAuthentication,
                               localizedReason: tr("blackout.disableAuthReason")) { [weak self] success, _ in
            DispatchQueue.main.async {
                guard let self, self.settingsAuthentication === context else { return }
                self.settingsAuthentication = nil
                guard success, !self.terminating, self.settings.requireAuthentication else { return }
                var updated = self.settings; updated.requireAuthentication = false
                _ = self.applySettings(updated, authenticated: true)
            }
        }
        return ""
    }

    private func persistSettings() {
        if let data = try? JSONEncoder().encode(settings) { UserDefaults.standard.set(data, forKey: "settings") }
    }

    private func writeStatus(running: Bool = true) {
        var state: [String: Any] = [
            "running": running, "pid": ProcessInfo.processInfo.processIdentifier,
            "uiLanguage": Localization.shared.language,
            "translationDirectory": Localization.shared.directory.path,
            "localizationWarnings": Localization.shared.warnings,
            "bundlePath": Bundle.main.bundlePath, "enabled": settings.enabled,
            "requireAuthentication": settings.requireAuthentication,
            "covered": privacy.isCovered, "authenticationVisible": privacy.isAuthenticating,
            "iconAction": settings.iconAction.rawValue,
            "shortcut": settings.shortcut.displayName,
            "shortcutKeyCode": settings.shortcut.keyCode, "shortcutModifiers": settings.shortcut.modifiers,
            "intervalMinutes": settings.intervalMinutes,
            "awakeAssertion": sleepPrevention.isRunning,
            "awakeEnabled": settings.awake.enabled, "keepDisplayOn": settings.awake.keepDisplayOn,
            "awakeTimerEnabled": settings.awake.timerEnabled, "awakeDurationMinutes": settings.awake.durationMinutes,
            "coverStatus": coverStatusText, "awakeStatus": awakeStatusText,
            "shortcutStatus": shortcut?.registrationStatus ?? -1,
            "sessionAvailable": sessionAvailable,
            "launchAtLogin": LaunchAtLogin.state.rawValue,
            "automaticallyChecksForUpdates": updates?.automaticallyChecks == true,
            "updateSessionInProgress": updates?.blocksBlackout == true
        ]
        if let next = schedule.nextCover, idleTimer != nil { state["nextCover"] = ISO8601DateFormatter().string(from: next) }
        if let deadline = settings.awake.expiresAt { state["awakeExpiresAt"] = ISO8601DateFormatter().string(from: deadline) }
        if let pid = sleepPrevention.processIdentifier { state["caffeinatePID"] = pid }
        guard let data = try? JSONSerialization.data(withJSONObject: state, options: [.prettyPrinted, .sortedKeys]),
              data != lastStatusData else { return }
        do {
            try FileManager.default.createDirectory(at: statusURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: statusURL, options: .atomic)
            lastStatusData = data
        } catch { log.error("Could not write local status: \(error.localizedDescription)") }
    }

    func applicationWillTerminate(_ notification: Notification) {
        terminating = true
        idleTimer?.invalidate(); awakeTimer?.invalidate()
        terminationSignal?.cancel()
        settingsAuthentication?.invalidate(); settingsAuthentication = nil
        privacy.shutdown()
        sleepPrevention.stop()
        schedule.reset()
        shortcut = nil
        writeStatus(running: false)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard privacy.isLocked, !systemTerminating else { return .terminateNow }
        quitAfterUnlock = true
        privacy.requestUnlock()
        return .terminateCancel
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.setActivationPolicy(.accessory)
app.delegate = delegate
app.run()
