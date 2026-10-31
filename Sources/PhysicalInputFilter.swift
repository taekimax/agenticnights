import AppKit

// Physical-source classification follows Curtain's InputFilter.
// Copyright (c) 2026 Aric Camarata. MIT; see THIRD_PARTY_NOTICES.md.
// A HID tap, as in RustDesk, intercepts earlier than Curtain's session tap.
// This is a convenience filter, not authentication of an agent: some injectors
// use HID-source events, and some system gestures may bypass a CGEvent tap.
final class PhysicalInputFilter {
    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    /// Delivered on the main thread. Characters are transient unlock input only;
    /// this class neither stores nor logs key content.
    var onPhysicalKey: ((UInt16, String?, UInt64) -> Void)?
    var onPhysicalClick: (() -> Void)?
    var onPhysicalMove: (() -> Void)?

    private let lock = NSLock()
    private var tap: CFMachPort?
    private var runLoop: CFRunLoop?
    private var thread: Thread?
    private var stopped: DispatchSemaphore?
    private var generation: UInt64 = 0

    var isActive: Bool {
        lock.lock()
        defer { lock.unlock() }
        return tap.map { CFMachPortIsValid($0) && CGEvent.tapIsEnabled(tap: $0) } ?? false
    }

    /// Start/stop and callback assignment belong to the main thread. The tap has
    /// its own run loop so password verification and UI work cannot stall it.
    func start() throws {
        guard !isActive else { return }
        stop()
        guard AXIsProcessTrusted() else {
            throw Failure(message: "Accessibility permission is required to block physical input.")
        }
        // Include all documented keyboard/mouse/modifier events plus AppKit's
        // system-defined and gesture types. System gesture coverage still needs
        // a physical-device check; a mask is not proof the OS delivers that path.
        let rawTypes: [UInt32] = [1, 2, 3, 4, 5, 6, 7, 10, 11, 12, 14, 18, 22, 23, 24,
                                  25, 26, 27, 29, 30, 31, 32, 34, 37]
        let mask = rawTypes.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1) }
        let owner = Unmanaged.passUnretained(self).toOpaque()
        guard let newTap = CGEvent.tapCreate(tap: .cghidEventTap, place: .headInsertEventTap,
                                             options: .defaultTap, eventsOfInterest: mask,
                                             callback: physicalInputCallback, userInfo: owner) else {
            throw Failure(message: "macOS could not start the physical-input filter.")
        }
        guard let source = CFMachPortCreateRunLoopSource(nil, newTap, 0) else {
            CFMachPortInvalidate(newTap)
            throw Failure(message: "Could not create the input-filter run loop source.")
        }
        let ready = DispatchSemaphore(value: 0)
        let finished = DispatchSemaphore(value: 0)
        lock.lock()
        generation &+= 1
        tap = newTap
        stopped = finished
        lock.unlock()
        let worker = Thread { [self] in
            let loop = CFRunLoopGetCurrent()!
            CFRunLoopAddSource(loop, source, .commonModes)
            lock.lock()
            runLoop = loop
            lock.unlock()
            CGEvent.tapEnable(tap: newTap, enable: true)
            ready.signal()
            CFRunLoopRun()
            CGEvent.tapEnable(tap: newTap, enable: false)
            CFRunLoopRemoveSource(loop, source, .commonModes)
            CFMachPortInvalidate(newTap)
            finished.signal()
        }
        worker.name = "agenticnights.physical-input"
        thread = worker
        worker.start()
        ready.wait()
        guard isActive else {
            stop()
            throw Failure(message: "macOS did not enable the physical-input filter.")
        }
    }

    func stop() {
        lock.lock()
        generation &+= 1
        let oldTap = tap
        let oldLoop = runLoop
        let finished = stopped
        tap = nil
        runLoop = nil
        stopped = nil
        lock.unlock()
        if let oldTap { CGEvent.tapEnable(tap: oldTap, enable: false) }
        if let oldLoop {
            CFRunLoopPerformBlock(oldLoop, CFRunLoopMode.commonModes.rawValue) { CFRunLoopStop(oldLoop) }
            CFRunLoopWakeUp(oldLoop)
            finished?.wait()
        }
        thread = nil
    }

    fileprivate func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        lock.lock()
        let currentTap = tap
        let currentGeneration = generation
        lock.unlock()
        guard let currentTap else { return Unmanaged.passUnretained(event) }
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            CGEvent.tapEnable(tap: currentTap, enable: true)
            return Unmanaged.passUnretained(event)
        }
        guard event.getIntegerValueField(.eventSourceStateID) == CGEventSourceStateID.hidSystemState.rawValue else {
            return Unmanaged.passUnretained(event)
        }
        if type == .keyDown {
            let keycode = UInt16(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode))
            let flags = event.flags.rawValue
            var count = 0
            var buffer = [UniChar](repeating: 0, count: 16)
            event.keyboardGetUnicodeString(maxStringLength: buffer.count, actualStringLength: &count,
                                           unicodeString: &buffer)
            let characters = count > 0 ? String(utf16CodeUnits: buffer, count: min(count, buffer.count)) : nil
            DispatchQueue.main.async { [weak self] in
                guard let self, self.isCurrent(currentGeneration) else { return }
                self.onPhysicalKey?(keycode, characters, flags)
            }
        } else if type == .leftMouseDown || type == .rightMouseDown || type == .otherMouseDown {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.isCurrent(currentGeneration) else { return }
                self.onPhysicalClick?()
            }
        }
        if type == .mouseMoved || type == .leftMouseDragged || type == .rightMouseDragged || type == .otherMouseDragged {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.isCurrent(currentGeneration) else { return }
                self.onPhysicalMove?()
            }
        }
        return nil
    }

    private func isCurrent(_ value: UInt64) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return tap != nil && generation == value
    }

    deinit { stop() }
}

private let physicalInputCallback: CGEventTapCallBack = { _, type, event, owner in
    guard let owner else { return Unmanaged.passUnretained(event) }
    return Unmanaged<PhysicalInputFilter>.fromOpaque(owner).takeUnretainedValue().handle(type, event)
}
