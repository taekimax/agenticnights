import AppKit

extension IconAction {
    var title: String { tr("feature.\(rawValue)") }
}

final class SettingsWindow: NSWindowController, NSWindowDelegate {
    private let enabledButton = NSButton(checkboxWithTitle: tr("settings.enableCover"), target: nil, action: nil)
    private let intervalField = NSTextField(string: "10")
    private let scheduleButton = NSButton(checkboxWithTitle: tr("settings.coverSchedule"), target: nil, action: nil)
    private let hideMenuBarButton = NSButton(checkboxWithTitle: tr("settings.hideMenuBar"), target: nil, action: nil)
    private let startPicker = NSDatePicker()
    private let endPicker = NSDatePicker()
    private let awakeEnabledButton = NSButton(checkboxWithTitle: tr("settings.enableAwake"), target: nil, action: nil)
    private let awakeTimerButton = NSButton(checkboxWithTitle: tr("settings.stopAfter"), target: nil, action: nil)
    private let awakeDurationField = NSTextField(string: "60")
    private let awakeScheduleButton = NSButton(checkboxWithTitle: tr("settings.awakeSchedule"), target: nil, action: nil)
    private let awakeStartPicker = NSDatePicker()
    private let awakeEndPicker = NSDatePicker()
    private let iconActionPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let statusLabel = NSTextField(wrappingLabelWithString: "")
    private let errorLabel = NSTextField(wrappingLabelWithString: "")
    private var baseline = VeilSettings.defaults
    var onSave: ((VeilSettings, VeilSettings) -> Void)?

    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 780, height: 600),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = tr("settings.title")
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        window.center()
        buildContent()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func present(settings: VeilSettings, status: String) {
        // Reopening an already-visible settings window must preserve unsaved edits.
        if window?.isVisible != true {
            baseline = settings
            iconActionPopup.selectItem(at: IconAction.allCases.firstIndex(of: settings.iconAction) ?? 2)
            enabledButton.state = settings.enabled ? .on : .off
            intervalField.stringValue = String(settings.intervalMinutes)
            scheduleButton.state = settings.scheduleEnabled ? .on : .off
            hideMenuBarButton.state = settings.hideMenuBar ? .on : .off
            startPicker.dateValue = date(for: settings.startMinute)
            endPicker.dateValue = date(for: settings.endMinute)
            awakeEnabledButton.state = settings.awake.enabled ? .on : .off
            awakeTimerButton.state = settings.awake.timerEnabled ? .on : .off
            awakeDurationField.stringValue = String(settings.awake.durationMinutes)
            awakeScheduleButton.state = settings.awake.scheduleEnabled ? .on : .off
            awakeStartPicker.dateValue = date(for: settings.awake.startMinute)
            awakeEndPicker.dateValue = date(for: settings.awake.endMinute)
            errorLabel.stringValue = ""
            updateScheduleControls()
        }
        statusLabel.stringValue = status
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func updateStatus(_ text: String, settings: VeilSettings) {
        statusLabel.stringValue = text
        // Reflect timer expiry and icon clicks without overwriting unsaved edits.
        if (enabledButton.state == .on) == baseline.enabled {
            enabledButton.state = settings.enabled ? .on : .off
            baseline.enabled = settings.enabled
        }
        if (awakeEnabledButton.state == .on) == baseline.awake.enabled {
            awakeEnabledButton.state = settings.awake.enabled ? .on : .off
            baseline.awake.enabled = settings.awake.enabled
        }
    }

    private func buildContent() {
        guard let content = window?.contentView else { return }
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 24)
        ])
        let title = NSTextField(labelWithString: tr("settings.heading"))
        title.font = .systemFont(ofSize: 20, weight: .semibold)
        stack.addArrangedSubview(title)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.font = .systemFont(ofSize: 12)
        stack.addArrangedSubview(statusLabel)
        statusLabel.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        statusLabel.heightAnchor.constraint(equalToConstant: 36).isActive = true
        for action in IconAction.allCases {
            iconActionPopup.addItem(withTitle: action.title)
            iconActionPopup.lastItem?.representedObject = action.rawValue
        }
        iconActionPopup.setAccessibilityLabel(tr("accessibility.iconAction"))
        stack.addArrangedSubview(row([NSTextField(labelWithString: tr("settings.iconAction")), iconActionPopup]))

        for field in [intervalField, awakeDurationField] {
            field.alignment = .right
            field.widthAnchor.constraint(equalToConstant: 60).isActive = true
        }
        intervalField.setAccessibilityLabel(tr("accessibility.interval"))
        awakeDurationField.setAccessibilityLabel(tr("accessibility.duration"))
        for button in [scheduleButton, awakeScheduleButton, awakeTimerButton] {
            button.target = self
            button.action = #selector(scheduleChanged)
        }
        for picker in [startPicker, endPicker, awakeStartPicker, awakeEndPicker] {
            picker.datePickerStyle = .textFieldAndStepper
            picker.datePickerElements = [.hourMinute]
            picker.locale = .current
        }
        startPicker.setAccessibilityLabel(tr("accessibility.coverStart"))
        endPicker.setAccessibilityLabel(tr("accessibility.coverEnd"))
        awakeStartPicker.setAccessibilityLabel(tr("accessibility.awakeStart"))
        awakeEndPicker.setAccessibilityLabel(tr("accessibility.awakeEnd"))

        let coverBox = section(tr("feature.cover"), views: [
            enabledButton,
            row([NSTextField(labelWithString: tr("settings.interval")), intervalField, NSTextField(labelWithString: tr("settings.minutes"))]),
            scheduleButton,
            row([NSTextField(labelWithString: tr("settings.start")), startPicker]),
            row([NSTextField(labelWithString: tr("settings.end")), endPicker]),
            hideMenuBarButton,
            hint(tr("settings.coverHint"))
        ])
        let awakeBox = section(tr("feature.awake"), views: [
            awakeEnabledButton,
            row([awakeTimerButton, awakeDurationField, NSTextField(labelWithString: tr("settings.minutes"))]),
            awakeScheduleButton,
            row([NSTextField(labelWithString: tr("settings.start")), awakeStartPicker]),
            row([NSTextField(labelWithString: tr("settings.end")), awakeEndPicker]),
            hint(tr("settings.awakeHint"))
        ])
        let columns = NSStackView(views: [coverBox, awakeBox])
        columns.orientation = .horizontal
        columns.alignment = .top
        columns.distribution = .fillEqually
        columns.spacing = 16
        stack.addArrangedSubview(columns)
        columns.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        coverBox.heightAnchor.constraint(equalTo: awakeBox.heightAnchor).isActive = true

        stack.addArrangedSubview(hint(tr("settings.footer")))
        errorLabel.textColor = .systemRed
        errorLabel.font = .systemFont(ofSize: 12)
        stack.addArrangedSubview(errorLabel)
        errorLabel.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        let cancel = NSButton(title: tr("settings.cancel"), target: self, action: #selector(cancelChanges))
        cancel.keyEquivalent = "\u{1b}"
        let save = NSButton(title: tr("settings.apply"), target: self, action: #selector(saveChanges))
        save.bezelStyle = .rounded
        cancel.bezelStyle = .rounded
        save.keyEquivalent = "\r"
        let buttons = row([cancel, save])
        buttons.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(buttons)
        NSLayoutConstraint.activate([
            buttons.topAnchor.constraint(greaterThanOrEqualTo: stack.bottomAnchor, constant: 8),
            buttons.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            buttons.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20)
        ])
    }

    private func hint(_ text: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        return label
    }

    private func section(_ title: String, views: [NSView]) -> NSBox {
        let box = NSBox()
        box.title = title
        box.contentViewMargins = NSSize(width: 14, height: 14)
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        let content = box.contentView!
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor)
        ])
        for view in views where view is NSTextField {
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        return box
    }

    private func row(_ views: [NSView]) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 10
        return stack
    }

    @objc private func scheduleChanged() {
        // Commit the field editor before disabling a control, so an entered
        // duration or time is retained when its optional restriction is unchecked.
        window?.makeFirstResponder(nil)
        updateScheduleControls()
    }
    private func updateScheduleControls() {
        startPicker.isEnabled = scheduleButton.state == .on
        endPicker.isEnabled = scheduleButton.state == .on
        awakeStartPicker.isEnabled = awakeScheduleButton.state == .on
        awakeEndPicker.isEnabled = awakeScheduleButton.state == .on
        awakeDurationField.isEnabled = awakeTimerButton.state == .on
    }

    @objc private func saveChanges() {
        guard let interval = Int(intervalField.stringValue.trimmingCharacters(in: .whitespaces)),
              (1...1440).contains(interval) else {
            errorLabel.stringValue = tr("settings.invalidInterval")
            return
        }
        let duration = Int(awakeDurationField.stringValue.trimmingCharacters(in: .whitespaces))
        if awakeTimerButton.state == .on && !(duration.map { (1...1440).contains($0) } ?? false) {
            errorLabel.stringValue = tr("settings.invalidDuration")
            return
        }
        var settings = baseline
        if let value = iconActionPopup.selectedItem?.representedObject as? String,
           let action = IconAction(rawValue: value) { settings.iconAction = action }
        settings.enabled = enabledButton.state == .on
        settings.intervalMinutes = interval
        settings.scheduleEnabled = scheduleButton.state == .on
        settings.hideMenuBar = hideMenuBarButton.state == .on
        settings.startMinute = minutes(from: startPicker.dateValue)
        settings.endMinute = minutes(from: endPicker.dateValue)
        settings.awake.enabled = awakeEnabledButton.state == .on
        settings.awake.timerEnabled = awakeTimerButton.state == .on
        if let duration, (1...1440).contains(duration) { settings.awake.durationMinutes = duration }
        settings.awake.scheduleEnabled = awakeScheduleButton.state == .on
        settings.awake.startMinute = minutes(from: awakeStartPicker.dateValue)
        settings.awake.endMinute = minutes(from: awakeEndPicker.dateValue)
        onSave?(settings, baseline)
        close()
    }

    @objc private func cancelChanges() { close() }
    private func date(for minute: Int) -> Date {
        Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60,
                              second: 0, of: Date()) ?? Date()
    }
    private func minutes(from date: Date) -> Int {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }
}
