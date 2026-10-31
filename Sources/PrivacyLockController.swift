import AppKit
import Carbon

/// A local privacy lock for ordinary desk input. The desktop stays available to
/// synthetic input and capture. This is not a replacement for the macOS lock.
final class PrivacyLockController {
    private let blackout = DisplayBlackout()
    private let input = PhysicalInputFilter()
    private let password: UnlockPassword
    private var windows: [NSWindow] = []
    private var dots: [NSTextField] = []
    private var messages: [NSTextField] = []
    private var buffer = ""
    private var promptDeadline: Date?
    private var retryAfter: Date?
    private var failedAttempts = 0
    private var systemLockRequired = false
    private var passwordRequired = true
    var dismissOnMouseMove = true
    private var animationTimer: Timer?
    private var promptGroups: [NSView] = []
    private var promptLabels: [NSTextField] = []
    private var animationStarted: TimeInterval = 0
    private var checking = false
    private var generation = 0
    private var suspended = false
    private var reportedFailure = false
    private(set) var isCovered = false
    var isLocked: Bool { isCovered && passwordRequired }
    var isShowingPrompt: Bool { !windows.isEmpty }
    var isInputBlocked: Bool { input.isActive }
    var onChange: (() -> Void)?
    var onError: ((String) -> Void)?
    var onUnlock: (() -> Void)?

    init(password: UnlockPassword = UnlockPassword()) { self.password = password }

    func start(requirePassword: Bool = true) throws {
        guard !isCovered else { requestUnlock(); return }
        if requirePassword, try !password.hasPassword() { throw DisplayBlackout.Failure(message: tr("privacy.noPassword")) }
        passwordRequired = requirePassword
        input.onPhysicalKey = { [weak self] key, chars, flags in self?.receiveKey(key, characters: chars, flags: flags) }
        input.onPhysicalClick = { [weak self] in self?.requestUnlock() }
        input.onPhysicalMove = { [weak self] in
            guard let self, !self.passwordRequired, self.dismissOnMouseMove else { return }
            self.requestUnlock()
        }
        try input.start()
        do { try blackout.begin() }
        catch { input.stop(); throw error }
        isCovered = true
        suspended = false
        reportedFailure = false
        failedAttempts = 0
        systemLockRequired = false
        retryAfter = nil
        generation += 1
        onChange?()
    }

    /// Protected UI entry points reveal the prompt; ordinary blackout dismisses.
    func requestUnlock() {
        guard isCovered, !suspended else { return }
        guard passwordRequired else { shutdown(); onUnlock?(); return }
        if systemLockRequired { _ = Self.lockMac() }
        if windows.isEmpty { buildPrompt() }
        promptDeadline = Date().addingTimeInterval(15)
        refreshPrompt()
    }

    func tick() {
        guard isCovered, !suspended else { return }
        do {
            if !input.isActive { try input.start() }
            try blackout.refresh()
        } catch { handleFailure(error.localizedDescription) }
        if let deadline = promptDeadline, Date() >= deadline, !checking { hidePrompt() }
        if isShowingPrompt { refreshPrompt() }
    }

    func refreshScreens() {
        guard isCovered, !suspended else { return }
        do { try blackout.refresh() }
        catch { handleFailure(error.localizedDescription) }
        if isShowingPrompt { removePromptWindows(); buildPrompt() }
    }

    /// Release interception while macOS owns a sleeping/inactive session, so its
    /// login UI remains usable. Resume this app's lock when the session returns.
    func suspend() {
        guard isCovered else { return }
        suspended = true
        generation += 1; checking = false; buffer = ""
        input.stop()
        let errors = blackout.end()
        removePromptWindows()
        if !errors.isEmpty { onError?(errors.joined(separator: "\n")) }
        onChange?()
    }

    func resume() {
        guard isCovered, suspended else { return }
        do {
            try input.start()
            try blackout.begin()
            suspended = false
            reportedFailure = false
        } catch { handleFailure(error.localizedDescription) }
        onChange?()
    }

    /// Called only after macOS reports a locked-to-unlocked transition.
    func systemDidUnlock() {
        if systemLockRequired {
            systemLockRequired = false
            failedAttempts = 0
            retryAfter = nil
        }
    }

    /// Teardown and unprotected dismissal. Protected UI paths must authenticate.
    func shutdown() {
        generation += 1
        isCovered = false
        suspended = false
        checking = false
        buffer = ""
        let errors = blackout.end()
        removePromptWindows()
        input.stop()
        if !errors.isEmpty { onError?(errors.joined(separator: "\n")) }
        onChange?()
    }

