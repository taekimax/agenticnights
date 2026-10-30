import AppKit

final class SettingsWindow: NSWindowController, NSWindowDelegate {
    private let enabledButton = NSButton(checkboxWithTitle: "자동 화면 보호 켜기", target: nil, action: nil)
    private let intervalField = NSTextField(string: "10")
    private let scheduleButton = NSButton(checkboxWithTitle: "화면 보호 시간대 지정", target: nil, action: nil)
    private let hideMenuBarButton = NSButton(checkboxWithTitle: "검은 화면에서 메뉴 막대 숨기기", target: nil, action: nil)
    private let startPicker = NSDatePicker()
    private let endPicker = NSDatePicker()
    private let awakeEnabledButton = NSButton(checkboxWithTitle: "잠자기 방지 켜기", target: nil, action: nil)
    private let awakeTimerButton = NSButton(checkboxWithTitle: "타이머로 자동 끄기", target: nil, action: nil)
    private let awakeDurationField = NSTextField(string: "60")
    private let awakeScheduleButton = NSButton(checkboxWithTitle: "잠자기 방지 시간대 지정", target: nil, action: nil)
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
        window.title = "agenticnights 설정"
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
        let title = NSTextField(labelWithString: "화면 보호와 잠자기 방지를 따로")
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
        iconActionPopup.setAccessibilityLabel("달 아이콘 클릭 동작")
        stack.addArrangedSubview(row([NSTextField(labelWithString: "달 아이콘 클릭"), iconActionPopup]))

        for field in [intervalField, awakeDurationField] {
            field.alignment = .right
            field.widthAnchor.constraint(equalToConstant: 60).isActive = true
        }
        intervalField.setAccessibilityLabel("가림 간격, 분")
        awakeDurationField.setAccessibilityLabel("잠자기 방지 타이머, 분")
        for button in [scheduleButton, awakeScheduleButton, awakeTimerButton] {
            button.target = self
            button.action = #selector(scheduleChanged)
        }
        for picker in [startPicker, endPicker, awakeStartPicker, awakeEndPicker] {
            picker.datePickerStyle = .textFieldAndStepper
            picker.datePickerElements = [.hourMinute]
            picker.locale = Locale(identifier: "ko_KR")
        }
        startPicker.setAccessibilityLabel("화면 보호 시작 시각")
        endPicker.setAccessibilityLabel("화면 보호 종료 시각")
        awakeStartPicker.setAccessibilityLabel("잠자기 방지 시작 시각")
        awakeEndPicker.setAccessibilityLabel("잠자기 방지 종료 시각")

        let coverBox = section("화면 보호", views: [
            enabledButton,
            row([NSTextField(labelWithString: "가림 간격"), intervalField, NSTextField(labelWithString: "분")]),
            scheduleButton,
            row([NSTextField(labelWithString: "시작"), startPicker]),
            row([NSTextField(labelWithString: "종료"), endPicker]),
            hideMenuBarButton,
            hint("한 주기가 지나면 화면을 검게 가립니다.\n다른 앱으로 전환하거나 클릭·키 입력으로 해제합니다.")
        ])
        let awakeBox = section("잠자기 방지", views: [
            awakeEnabledButton,
            row([awakeTimerButton, awakeDurationField, NSTextField(labelWithString: "분 후")]),
            awakeScheduleButton,
            row([NSTextField(labelWithString: "시작"), awakeStartPicker]),
            row([NSTextField(labelWithString: "종료"), awakeEndPicker]),
            hint("Mac과 디스플레이의 자동 잠자기를 막습니다.\n타이머는 실제 작동 시작부터 계산하며,\n시간대 밖에서는 잠자기 방지를 멈춥니다.")
        ])
        let columns = NSStackView(views: [coverBox, awakeBox])
        columns.orientation = .horizontal
        columns.alignment = .top
        columns.distribution = .fillEqually
        columns.spacing = 16
        stack.addArrangedSubview(columns)
        columns.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        coverBox.heightAnchor.constraint(equalTo: awakeBox.heightAnchor).isActive = true

        stack.addArrangedSubview(hint("달 클릭 → 선택한 기능 켜기/끄기 · 우클릭 → 설정 · 각 기능의 타이머와 시간대를 따릅니다.\n분 단위 값: 1–1440 · 시작과 종료가 같으면 하루 종일 · 수동 가리기/해제: ⌃⌥⌘B"))
        errorLabel.textColor = .systemRed
        errorLabel.font = .systemFont(ofSize: 12)
        stack.addArrangedSubview(errorLabel)
        errorLabel.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        let cancel = NSButton(title: "취소", target: self, action: #selector(cancelChanges))
        cancel.keyEquivalent = "\u{1b}"
        let save = NSButton(title: "설정 적용", target: self, action: #selector(saveChanges))
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
            errorLabel.stringValue = "가림 간격을 1–1440 사이의 정수로 입력하세요."
            return
        }
        let duration = Int(awakeDurationField.stringValue.trimmingCharacters(in: .whitespaces))
        if awakeTimerButton.state == .on && !(duration.map { (1...1440).contains($0) } ?? false) {
            errorLabel.stringValue = "잠자기 방지 타이머를 1–1440 사이의 정수로 입력하세요."
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
