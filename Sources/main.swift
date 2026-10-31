import AppKit
import OSLog

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let log = Logger(subsystem: "com.tk.agenticnights", category: "App")
    private let cover = CoverController()
    private let sleepPrevention = SleepPrevention()
    private var schedule = VeilSchedule()
    private var userActivity = UserActivity()
    private var idleReady = false
    private var settings = VeilSettings.defaults
    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private var terminationSignal: DispatchSourceSignal?
    private var shortcut: GlobalShortcut?
    private var settingsWindow: SettingsWindow?
    private var observers: [NSObjectProtocol] = []
    private var sessionActive = true
    private var sleeping = false
    private var menuIsOpen = false
    private var lastStatusData: Data?
    private let statusURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/agenticnights/status.json")

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
        cover.hideMenuBar = settings.hideMenuBar
        cover.dismissOnMouseMove = settings.dismissOnMouseMove
        persistSettings()
        installMainMenu()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.autosaveName = "ScreenProtection"
        statusItem.button?.target = self
        statusItem.button?.action = #selector(iconClicked(_:))
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        cover.onChange = { [weak self] in self?.refreshStatus() }
        shortcut = GlobalShortcut(shortcut: settings.shortcut) { [weak self] in self?.toggleCover() }
        observeSystem()
        tick()
        timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer!, forMode: .common)
        log.info("Started. Interval: \(self.settings.intervalMinutes) minutes.")
        if firstLaunch { showSettings() }
    }

    @objc private func iconClicked(_ button: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let opensMenu = event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true ||
            event?.modifierFlags.contains(.option) == true
        guard opensMenu else {
            var updated = settings
            updated.toggleIconFeatures()
            applySettings(updated)
            return
        }
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.minY - 4), in: button)
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
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification] {
            observers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.sleeping = true
                self?.suspend()
            })
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification] {
            observers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.sleeping = false
                self?.schedule.reset()
                self?.userActivity.reset()
                self?.tick()
            })
        }
        observers.append(workspace.addObserver(forName: NSWorkspace.sessionDidResignActiveNotification,
            object: nil, queue: .main) { [weak self] _ in self?.sessionActive = false; self?.suspend() })
        observers.append(workspace.addObserver(forName: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil, queue: .main) { [weak self] _ in
                self?.sessionActive = true; self?.schedule.reset(); self?.userActivity.reset(); self?.tick()
            })
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
                self?.cover.refreshScreens()
            })
    }

    private func suspend() {
        cover.hide(restorePrevious: false)
        schedule.reset()
        idleReady = false
        sleepPrevention.stop()
        refreshStatus()
    }

    func applicationDidResignActive(_ notification: Notification) {
        cover.hide(restorePrevious: false)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }

    private func tick() {
        guard sessionActive, !sleeping else { return }
        let now = Date()
        let idleSeconds = userActivity.idleSeconds()
        idleReady = isIdleReady(idleSeconds, settings: settings) &&
            settingsWindow?.window?.isVisible != true && !menuIsOpen
        let wasActive = schedule.active
        let due = schedule.tick(now: now, settings: settings, idleSeconds: idleSeconds)
        if wasActive && !schedule.active { cover.hide(restorePrevious: true) }
        updateAwake(now: now)
        if due && idleReady && !cover.isCovered { showCover() }
        refreshStatus()
    }

    private func updateAwake(now: Date) {
        let previous = settings.awake
        let active = settings.awake.update(at: now, idleReady: idleReady)
        if settings.awake != previous { persistSettings() }
        if sessionActive && !sleeping && active { sleepPrevention.start() }
        else { sleepPrevention.stop() }
    }

    private var coverStatusText: String {
        if cover.isCovered { return tr("status.covered") }
        if !settings.enabled { return tr("status.off") }
        if !sessionActive || sleeping { return tr("status.paused") }
        if !schedule.active { return tr("status.outsideSchedule") }
        if let next = schedule.nextCover {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            return tr("status.nextCover", ["time": formatter.string(from: next)])
        }
        return tr("status.on")
    }

    private var awakeStatusText: String {
        if !settings.awake.enabled { return tr("status.off") }
        if !sessionActive || sleeping { return tr("status.paused") }
        if !settings.awake.isWithinSchedule(at: Date()) { return tr("status.outsideSchedule") }
        if let error = sleepPrevention.lastError { return tr("status.error", ["error": error]) }
        if !idleReady { return tr("status.waitingForIdle") }
        if let deadline = settings.awake.expiresAt {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            return tr("status.stopsAt", ["time": formatter.string(from: deadline)])
        }
        return sleepPrevention.isRunning ? tr("status.on") : tr("status.waiting")
    }

    private var statusText: String {
        tr("status.summary", ["cover": coverStatusText, "awake": awakeStatusText])
    }

    private func refreshStatus() {
        guard let button = statusItem?.button else { return }
        let enabled = settings.iconFeaturesEnabled
        button.image = NSImage(systemSymbolName: enabled ? "moon.fill" : "moon",
                               accessibilityDescription: "agenticnights")
        button.image?.isTemplate = true
        button.appearsDisabled = !enabled
        let action = tr("icon.action", ["features": settings.iconAction.title])
        button.toolTip = tr("status.tooltip", ["status": statusText]) + "\n" + action + " · " + tr("icon.menuHint")
        button.setAccessibilityLabel("agenticnights · " + action)
        settingsWindow?.updateStatus(statusText, settings: settings)
        writeStatus()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        for title in [tr("status.coverHeading", ["status": coverStatusText]),
                      tr("status.awakeHeading", ["status": awakeStatusText])] {
            let heading = menu.addItem(withTitle: title, action: nil, keyEquivalent: "")
            heading.isEnabled = false
        }
        menu.addItem(.separator())
        let enable = menu.addItem(withTitle: tr("settings.enableCover"), action: #selector(toggleEnabled), keyEquivalent: "")
        enable.target = self
        enable.state = settings.enabled ? .on : .off
        let awake = menu.addItem(withTitle: tr("settings.enableAwake"), action: #selector(toggleAwakeEnabled), keyEquivalent: "")
        awake.target = self
        awake.state = settings.awake.enabled ? .on : .off
        let interval = menu.addItem(withTitle: tr("menu.idleDelay", ["minutes": String(settings.intervalMinutes)]), action: nil, keyEquivalent: "")
        let intervals = NSMenu()
        intervals.autoenablesItems = false
        for minutes in [5, 10, 15, 30, 60] {
            let item = intervals.addItem(withTitle: tr("menu.minutes", ["minutes": String(minutes)]), action: #selector(setInterval(_:)), keyEquivalent: "")
            item.target = self
            item.tag = minutes
            item.state = settings.intervalMinutes == minutes ? .on : .off
        }
        intervals.addItem(.separator())
        let custom = intervals.addItem(withTitle: tr("menu.customIdleDelay"), action: #selector(showSettings), keyEquivalent: "")
        custom.target = self
        interval.submenu = intervals
        let movement = menu.addItem(withTitle: tr("menu.dismissOnMouseMove"), action: #selector(toggleMouseMove), keyEquivalent: "")
        movement.target = self
        movement.state = settings.dismissOnMouseMove ? .on : .off
        let timerItem = menu.addItem(withTitle: tr("menu.awakeTimer"), action: nil, keyEquivalent: "")
        let timers = NSMenu()
        timers.autoenablesItems = false
        for minutes in [0, 30, 60, 120] {
            let item = timers.addItem(withTitle: minutes == 0 ? tr("menu.noTimer") : tr("menu.timerMinutes", ["minutes": String(minutes)]), action: #selector(setAwakeTimer(_:)), keyEquivalent: "")
            item.target = self
            item.tag = minutes
            item.state = (minutes == 0 ? !settings.awake.timerEnabled : settings.awake.timerEnabled && settings.awake.durationMinutes == minutes) ? .on : .off
        }
        timerItem.submenu = timers
        menu.addItem(.separator())
        let now = menu.addItem(withTitle: tr(cover.isCovered ? "menu.uncover" : "menu.cover"), action: #selector(toggleCover), keyEquivalent: "")
        now.target = self
        let shortcutItem = menu.addItem(withTitle: tr("menu.shortcut", ["shortcut": settings.shortcut.displayName]), action: #selector(showSettings), keyEquivalent: "")
        shortcutItem.target = self
        if shortcut?.registrationStatus != noErr {
            let warning = menu.addItem(withTitle: tr("menu.shortcutUnavailable"), action: nil, keyEquivalent: "")
            warning.isEnabled = false
        }
        menu.addItem(.separator())
        let preferences = menu.addItem(withTitle: tr("menu.settings"), action: #selector(showSettings), keyEquivalent: ",")
        preferences.target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: tr("menu.quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }

    func menuWillOpen(_ menu: NSMenu) { menuIsOpen = true }
    func menuDidClose(_ menu: NSMenu) { menuIsOpen = false }

    @objc private func setInterval(_ sender: NSMenuItem) {
        var updated = settings
        updated.intervalMinutes = sender.tag
        applySettings(updated)
    }

    @objc private func setAwakeTimer(_ sender: NSMenuItem) {
        var updated = settings
        updated.awake.timerEnabled = sender.tag != 0
        if sender.tag > 0 { updated.awake.durationMinutes = sender.tag }
        applySettings(updated)
    }

    @objc private func toggleMouseMove() {
        var updated = settings
        updated.dismissOnMouseMove.toggle()
        applySettings(updated)
    }

    @objc private func toggleEnabled() {
        var updated = settings
        updated.enabled.toggle()
        applySettings(updated)
    }

    @objc private func toggleAwakeEnabled() {
        var updated = settings
        updated.awake.enabled.toggle()
        applySettings(updated)
    }

    @objc private func showCover() {
        settingsWindow?.close()
        cover.show()
        schedule.didCover(at: Date(), settings: settings)
        refreshStatus()
        log.info("Cover shown on \(self.cover.windows.count) display(s).")
    }

    @objc private func hideCover() { cover.hide(restorePrevious: true) }

    @objc private func toggleCover() {
        if cover.isCovered { hideCover() }
        else { showCover() }
    }

    @objc private func showSettings() {
        cover.hide(restorePrevious: false)
        if settingsWindow == nil {
            settingsWindow = SettingsWindow()
            settingsWindow?.onSave = { [weak self] edited, baseline in
                self?.applySettingsEdits(edited, baseline: baseline)
            }
            settingsWindow?.onRecordingChanged = { [weak self] recording in
                guard let self else { return }
                if recording { self.shortcut?.suspend() }
                else { self.shortcut?.resume(self.settings.shortcut); self.refreshStatus() }
            }
        }
        settingsWindow?.present(settings: settings, status: statusText)
    }

    private func applySettingsEdits(_ edited: VeilSettings, baseline: VeilSettings) -> String? {
        // Keep live menu changes and timer expiry when their controls were not edited.
        var result = settings
        func merge<Value: Equatable>(_ key: WritableKeyPath<VeilSettings, Value>) {
            if edited[keyPath: key] != baseline[keyPath: key] {
                result[keyPath: key] = edited[keyPath: key]
            }
        }
        merge(\.enabled)
        merge(\.intervalMinutes)
        merge(\.scheduleEnabled)
        merge(\.startMinute)
        merge(\.endMinute)
        merge(\.hideMenuBar)
        merge(\.dismissOnMouseMove)
        merge(\.shortcut)
        merge(\.iconAction)
        merge(\.awake.enabled)
        merge(\.awake.timerEnabled)
        merge(\.awake.durationMinutes)
        merge(\.awake.scheduleEnabled)
        merge(\.awake.startMinute)
        merge(\.awake.endMinute)
        if result.shortcut != settings.shortcut || shortcut?.registrationStatus != noErr {
            guard shortcut?.replace(with: result.shortcut) == noErr else { return tr("settings.shortcutConflict") }
        }
        applySettings(result)
        return nil
    }

    private func applySettings(_ newSettings: VeilSettings) {
        let old = settings
        settings = newSettings.validated()
        // A cover-only change, or a change to the awake hours, keeps the timer deadline.
        let restartTimer = old.awake.enabled != settings.awake.enabled ||
            old.awake.timerEnabled != settings.awake.timerEnabled ||
            old.awake.durationMinutes != settings.awake.durationMinutes
        settings.awake.expiresAt = restartTimer ? nil : old.awake.expiresAt
        cover.hideMenuBar = settings.hideMenuBar
        cover.dismissOnMouseMove = settings.dismissOnMouseMove
        if !settings.isActive(at: Date()) { cover.hide(restorePrevious: true) }
        if old.enabled != settings.enabled || old.intervalMinutes != settings.intervalMinutes ||
            old.scheduleEnabled != settings.scheduleEnabled || old.startMinute != settings.startMinute ||
            old.endMinute != settings.endMinute {
            schedule.reset()
        }
        persistSettings()
        tick()
        log.info("Settings saved. Cover: \(self.settings.enabled), awake: \(self.settings.awake.enabled).")
    }

    private func persistSettings() {
        if let data = try? JSONEncoder().encode(settings) { UserDefaults.standard.set(data, forKey: "settings") }
    }

    private func writeStatus(running: Bool = true) {
        let displayFrames = cover.windows.map { window -> [String: Any] in
            ["x": window.frame.origin.x, "y": window.frame.origin.y,
             "width": window.frame.width, "height": window.frame.height,
             "level": window.level.rawValue, "visible": window.isVisible]
        }
        var state: [String: Any] = [
            "running": running, "pid": ProcessInfo.processInfo.processIdentifier,
            "uiLanguage": Localization.shared.language,
            "translationDirectory": Localization.shared.directory.path,
            "localizationWarnings": Localization.shared.warnings,
            "bundlePath": Bundle.main.bundlePath, "enabled": settings.enabled,
            "dismissOnMouseMove": settings.dismissOnMouseMove,
            "iconAction": settings.iconAction.rawValue, "iconFeaturesEnabled": settings.iconFeaturesEnabled,
            "shortcut": settings.shortcut.displayName,
            "shortcutKeyCode": settings.shortcut.keyCode, "shortcutModifiers": settings.shortcut.modifiers,
            "intervalMinutes": settings.intervalMinutes, "scheduleEnabled": settings.scheduleEnabled,
            "hideMenuBar": settings.hideMenuBar, "presentationOptions": NSApp.presentationOptions.rawValue,
            "startMinute": settings.startMinute, "endMinute": settings.endMinute,
            "scheduleActive": schedule.active, "covered": cover.isCovered,
            "awakeAssertion": sleepPrevention.isRunning, "windows": displayFrames,
            "idleReady": idleReady,
            "awakeEnabled": settings.awake.enabled, "awakeTimerEnabled": settings.awake.timerEnabled,
            "awakeDurationMinutes": settings.awake.durationMinutes,
            "awakeScheduleEnabled": settings.awake.scheduleEnabled,
            "awakeStartMinute": settings.awake.startMinute, "awakeEndMinute": settings.awake.endMinute,
            "awakeScheduleActive": settings.awake.isActive(at: Date()),
            "coverStatus": coverStatusText, "awakeStatus": awakeStatusText,
            "shortcutStatus": shortcut?.registrationStatus ?? -1,
            "status": statusText
        ]
        if let next = schedule.nextCover { state["nextCover"] = ISO8601DateFormatter().string(from: next) }
        if let deadline = settings.awake.expiresAt {
            state["awakeExpiresAt"] = ISO8601DateFormatter().string(from: deadline)
        }
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
        timer?.invalidate()
        terminationSignal?.cancel()
        cover.hide(restorePrevious: false)
        sleepPrevention.stop()
        schedule.reset()
        shortcut = nil
        writeStatus(running: false)
        log.info("Stopped.")
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.setActivationPolicy(.accessory)
app.delegate = delegate
app.run()