    private func receiveKey(_ code: UInt16, characters: String?, flags: UInt64) {
        guard isCovered, !suspended else { return }
        guard passwordRequired else { requestUnlock(); return }
        if code == 53 { hidePrompt(); return }
        requestUnlock()
        guard !checking, !systemLockRequired, retryAfter.map({ Date() >= $0 }) ?? true else { return }
        switch code {
        case 36, 76: verify()
        case 51, 117:
            if !buffer.isEmpty { buffer.removeLast() }
        default:
            let modifiers = CGEventFlags(rawValue: flags)
            guard modifiers.intersection([.maskCommand, .maskControl, .maskAlternate]).isEmpty else { return }
            // Use an ASCII-capable layout without changing the user's input source.
            // A Korean IME's composition is not available in a global event tap.
            let typed = Self.asciiCharacter(keycode: code, flags: modifiers) ?? characters ?? ""
            if !typed.isEmpty, typed.utf8.allSatisfy({ (32...126).contains($0) }), buffer.utf8.count + typed.utf8.count <= 128 {
                buffer += typed
            }
        }
        refreshPrompt()
    }

    private func verify() {
        guard !buffer.isEmpty else { return }
        let attempt = buffer
        buffer = ""
        checking = true
        let token = generation
        refreshPrompt()
        DispatchQueue.global(qos: .userInitiated).async { [password, weak self] in
            let result = Result { try password.verify(attempt) }
            DispatchQueue.main.async {
                guard let self, self.isLocked, self.generation == token else { return }
                self.checking = false
                switch result {
                case .success(true):
                    self.shutdown()
                    self.onUnlock?()
                case .success(false):
                    self.failedAttempts += 1
                    if self.failedAttempts >= 7 {
                        self.systemLockRequired = true
                        if !Self.lockMac() { self.onError?(tr("privacy.systemLockFailed")) }
                    } else if self.failedAttempts >= 3 {
                        let seconds = 60 * (1 << (self.failedAttempts - 3))
                        self.retryAfter = Date().addingTimeInterval(TimeInterval(seconds))
                    }
                    self.messages.forEach { $0.stringValue = tr("privacy.wrongPassword") }
                    self.promptDeadline = Date().addingTimeInterval(15)
                    self.refreshPrompt()
                case .failure:
                    self.messages.forEach { $0.stringValue = tr("privacy.passwordUnavailable") }
                }
            }
        }
    }

