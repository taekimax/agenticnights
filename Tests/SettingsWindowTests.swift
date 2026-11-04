import AppKit

// Run as a separate executable without Localization.swift: use only repository
// catalogs, never the user's editable translations or saved preferences.
private var catalog: [String: String] = [:]
func tr(_ key: String, _ values: [String: String] = [:]) -> String {
    var text = catalog[key] ?? key
    for (token, value) in values { text = text.replacingOccurrences(of: "{\(token)}", with: value) }
    return text
}

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}

@main
enum SettingsWindowTests {
    static func descendants(_ view: NSView) -> [NSView] {
        let children = (view as? NSStackView)?.arrangedSubviews ?? view.subviews
        return [view] + children.flatMap(descendants)
    }

    static func main() throws {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
        let resources = URL(fileURLWithPath: CommandLine.arguments[1])
        for language in ["en", "ko"] {
            catalog = try JSONDecoder().decode([String: String].self,
                from: Data(contentsOf: resources.appendingPathComponent("\(language).json")))
            try check(language)
        }
    }

    static func check(_ language: String) throws {
        let controller = SettingsWindow()
        let content = controller.window!.contentView!
        let views = descendants(content)
        let fields = views.compactMap { $0 as? NSTextField }.filter(\.isEditable)
        expect(fields.count == 2, "Only delay and duration accept text")
        let delay = fields.first { $0.accessibilityLabel() == tr("blackout.delay") }!
        let duration = fields.first { $0.accessibilityLabel() == tr("sleep.duration") }!
        let buttons = views.compactMap { $0 as? NSButton }
        let enabled = buttons.first { $0.title == tr("blackout.auto") }!
        let display = buttons.first { $0.title == tr("sleep.display") }!
        let reset = buttons.first { $0.title == tr("settings.shortcutReset") }!
        let shortcut = buttons.first { $0.accessibilityLabel() == tr("settings.shortcutRecord") }!
        let mode = views.compactMap { $0 as? NSPopUpButton }
            .first { $0.accessibilityLabel() == tr("sleep.duration") }!
        var current = VeilSettings.defaults
        var changes = 0
        var reject = false
        controller.onChange = { proposal in
            if reject { return "Rejected" }
            current = proposal
            _ = current.awake.update(at: Date(timeIntervalSince1970: 10_000))
            changes += 1
            controller.updateStatus("Status", settings: current)
            return nil
        }
        controller.updateStatus("Status", settings: current)
        expect(changes == 0, "Rendering cannot save preferences")
        enabled.performClick(nil)
        expect(!current.enabled && changes == 1, "Checkbox must apply immediately")

        func type(_ text: String, into field: NSTextField) {
            field.stringValue = text
            controller.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: field))
        }
        func blur(_ field: NSTextField) {
            controller.controlTextDidEndEditing(Notification(name: NSControl.textDidEndEditingNotification, object: field))
        }
        type("23", into: delay)
        current.awake.enabled = false
        controller.updateStatus("Off", settings: current)
        expect(delay.stringValue == "23", "Live state cannot replace unfinished input")
        blur(delay)
        expect(current.intervalMinutes == 23 && !current.awake.enabled,
               "Field commit must preserve external state changes")
        for invalid in ["0", "1441", "1.5", "", "-1", "abc"] {
            type(invalid, into: delay)
            blur(delay)
            expect(current.intervalMinutes == 23, "Invalid minutes cannot replace the last valid value")
            expect(views.compactMap { $0 as? NSTextField }.contains {
                $0.stringValue == tr("error.minutes") && !$0.isHidden
            }, "Invalid input must show the range error")
        }
        type("1440", into: delay)
        _ = delay.sendAction(delay.action!, to: delay.target)
        expect(current.intervalMinutes == 1440, "Return must apply valid minutes")
        type("37", into: duration)
        blur(duration)
        expect(current.awake.timerEnabled && current.awake.durationMinutes == 37,
               "Custom duration must apply and select a limit")
        current.awake.enabled = true
        _ = current.awake.update(at: Date(timeIntervalSince1970: 10_000))
        controller.updateStatus("On", settings: current)
        let deadline = current.awake.expiresAt
        display.performClick(nil)
        expect(current.awake.expiresAt == deadline, "Display option cannot restart the duration")
        mode.selectItem(at: 0)
        _ = mode.sendAction(mode.action!, to: mode.target)
        expect(!current.awake.timerEnabled && current.awake.durationMinutes == 37,
               "No Limit must retain the custom value")
        let unchangedCount = changes
        blur(duration)
        expect(!current.awake.timerEnabled && changes == unchangedCount,
               "Hidden unchanged duration cannot enable the timer")
        _ = duration.sendAction(duration.action!, to: duration.target)
        expect(current.awake.timerEnabled && current.awake.durationMinutes == 37,
               "Return accepts the retained Custom duration")

        current.shortcut = KeyboardShortcut(keyCode: 3, modifiers: KeyboardShortcut.command | KeyboardShortcut.option)
        controller.updateStatus("On", settings: current)
        reject = true
        reset.performClick(nil)
        expect(current.shortcut.keyCode == 3 && shortcut.title.hasPrefix(current.shortcut.displayName),
               "Rejected shortcut must preserve prior value and button title")
        reject = false
        reset.performClick(nil)
        expect(current.shortcut == .defaults, "Available shortcut reset must apply immediately")

        let startup = buttons.first { $0.title == tr("startup.launch") }!
        let openLoginItems = buttons.first { $0.title == tr("startup.openSettings") }!
        let startupNote = views.compactMap { $0 as? NSTextField }.first { $0.stringValue == tr("startup.approval") }
        expect(startupNote == nil, "Approval note starts empty")
        var loginItem = LoginItemStatus(enabled: false, needsApproval: false, available: true)
        var requests: [Bool] = []
        var loginRefusal: String?
        controller.loginItemStatus = { loginItem }
        controller.onLoginItemChange = { enabled in
            requests.append(enabled)
            if loginRefusal == nil { loginItem.enabled = enabled }
            return loginRefusal
        }
        let settingsChanges = changes
        controller.updateStatus("On", settings: current)
        expect(startup.state == .off && startup.isEnabled && openLoginItems.isHidden, "Login item reflects macOS state")
        startup.performClick(nil)
        expect(requests == [true] && startup.state == .on && changes == settingsChanges,
               "Open at login applies through macOS, not saved settings")
        loginRefusal = "Refused"
        startup.performClick(nil)
        expect(requests == [true, false] && startup.state == .on, "Refused change keeps the macOS state")
        expect(views.compactMap { $0 as? NSTextField }.contains { $0.stringValue == "Refused" && !$0.isHidden },
               "Refused change shows an error")
        loginRefusal = nil
        loginItem = LoginItemStatus(enabled: false, needsApproval: true, available: true)
        controller.updateStatus("On", settings: current)
        expect(startup.state == .on && !openLoginItems.isHidden, "Pending approval shows the System Settings link")
        loginItem = LoginItemStatus(enabled: false, needsApproval: false, available: false)
        controller.updateStatus("On", settings: current)
        expect(!startup.isEnabled && openLoginItems.isHidden, "Unavailable registration disables the checkbox")
        loginItem = LoginItemStatus(enabled: false, needsApproval: true, available: true)
        controller.updateStatus("On", settings: current)

        let scroll = content.subviews.compactMap { $0 as? NSScrollView }.first!
        for width in [640.0, 560.0] {
            controller.window!.setContentSize(NSSize(width: width, height: 600))
            content.layoutSubtreeIfNeeded()
            expect(abs(scroll.documentView!.frame.width - scroll.contentView.bounds.width) < 1,
                   "Settings must scroll vertically without horizontal overflow")
            expect(scroll.documentView!.frame.height > 0, "Scroll content must have a measured height")
            for view in views where !view.isHidden {
                if let button = view as? NSButton {
                    expect(button.frame.width >= button.fittingSize.width - 1,
                           "Button title must fit: \(button.title)")
                }
                if let label = view as? NSTextField, !label.isEditable {
                    let needed = label.cell!.cellSize(forBounds: NSRect(x: 0, y: 0, width: label.bounds.width, height: 10_000))
                    expect(needed.height <= label.bounds.height + 1,
                           "Label must have enough height: \(label.stringValue)")
                }
            }
            print("Layout \(language): window=\(content.frame.size), document=\(scroll.documentView!.frame.size)")
        }
        print("PASS: \(language) offscreen immediate changes, login item, Return/blur validation, live updates, duration preservation, shortcut rejection, scroll layout")
        controller.onChange = nil
    }
}
