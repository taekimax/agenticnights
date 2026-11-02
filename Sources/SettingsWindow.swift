import AppKit

extension IconAction {
    var title: String { tr("icon.\(rawValue)") }
}

private final class SettingsDocumentView: NSView {
    override var isFlipped: Bool { true }
}

final class SettingsWindow: NSWindowController, NSWindowDelegate, NSTextFieldDelegate {
    enum Focus { case delay, duration }

    private let enabledButton = NSButton(checkboxWithTitle: tr("blackout.auto"), target: nil, action: nil)
    private let keyboardButton = NSButton(checkboxWithTitle: tr("blackout.keyboard"), target: nil, action: nil)
    private let keyboardSupported: Bool
    private let intervalField = NSTextField(string: "10")
    private let protectionButton = NSButton(checkboxWithTitle: tr("blackout.requireAuth"), target: nil, action: nil)
    private let awakeEnabledButton = NSButton(checkboxWithTitle: tr("sleep.enable"), target: nil, action: nil)
    private let displayButton = NSButton(checkboxWithTitle: tr("sleep.display"), target: nil, action: nil)
    private let durationPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let awakeDurationField = NSTextField(string: "60")
    private let durationEntry = NSStackView()
    private let shortcutButton = NSButton()
    private let iconActionPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let statusLabel = NSTextField(wrappingLabelWithString: "")
    private let delayError = NSTextField(wrappingLabelWithString: "")
    private let durationError = NSTextField(wrappingLabelWithString: "")
    private let shortcutError = NSTextField(wrappingLabelWithString: "")
    private let changeError = NSTextField(wrappingLabelWithString: "")
    private var settings = VeilSettings.defaults
    private var dirtyMinutes: Set<Focus> = []
    private var keyMonitor: Any?

    /// Return an error without changing the saved settings when a proposal fails.
    /// The owner may synchronously call updateStatus with its canonical settings.
    var onChange: ((VeilSettings) -> String?)?
    var onRecordingChanged: ((Bool) -> Void)?
    var onClose: (() -> Void)?