    private func buildPrompt() {
        guard windows.isEmpty else { return }
        for screen in NSScreen.screens {
            let window = PrivacyPromptWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
            window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
            window.backgroundColor = .black
            window.isOpaque = true
            window.hasShadow = false
            window.ignoresMouseEvents = true
            window.isReleasedWhenClosed = false
            window.title = tr("privacy.title")
            let content = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
            let group = NSView(frame: NSRect(x: 0, y: 0, width: min(540, screen.frame.width - 40), height: 230))
            content.addSubview(group)
            promptGroups.append(group)
            let middle = group.bounds.midY
            func label(_ text: String, y: CGFloat, size: CGFloat) -> NSTextField {
                let field = NSTextField(wrappingLabelWithString: text)
                field.alignment = .center
                field.font = .systemFont(ofSize: size)
                field.textColor = .white
                field.frame = NSRect(x: 10, y: y, width: group.bounds.width - 20, height: 55)
                group.addSubview(field)
                promptLabels.append(field)
                return field
            }
            _ = label(tr("privacy.title"), y: middle + 50, size: 22)
            _ = label(tr("privacy.unlockHint"), y: middle, size: 13)
            let masked = label("", y: middle - 55, size: 24)
            masked.setAccessibilityLabel(tr("privacy.password"))
            dots.append(masked)
            messages.append(label("", y: middle - 105, size: 13))
            window.contentView = content
            windows.append(window)
            window.orderFrontRegardless()
        }
        animationStarted = ProcessInfo.processInfo.systemUptime
        animatePrompt()
        let timer = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in self?.animatePrompt() }
        RunLoop.main.add(timer, forMode: .common)
        animationTimer = timer
        // Curtain uses the same ordering: opaque windows first, then restore the
        // output ramp. Captures see this prompt while it is visible (documented).
        do { try blackout.pause() }
        catch { handleFailure(error.localizedDescription) }
        onChange?()
    }

    private func animatePrompt() {
        let t = ProcessInfo.processInfo.systemUptime - animationStarted
        // Slow, phase-modulated waves vary the path continuously without a
        // physics engine or per-frame random jumps. Keep every line on screen.
        for (index, group) in promptGroups.enumerated() {
            guard let bounds = group.superview?.bounds else { continue }
            let phase = Double(index) * 1.7
            let x = sin(t * 0.043 + 0.8 * sin(t * 0.017) + phase)
            let y = sin(t * 0.037 + 0.7 * sin(t * 0.013) + phase)
            let travelX = max(0, (bounds.width - group.frame.width) / 2 - 32)
            let travelY = max(0, (bounds.height - group.frame.height) / 2 - 32)
            group.setFrameOrigin(NSPoint(x: bounds.midX - group.frame.width / 2 + travelX * x,
                                        y: bounds.midY - group.frame.height / 2 + travelY * y))
        }
        // Silver, platinum, muted champagne and steel blue; all remain legible.
        let palette: [(Double, Double, Double)] = [(0.77, 0.82, 0.88), (0.90, 0.88, 0.81),
                                                   (0.79, 0.70, 0.56), (0.59, 0.72, 0.82)]
        let position = t / 12
        let segment = Int(position) % palette.count
        let fraction = position - floor(position)
        let blend = fraction * fraction * (3 - 2 * fraction)
        let a = palette[segment], b = palette[(segment + 1) % palette.count]
        let color = NSColor(srgbRed: a.0 + (b.0 - a.0) * blend,
                            green: a.1 + (b.1 - a.1) * blend,
                            blue: a.2 + (b.2 - a.2) * blend, alpha: 1)
        promptLabels.forEach { $0.textColor = color }
    }

    private func refreshPrompt() {
        dots.forEach { $0.stringValue = String(repeating: "•", count: buffer.count) }
        if systemLockRequired { messages.forEach { $0.stringValue = tr("privacy.systemLockRequired") } }
        else if checking { messages.forEach { $0.stringValue = tr("privacy.checking") } }
        else if let retryAfter, Date() < retryAfter {
            messages.forEach { $0.stringValue = tr("privacy.retry", ["seconds": String(Int(ceil(retryAfter.timeIntervalSinceNow)))]) }
        } else if retryAfter != nil {
            retryAfter = nil
            messages.forEach { $0.stringValue = "" }
        } else if !buffer.isEmpty {
            messages.forEach { $0.stringValue = "" }
        }
    }

    private func hidePrompt() {
        buffer = ""
        generation += 1
        checking = false
        guard !windows.isEmpty else { return }
        do { try blackout.resume() }
        catch { handleFailure(error.localizedDescription); return }
        removePromptWindows()
        onChange?()
    }

    private func removePromptWindows() {
        windows.forEach { $0.orderOut(nil); $0.close() }
        animationTimer?.invalidate(); animationTimer = nil
        promptGroups.removeAll(); promptLabels.removeAll()
        windows.removeAll(); dots.removeAll(); messages.removeAll()
        promptDeadline = nil
    }

    private func handleFailure(_ message: String) {
        if !passwordRequired {
            shutdown()
            onUnlock?()
            onError?(message)
            return
        }
        guard !reportedFailure else { return }
        reportedFailure = true
        // Never use Curtain's password-free emergency uncover. If the mechanism
        // fails, request the actual macOS lock; an unavailable symbol leaves the
        // existing protection in place and reports the error.
        let lockedBySystem = Self.lockMac()
        onError?(tr("privacy.failure", ["error": message]) + (lockedBySystem ? "" : "\n" + tr("privacy.systemLockFailed")))
    }

    private static func lockMac() -> Bool {
        let path = "/System/Library/PrivateFrameworks/login.framework/Versions/Current/login"
        guard let library = dlopen(path, RTLD_LAZY) else { return false }
        defer { dlclose(library) }
        guard let symbol = dlsym(library, "SACLockScreenImmediate") else { return false }
        let lock = unsafeBitCast(symbol, to: (@convention(c) () -> Int32).self)
        return lock() == 0
    }

    static func asciiCharacter(keycode: UInt16, flags: CGEventFlags) -> String? {
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let property = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let data = unsafeBitCast(property, to: CFData.self)
        guard let bytes = CFDataGetBytePtr(data) else { return nil }
        let layout = UnsafeRawPointer(bytes).assumingMemoryBound(to: UCKeyboardLayout.self)
        var modifiers: UInt32 = 0
        if flags.contains(.maskShift) { modifiers |= UInt32(shiftKey) }
        if flags.contains(.maskAlphaShift) { modifiers |= UInt32(alphaLock) }
        var dead: UInt32 = 0
        var count = 0
        var text = [UniChar](repeating: 0, count: 8)
        let result = UCKeyTranslate(layout, keycode, UInt16(kUCKeyActionDown), modifiers >> 8,
            UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit), &dead, text.count, &count, &text)
        guard result == noErr, count > 0 else { return nil }
        return String(utf16CodeUnits: text, count: count)
    }
}

private final class PrivacyPromptWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
