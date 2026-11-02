import AppKit
import LocalAuthentication

/// Hides physical display output while keeping the desktop available to agents.
/// All lifecycle methods and callbacks run on the main thread.
final class PrivacyLockController {
    private let blackout = DisplayBlackout()
    private let brightness = DisplayBrightness()
    private let keyboard = KeyboardBacklight()
    private var keyboardDimming = true
    private let input = PhysicalClickMonitor()
    private var windows: [NSWindow] = []
    private var context: LAContext?
    private var authenticationGeneration = 0
    private var frontApplication: NSRunningApplication?
    private var activationObserver: NSObjectProtocol?
    private var resignationObserver: NSObjectProtocol?
    private var voiceOverObservation: NSKeyValueObservation?
    private var refreshWork: [DispatchWorkItem] = []
    private var refreshGeneration = 0
    private var suspended = false
    private var authenticationRequired = false
    private var reportedFailure = false
    private(set) var isCovered = false
    private(set) var isAuthenticating = false
    var isLocked: Bool { isCovered && authenticationRequired }
    var onPhysicalClick: ((NSEvent) -> Void)?
    var onChange: (() -> Void)?
    var onError: ((String) -> Void)?
    var onUnlock: (() -> Void)?
    var onAuthenticationCancelled: (() -> Void)?

    func start(requireAuthentication: Bool, dimKeyboard: Bool = true) throws {
        guard !isCovered else { requestUnlock(); return }
        input.onClick = { [weak self] event in
            self?.onPhysicalClick?(event)
            self?.requestUnlock()
        }
        try input.start()
        do { try blackout.begin() }
        catch { input.stop(); throw error }
        keyboardDimming = dimKeyboard
        brightness.begin()
        if keyboardDimming { keyboard.begin() }
        authenticationRequired = requireAuthentication
        isCovered = true
        suspended = false
        reportedFailure = false
        observeVoiceOver()
        onChange?()
    }

    func setKeyboardDimming(_ enabled: Bool) {
        keyboardDimming = enabled
        if enabled && isCovered && !suspended && !isAuthenticating { keyboard.begin() }
        else { keyboard.end() }
    }

