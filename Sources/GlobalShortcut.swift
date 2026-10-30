import AppKit
import Carbon

extension KeyboardShortcut {
    init(event: NSEvent) {
        keyCode = UInt32(event.keyCode)
        modifiers = 0
        for (flag, bit): (NSEvent.ModifierFlags, UInt32) in [
            (.command, Self.command), (.shift, Self.shift), (.option, Self.option), (.control, Self.control)
        ] {
            if event.modifierFlags.contains(flag) { modifiers |= bit }
        }
    }
}

final class GlobalShortcut {
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var localMonitor: Any?
    private var registeredShortcut: KeyboardShortcut?
    private let action: () -> Void
    private var identifier: UInt32 = 0
    private(set) var registrationStatus: OSStatus = noErr

    init(shortcut: KeyboardShortcut, action: @escaping () -> Void) {
        self.action = action
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        registrationStatus = InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let userData, let event else { return OSStatus(eventNotHandledErr) }
            let shortcut = Unmanaged<GlobalShortcut>.fromOpaque(userData).takeUnretainedValue()
            var key = EventHotKeyID()
            let result = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &key)
            guard result == noErr, key.signature == 0x41474E54, key.id == shortcut.identifier else {
                return OSStatus(eventNotHandledErr)
            }
            shortcut.action()
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard registrationStatus == noErr else { return }
        registrationStatus = replace(with: shortcut)
        // App-directed key events (including accessibility input) may reach
        // AppKit without Carbon's global dispatch. Keep the focused-app path
        // consistent, and consume the shortcut before text editing/menu actions.
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.hotKey != nil,
                  KeyboardShortcut(event: event) == self.registeredShortcut else { return event }
            if !event.isARepeat { self.action() }
            return nil
        }
    }

    /// Register first so a conflict never takes away the working shortcut.
    @discardableResult
    func replace(with shortcut: KeyboardShortcut) -> OSStatus {
        guard shortcut.isValid, handler != nil else { return OSStatus(paramErr) }
        var candidate: EventHotKeyRef?
        let nextIdentifier = identifier &+ 1
        let id = EventHotKeyID(signature: 0x41474E54, id: nextIdentifier)
        let result = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, id,
                                         GetApplicationEventTarget(), 0, &candidate)
        guard result == noErr else { return result }
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = candidate
        registeredShortcut = shortcut
        identifier = nextIdentifier
        registrationStatus = result
        return result
    }

    // Release only while the recorder is active, allowing the current combo to
    // reach its local key monitor. Every exit restores the saved registration.
    func suspend() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = nil
    }

    func resume(_ shortcut: KeyboardShortcut) {
        guard hotKey == nil else { return }
        registrationStatus = replace(with: shortcut)
    }

    deinit {
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
    }
}