    init(keyboardSupported: Bool = KeyboardBacklight.isSupported) {
        self.keyboardSupported = keyboardSupported
        let available = NSScreen.main?.visibleFrame.size ?? NSSize(width: 1024, height: 900)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0,
                                                  width: min(640, available.width - 60),
                                                  height: min(800, available.height - 100)),
                              styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = tr("settings.title")
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: min(560, available.width - 60), height: 400)
        super.init(window: window)
        window.delegate = self
        buildContent()
        window.center()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func present(settings: VeilSettings, status: String, focus: Focus? = nil) {
        if window?.isVisible != true {
            dirtyMinutes.removeAll()
            for label in [delayError, durationError, shortcutError, changeError] { setError("", on: label) }
        }
        updateStatus(status, settings: settings)
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        if let focus {
            // Opening Custom… exposes the entry without changing the saved mode.
            if focus == .duration { durationEntry.isHidden = false }
            let field = focus == .delay ? intervalField : awakeDurationField
            field.scrollToVisible(field.bounds.insetBy(dx: -8, dy: -12))
            window?.makeFirstResponder(field)
            field.selectText(nil)
        }
    }

    func updateStatus(_ text: String, settings: VeilSettings) {
        self.settings = settings
        statusLabel.stringValue = text
        refreshControls()
    }

    private func refreshControls() {
        keyboardButton.state = settings.dimKeyboardBacklight ? .on : .off
        enabledButton.state = settings.enabled ? .on : .off
        protectionButton.state = settings.requireAuthentication ? .on : .off
        awakeEnabledButton.state = settings.awake.enabled ? .on : .off
        displayButton.state = settings.awake.keepDisplayOn ? .on : .off
        durationPopup.selectItem(at: settings.awake.timerEnabled ? 1 : 0)
        iconActionPopup.selectItem(at: IconAction.allCases.firstIndex(of: settings.iconAction) ?? 1)
        if !dirtyMinutes.contains(.delay), intervalField.currentEditor() == nil {
            intervalField.stringValue = String(settings.intervalMinutes)
        }
        if !dirtyMinutes.contains(.duration), awakeDurationField.currentEditor() == nil {
            awakeDurationField.stringValue = String(settings.awake.durationMinutes)
        }
        durationEntry.isHidden = !settings.awake.timerEnabled &&
            !dirtyMinutes.contains(.duration) && awakeDurationField.currentEditor() == nil
        if keyMonitor == nil { updateShortcutTitle() }
    }

    private func buildContent() {
        guard let content = window?.contentView else { return }
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: content.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: content.bottomAnchor)
        ])
        let document = SettingsDocumentView()
        document.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = document
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 22
        stack.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(stack)
        NSLayoutConstraint.activate([
            document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
            stack.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: document.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -24)
        ])
        for field in [intervalField, awakeDurationField] {
            field.alignment = .right
            field.widthAnchor.constraint(equalToConstant: 64).isActive = true
            field.delegate = self
            field.target = self
            field.action = #selector(minutesReturned(_:))
        }
        intervalField.setAccessibilityLabel(tr("blackout.delay"))
        awakeDurationField.setAccessibilityLabel(tr("sleep.duration"))
        for button in [enabledButton, protectionButton, keyboardButton, awakeEnabledButton, displayButton] {
            button.target = self
            button.action = #selector(toggleChanged(_:))
        }
        for label in [delayError, durationError, shortcutError, changeError] {
            label.font = .systemFont(ofSize: 12)
            label.textColor = .systemRed
            label.isHidden = true
        }
        shortcutButton.bezelStyle = .rounded
        shortcutButton.target = self
        shortcutButton.action = #selector(recordShortcut)
        shortcutButton.setAccessibilityLabel(tr("settings.shortcutRecord"))
        let reset = NSButton(title: tr("settings.shortcutReset"), target: self, action: #selector(resetShortcut))
        reset.bezelStyle = .rounded
        durationPopup.addItems(withTitles: [tr("menu.noLimit"), tr("menu.custom")])
        durationPopup.target = self
        durationPopup.action = #selector(durationChanged)
        durationPopup.setAccessibilityLabel(tr("sleep.duration"))
        durationEntry.orientation = .horizontal
        durationEntry.alignment = .centerY
        durationEntry.spacing = 6
        durationEntry.addArrangedSubview(awakeDurationField)
        durationEntry.addArrangedSubview(minutesLabel())
        for action in IconAction.allCases { iconActionPopup.addItem(withTitle: action.title) }
        iconActionPopup.target = self
        iconActionPopup.action = #selector(iconActionChanged)
        iconActionPopup.setAccessibilityLabel(tr("icon.click"))
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor

        keyboardButton.isEnabled = keyboardSupported
        let blackout = section("blackout.title", views: [
            hint("blackout.about"), enabledButton,
            row([NSTextField(labelWithString: tr("blackout.delay")), intervalField, minutesLabel()]),
            delayError, hint("blackout.delayHint"), hint("blackout.end"),
            protectionButton, hint("blackout.requireAuthHint"), hint("blackout.requireAuthOffHint"),
            row([NSTextField(labelWithString: tr("blackout.shortcut")), shortcutButton, reset]),
            shortcutError, hint("blackout.shortcutHint"), hint("settings.shortcutHint"),
            hint("blackout.voiceOver"), hint("blackout.dim"), keyboardButton,
            hint(keyboardSupported ? "blackout.keyboardHint" : "blackout.keyboardUnavailable")
        ])
        let sleep = section("sleep.title", views: [
            awakeEnabledButton, hint("sleep.enableHint"), displayButton, hint("sleep.displayHint"),
            row([NSTextField(labelWithString: tr("sleep.duration")), durationPopup, durationEntry]),
            durationError, hint("sleep.durationHint"),
            row([NSTextField(labelWithString: tr("sleep.status")), statusLabel])
        ])
        let icon = section("icon.title", views: [
            row([NSTextField(labelWithString: tr("icon.click")), iconActionPopup]), hint("icon.hint")
        ])
        for view in [blackout, sleep, icon, changeError] {
            stack.addArrangedSubview(view)
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
    }

    private func minutesLabel() -> NSTextField {
        NSTextField(labelWithString: tr("menu.minutes", ["minutes": ""]).trimmingCharacters(in: .whitespaces))
    }

    private func hint(_ key: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: tr(key))
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        return label
    }

    private func section(_ title: String, views: [NSView]) -> NSStackView {
        let heading = NSTextField(labelWithString: tr(title))
        heading.font = .boldSystemFont(ofSize: 13)
        let stack = NSStackView(views: [heading] + views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 7
        stack.setCustomSpacing(10, after: heading)
        for view in views where view is NSTextField || view is NSStackView {
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        return stack
    }

    private func row(_ views: [NSView]) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        // Keep controls at their intrinsic size; unused width belongs at the end.
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stack.addArrangedSubview(spacer)
        return stack
    }

    private func setError(_ message: String, on label: NSTextField) {
        label.stringValue = message
        label.isHidden = message.isEmpty
    }

    @discardableResult
    private func apply(_ edit: (inout VeilSettings) -> Void, errorLabel: NSTextField? = nil) -> Bool {
        let previous = settings
        var proposal = previous
        edit(&proposal)
        let label = errorLabel ?? changeError
        setError("", on: label)
        guard proposal != previous else { return true }
        settings = proposal
        if let error = onChange?(proposal) {
            settings = previous
            setError(error, on: label)
            refreshControls()
            return false
        }
        refreshControls()
        return true
    }

    @objc private func toggleChanged(_ sender: NSButton) {
        let enabled = sender.state == .on
        apply { settings in
            if sender === enabledButton { settings.enabled = enabled }
            else if sender === keyboardButton { settings.dimKeyboardBacklight = enabled }
            else if sender === protectionButton { settings.requireAuthentication = enabled }
            else if sender === awakeEnabledButton {
                settings.awake.enabled = enabled
                settings.awake.expiresAt = nil
            } else if sender === displayButton { settings.awake.keepDisplayOn = enabled }
        }
    }

    @objc private func durationChanged() {
        let limited = durationPopup.indexOfSelectedItem == 1
        if !limited {
            dirtyMinutes.remove(.duration)
            setError("", on: durationError)
            awakeDurationField.stringValue = String(settings.awake.durationMinutes)
        }
        apply {
            if $0.awake.timerEnabled != limited { $0.awake.expiresAt = nil }
            $0.awake.timerEnabled = limited
        }
        if limited {
            durationEntry.isHidden = false
            window?.makeFirstResponder(awakeDurationField)
            awakeDurationField.selectText(nil)
        }
    }

    @objc private func iconActionChanged() {
        let index = iconActionPopup.indexOfSelectedItem
        guard IconAction.allCases.indices.contains(index) else { return }
        apply { $0.iconAction = IconAction.allCases[index] }
    }

    func controlTextDidChange(_ notification: Notification) {
        guard let field = notification.object as? NSTextField else { return }
        dirtyMinutes.insert(field === intervalField ? .delay : .duration)
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        guard let field = notification.object as? NSTextField else { return }
        commitMinutes(field)
    }

    @objc private func minutesReturned(_ sender: NSTextField) {
        // Custom… may focus the retained duration while No Limit is selected.
        // Return explicitly accepts that value, even without typing a new one.
        dirtyMinutes.insert(sender === intervalField ? .delay : .duration)
        commitMinutes(sender)
    }

    private func commitMinutes(_ field: NSTextField) {
        let focus: Focus = field === intervalField ? .delay : .duration
        guard dirtyMinutes.contains(focus) else { return }
        let label = focus == .delay ? delayError : durationError
        let input = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty, input.allSatisfy({ $0.isASCII && $0.isNumber }),
              let minutes = Int(input), (1...1440).contains(minutes) else {
            setError(tr("error.minutes"), on: label)
            return
        }
        let accepted = apply({ settings in
            if focus == .delay { settings.intervalMinutes = minutes }
            else {
                if !settings.awake.timerEnabled || settings.awake.durationMinutes != minutes {
                    settings.awake.expiresAt = nil
                }
                settings.awake.durationMinutes = minutes
                settings.awake.timerEnabled = true
            }
        }, errorLabel: label)
        if accepted {
            dirtyMinutes.remove(focus)
            field.stringValue = String(minutes)
            refreshControls()
        }
    }

    override func close() {
        window?.makeFirstResponder(nil)
        stopRecording()
        super.close()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.makeFirstResponder(nil)
        return true
    }

    func windowWillClose(_ notification: Notification) {
        stopRecording()
        onClose?()
    }

    func windowDidResignKey(_ notification: Notification) { stopRecording() }

    private func updateShortcutTitle() {
        shortcutButton.title = "\(settings.shortcut.displayName)  \(tr("settings.shortcutRecord"))"
    }

    @objc private func resetShortcut() {
        stopRecording()
        apply({ $0.shortcut = .defaults }, errorLabel: shortcutError)
    }

    @objc private func recordShortcut() {
        if keyMonitor != nil { stopRecording(); return }
        window?.makeFirstResponder(shortcutButton)
        setError("", on: shortcutError)
        shortcutButton.title = tr("settings.shortcutRecording")
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.window?.isKeyWindow == true else { return event }
            if event.keyCode == 53 { self.stopRecording(); return nil }
            let proposed = KeyboardShortcut(event: event)
            guard proposed.isValid else {
                self.setError(tr("settings.shortcutInvalid"), on: self.shortcutError)
                return nil
            }
            // Restore the existing registration before attempting replacement;
            // a rejected proposal must leave that valid shortcut registered.
            self.stopRecording()
            self.apply({ $0.shortcut = proposed }, errorLabel: self.shortcutError)
            return nil
        }
        if keyMonitor != nil { onRecordingChanged?(true) }
        else { updateShortcutTitle() }
    }

    private func stopRecording() {
        guard let keyMonitor else { return }
        NSEvent.removeMonitor(keyMonitor)
        self.keyMonitor = nil
        updateShortcutTitle()
        onRecordingChanged?(false)
    }
}