    func requestUnlock() {
        guard isCovered, !suspended, !isAuthenticating else { return }
        guard authenticationRequired else { shutdown(); onUnlock?(); return }
        let authentication = LAContext()
        var error: NSError?
        guard authentication.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            authentication.invalidate()
            let message = (error ?? LAError(.passcodeNotSet) as NSError).localizedDescription
            // An account without a login password can never authenticate, so
            // nothing could end blackout or quit the app. End it and report.
            // Other failures keep blackout; they are not a permanent condition.
            if Self.isPasscodeNotSet(error) {
                shutdown()
                onUnlock?()
            } else {
                onAuthenticationCancelled?()
            }
            onError?(message)
            return
        }
        cancelRefreshes()
        authenticationGeneration += 1
        let generation = authenticationGeneration
        context = authentication
        isAuthenticating = true
        frontApplication = NSWorkspace.shared.frontmostApplication
        observeAuthenticationFocus()
        NSApp.activate(ignoringOtherApps: true)
        buildAuthenticationBackdrop()
        do {
            // Opaque windows are on screen before gamma or backlight is restored.
            try blackout.pause()
            brightness.end()
            keyboard.end()
        } catch {
            cancelAuthentication()
            handleFailure(error.localizedDescription)
            return
        }
        onChange?()
        authentication.evaluatePolicy(.deviceOwnerAuthentication,
                                      localizedReason: tr("blackout.authReason")) { [weak self] success, _ in
            DispatchQueue.main.async {
                guard let self, self.isAuthenticating,
                      self.authenticationGeneration == generation else { return }
                if success {
                    let previous = self.frontApplication
                    self.frontApplication = nil
                    self.shutdown()
                    self.restoreFrontApplication(previous)
                    self.onUnlock?()
                } else {
                    self.cancelAuthentication()
                }
            }
        }
    }

    /// Returns why macOS account authentication cannot run, or nil if it can.
    static func authenticationUnavailableReason() -> String? {
        let context = LAContext()
        defer { context.invalidate() }
        var error: NSError?
        guard !context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return nil }
        return (error ?? LAError(.passcodeNotSet) as NSError).localizedDescription
    }

    /// An account without a login password can never pass account authentication.
    static func isPasscodeNotSet(_ error: NSError?) -> Bool {
        error?.domain == LAErrorDomain && error?.code == LAError.Code.passcodeNotSet.rawValue
    }

    /// Configuration changes invalidate the current system prompt. Reapply now
    /// and after the display driver has had time to finish its reconfiguration.
    func refreshScreens() {
        guard isCovered, !suspended else { return }
        cancelRefreshes()
        cancelAuthentication()
        guard isCovered, !suspended else { return }
        refreshDisplays()
        guard isCovered, !suspended else { return }
        let generation = refreshGeneration
        for delay in [5.0, 10.0] {
            let work = DispatchWorkItem { [weak self] in
                guard let self, self.refreshGeneration == generation,
                      self.isCovered, !self.suspended, !self.isAuthenticating else { return }
                self.refreshDisplays()
            }
            refreshWork.append(work)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        }
    }

    /// Keep blackout intent while macOS owns a sleeping, locked or inactive
    /// session; restore display output so the system's login UI remains usable.
    func suspend() {
        guard isCovered, !suspended else { return }
        suspended = true
        cancelRefreshes()
        let wasAuthenticating = invalidateAuthentication()
        frontApplication = nil
        stopObservingVoiceOver()
        input.stop()
        let errors = blackout.end()
        brightness.end()
        keyboard.end()
        removeBackdrop()
        if wasAuthenticating { onAuthenticationCancelled?() }
        if !errors.isEmpty { onError?(errors.joined(separator: "\n")) }
        onChange?()
    }

    func resume() {
        guard isCovered, suspended else { return }
        do {
            try input.start()
            try blackout.begin()
            brightness.begin()
            if keyboardDimming { keyboard.begin() }
            suspended = false
            reportedFailure = false
            observeVoiceOver()
            refreshScreens()
        } catch {
            input.stop()
            handleFailure(error.localizedDescription)
        }
        onChange?()
    }

    /// Direct teardown is reserved for successful authentication, ordinary
    /// dismissal and system shutdown. Protected user requests use requestUnlock.
    func shutdown() {
        cancelRefreshes()
        _ = invalidateAuthentication()
        frontApplication = nil
        stopObservingVoiceOver()
        input.stop()
        isCovered = false
        suspended = false
        let errors = blackout.end()
        brightness.end()
        keyboard.end()
        removeBackdrop()
        if !errors.isEmpty { onError?(errors.joined(separator: "\n")) }
        onChange?()
    }

    private func cancelAuthentication() {
        guard isAuthenticating || !windows.isEmpty else { return }
        let wasAuthenticating = invalidateAuthentication()
        let previous = frontApplication
        frontApplication = nil
        do {
            // Never expose the desktop between the system prompt and blackout.
            try blackout.resume()
            try blackout.refresh()
            brightness.begin()
            if keyboardDimming { keyboard.begin() }
            removeBackdrop()
        } catch {
            // Keep opaque windows if blackening failed; the system lock provides
            // the recovery path, without pretending authentication succeeded.
            handleFailure(error.localizedDescription)
        }
        restoreFrontApplication(previous)
        if wasAuthenticating { onAuthenticationCancelled?() }
        onChange?()
    }

    @discardableResult
    private func invalidateAuthentication() -> Bool {
        let wasAuthenticating = isAuthenticating
        authenticationGeneration += 1
        isAuthenticating = false
        context?.invalidate()
        context = nil
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
            self.activationObserver = nil
        }
        if let resignationObserver {
            NotificationCenter.default.removeObserver(resignationObserver)
            self.resignationObserver = nil
        }
        return wasAuthenticating
    }

    private func observeAuthenticationFocus() {
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] notification in
            guard let self, self.isAuthenticating,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  !self.isAuthenticationApplication(app) else { return }
            self.cancelAuthentication()
        }
        resignationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification, object: NSApp, queue: .main
        ) { [weak self] _ in
            // Workspace frontmostApplication settles after the AppKit notice.
            // LA's own UI agent can take focus and must not cancel its prompt.
            let generation = self?.authenticationGeneration
            DispatchQueue.main.async {
                guard let self, self.isAuthenticating,
                      self.authenticationGeneration == generation,
                      let app = NSWorkspace.shared.frontmostApplication,
                      !self.isAuthenticationApplication(app) else { return }
                self.cancelAuthentication()
            }
        }
    }

    private func isAuthenticationApplication(_ app: NSRunningApplication) -> Bool {
        if app.processIdentifier == ProcessInfo.processInfo.processIdentifier { return true }
        // These Apple agents host the system Touch ID / login-password dialog.
        // Require a system bundle as well as its identifier.
        guard app.bundleURL?.path.hasPrefix("/System/Library/") == true else { return false }
        return app.bundleIdentifier == "com.apple.LocalAuthentication.UIAgent"
            || app.bundleIdentifier == "com.apple.SecurityAgent"
    }

    private func restoreFrontApplication(_ app: NSRunningApplication?) {
        guard !suspended, let app, !app.isTerminated,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
        app.activate(options: [])
    }

    private func buildAuthenticationBackdrop() {
        guard windows.isEmpty else { return }
        for screen in NSScreen.screens {
            let window = AuthenticationBackdrop(contentRect: screen.frame, styleMask: .borderless,
                                                 backing: .buffered, defer: false)
            // Cover normal app windows and the menu bar. System authentication
            // must remain above this level; verify that on the target macOS.
            // The old maximum-level window would hide the authentication UI.
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
            window.backgroundColor = .black
            window.isOpaque = true
            window.hasShadow = false
            window.ignoresMouseEvents = true
            window.isReleasedWhenClosed = false
            windows.append(window)
            window.orderFrontRegardless()
        }
    }

    private func removeBackdrop() {
        windows.forEach { $0.orderOut(nil); $0.close() }
        windows.removeAll()
    }

    private func observeVoiceOver() {
        stopObservingVoiceOver()
        voiceOverObservation = NSWorkspace.shared.observe(\.isVoiceOverEnabled, options: [.new]) { [weak self] _, _ in
            if Thread.isMainThread { self?.voiceOverChanged() }
            else { DispatchQueue.main.async { self?.voiceOverChanged() } }
        }
        voiceOverChanged()
    }

    private func stopObservingVoiceOver() {
        voiceOverObservation?.invalidate()
        voiceOverObservation = nil
    }

    private func voiceOverChanged() {
        guard isCovered, !suspended, NSWorkspace.shared.isVoiceOverEnabled else { return }
        if Self.lockMac() { suspend() }
        else { onError?(tr("error.lock")) }
    }

    private func refreshDisplays() {
        guard isCovered, !suspended, !isAuthenticating else { return }
        do { try blackout.refresh(); brightness.refresh(); keyboard.refresh() }
        catch { handleFailure(error.localizedDescription) }
    }

    private func cancelRefreshes() {
        refreshGeneration += 1
        refreshWork.forEach { $0.cancel() }
        refreshWork.removeAll()
    }

    private func handleFailure(_ message: String) {
        if !authenticationRequired {
            shutdown()
            onUnlock?()
            onError?(message)
            return
        }
        guard !reportedFailure else { return }
        reportedFailure = true
        let lockedBySystem = Self.lockMac()
        if lockedBySystem { suspend() }
        onError?(message + (lockedBySystem ? "" : "\n" + tr("error.lock")))
    }

    private static func lockMac() -> Bool {
        let path = "/System/Library/PrivateFrameworks/login.framework/Versions/Current/login"
        guard let library = dlopen(path, RTLD_LAZY) else { return false }
        defer { dlclose(library) }
        guard let symbol = dlsym(library, "SACLockScreenImmediate") else { return false }
        let lock = unsafeBitCast(symbol, to: (@convention(c) () -> Int32).self)
        return lock() == 0
    }

    deinit {
        refreshWork.forEach { $0.cancel() }
        context?.invalidate()
        if let activationObserver { NSWorkspace.shared.notificationCenter.removeObserver(activationObserver) }
        if let resignationObserver { NotificationCenter.default.removeObserver(resignationObserver) }
        voiceOverObservation?.invalidate()
        input.stop()
        brightness.end()
        keyboard.end()
        blackout.end()
        windows.forEach { $0.close() }
    }
}

private final class AuthenticationBackdrop: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
