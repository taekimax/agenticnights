import CoreGraphics
import Darwin
import Foundation
import ObjectiveC

/// Best-effort keyboard dimming alongside blackout. Lifecycle calls use the main thread.
/// Originals are journaled before dimming; unresolved entries are retried by the
/// next blackout in this process, by session return, and at the next launch.
final class KeyboardBacklight {
    struct Backend {
        let builtInDisplayActive: () -> Bool
        let keyboards: () -> [UInt64]
        let read: (UInt64) -> Float?
        let isOverridden: (UInt64) -> Bool
        let write: (UInt64, Float) -> Bool
    }

    /// Owner process (PID and start time, which survives PID reuse) plus each
    /// keyboard's brightness before dimming.
    struct Journal: Codable, Equatable {
        var pid: Int32
        var start: Int
        var originals: [String: Float]
    }

    private static let system = SystemKeyboardBacklight()
    private static var activeCount = 0
    private static let journalURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/agenticnights/keyboard-backlight.json")
    static var isSupported: Bool { !system.keyboards().isEmpty }

    private let backend: Backend
    private let journal: URL
    private let pid: Int32
    private let start: Int
    private var originals: [String: Float] = [:]
    private var dimmed: Set<UInt64> = []
    private var blocked = false
    private(set) var isActive = false

    convenience init() { self.init(backend: Self.system.backend, journal: Self.journalURL) }

    /// Inject devices, a journal file and an owner PID for tests without touching hardware.
    init(backend: Backend, journal: URL, pid: Int32 = getpid()) {
        self.backend = backend
        self.journal = journal
        self.pid = pid
        start = Self.startTime(pid) ?? 0
    }

    func begin() {
        guard !isActive else { return }
        isActive = true
        Self.activeCount += 1
        // Adopt values another blackout could not restore; never take over a
        // journal that a different running instance still owns.
        if let saved = loadJournal() {
            if ownedElsewhere(saved) { blocked = true }
            else {
                // A value the user raised since then is theirs; drop that entry.
                let pending = saved.originals.filter { key, value in
                    guard let id = UInt64(key), Self.valid(value), value > Self.off else { return false }
                    return backend.read(id).map { !Self.valid($0) || $0 <= Self.off } ?? true
                }
                originals.merge(pending) { current, _ in current }
                // Take ownership so another instance treats these entries as live.
                _ = saveJournal()
            }
        }
        refresh()
    }

    /// Repeated configuration notifications must never save an already-dim value.
    func refresh() {
        guard isActive, !blocked else { return }
        guard backend.builtInDisplayActive() else { restore(); return }
        for id in backend.keyboards() where !dimmed.contains(id) {
            guard !backend.isOverridden(id) else { continue }
            if originals[String(id)] == nil {
                // Zero is either already dark or a transient system reading.
                guard let value = backend.read(id), Self.valid(value), value > Self.off else { continue }
                originals[String(id)] = value
                // Never turn a keyboard off without a durable recovery value.
                guard saveJournal() else { originals.removeValue(forKey: String(id)); continue }
            }
            if backend.write(id, 0) { dimmed.insert(id) }
        }
    }

    func end() {
        guard isActive else { return }
        if !blocked { restore() }
        originals.removeAll()
        dimmed.removeAll()
        blocked = false
        isActive = false
        Self.activeCount -= 1
    }

    /// Values still near zero are restored; a user change is kept. Failures stay journaled.
    private func restore() {
        guard !originals.isEmpty else { return }
        for (key, original) in originals {
            guard let id = UInt64(key), let current = backend.read(id), Self.valid(current) else { continue }
            if current > Self.off || backend.write(id, original) {
                originals.removeValue(forKey: key)
                dimmed.remove(id)
            }
        }
        _ = saveJournal()
    }

    /// Run at launch and session return; skipped while any blackout in this process is active.
    static func recoverPending() {
        KeyboardBacklight(backend: system.backend, journal: journalURL).recoverPending()
    }

    func recoverPending() {
        guard Self.activeCount == 0, !isActive, let saved = loadJournal(), !ownedElsewhere(saved) else { return }
        let available = Set(backend.keyboards())
        originals = saved.originals.filter { key, value in
            guard let id = UInt64(key), Self.valid(value) else { return false }
            guard available.contains(id), let current = backend.read(id), Self.valid(current) else { return true }
            return current <= Self.off && !backend.write(id, value)
        }
        _ = saveJournal()
        originals.removeAll()
    }

    private func loadJournal() -> Journal? {
        guard let data = try? Data(contentsOf: journal) else { return nil }
        return try? JSONDecoder().decode(Journal.self, from: data)
    }

    private func saveJournal() -> Bool {
        do {
            if originals.isEmpty {
                if FileManager.default.fileExists(atPath: journal.path) { try FileManager.default.removeItem(at: journal) }
            } else {
                try FileManager.default.createDirectory(at: journal.deletingLastPathComponent(), withIntermediateDirectories: true)
                try JSONEncoder().encode(Journal(pid: pid, start: start, originals: originals)).write(to: journal, options: .atomic)
            }
            return true
        } catch {
            NSLog("Keyboard backlight journal: %@", error.localizedDescription)
            return false
        }
    }

    private static let off: Float = 0.001
    private static func valid(_ value: Float) -> Bool { value.isFinite && (0...1).contains(value) }
    /// Another live instance wrote this journal; a reused PID has a different start time.
    private func ownedElsewhere(_ saved: Journal) -> Bool {
        !(saved.pid == pid && saved.start == start) && Self.startTime(saved.pid) == saved.start
    }

    static func startTime(_ pid: Int32) -> Int? {
        guard pid > 0 else { return nil }
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var name = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        guard sysctl(&name, 4, &info, &size, nil, 0) == 0, size > 0, info.kp_proc.p_pid == pid else { return nil }
        return info.kp_proc.p_starttime.tv_sec
    }

    deinit { end() }
}

/// Validate private API signatures before invoking typed IMPs.
private final class SystemKeyboardBacklight {
    private typealias CopyIDs = @convention(c) (AnyObject, Selector) -> Unmanaged<NSArray>?
    private typealias Flag = @convention(c) (AnyObject, Selector, UInt64) -> Bool
    private typealias Read = @convention(c) (AnyObject, Selector, UInt64) -> Float
    private typealias Write = @convention(c) (AnyObject, Selector, Float, Int32, Bool, UInt64) -> Bool
    private typealias PropertyWrite = @convention(c) (AnyObject, Selector, NSNumber, NSString, UInt64) -> Bool
    private let handle: UnsafeMutableRawPointer?
    private var client: NSObject?
    private var fallback: NSObject?
    private var preferFallback = false

    init() {
        handle = dlopen("/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness", RTLD_LAZY | RTLD_LOCAL)
        guard handle != nil, let type = NSClassFromString("KeyboardBrightnessClient") as? NSObject.Type else { return }
        let object = type.init()
        let signatures = ["copyKeyboardBacklightIDs": "@@:", "isKeyboardBuiltIn:": "B@:Q",
                          "brightnessForKeyboard:": "f@:Q", "backlightLevelForKeyboard:": "f@:Q",
                          "isBacklightSuppressedOnKeyboard:": "B@:Q", "isBacklightDimmedOnKeyboard:": "B@:Q",
                          "setBrightness:fadeSpeed:commit:forKeyboard:": "B@:fiBQ"]
        guard signatures.allSatisfy({ Self.matches(object, $0.key, $0.value) }) else { return }
        client = object
        // Optional second writer for systems where KBC accepts but ignores writes.
        if let type = NSClassFromString("BrightnessSystemClient") as? NSObject.Type {
            let object = type.init()
            if Self.matches(object, "setProperty:withKey:keyboardID:", "B@:@@Q") { fallback = object }
        }
    }

    private static func matches(_ object: NSObject, _ name: String, _ expected: String) -> Bool {
        let selector = NSSelectorFromString(name)
        guard object.responds(to: selector),
              let method = class_getInstanceMethod(type(of: object), selector),
              let encoding = method_getTypeEncoding(method),
              String(cString: encoding).filter({ !$0.isNumber }) == expected else {
            NSLog("Keyboard backlight API unavailable: %@", name)
            return false
        }
        return true
    }

    var backend: KeyboardBacklight.Backend {
        .init(builtInDisplayActive: Self.builtInDisplayActive, keyboards: { self.keyboards() },
              read: { self.read($0, "brightnessForKeyboard:") },
              isOverridden: { self.flag($0, "isBacklightSuppressedOnKeyboard:") || self.flag($0, "isBacklightDimmedOnKeyboard:") },
              write: { self.write($0, $1) })
    }

    func keyboards() -> [UInt64] {
        guard let client else { return [] }
        let selector = NSSelectorFromString("copyKeyboardBacklightIDs")
        let copy = unsafeBitCast(client.method(for: selector), to: CopyIDs.self)
        guard let ids = copy(client, selector)?.takeRetainedValue() as? [NSNumber] else { return [] }
        return ids.map(\.uint64Value).filter { flag($0, "isKeyboardBuiltIn:") }
    }

    private func flag(_ id: UInt64, _ name: String) -> Bool {
        guard let client else { return false }
        let selector = NSSelectorFromString(name)
        return unsafeBitCast(client.method(for: selector), to: Flag.self)(client, selector, id)
    }

    private func read(_ id: UInt64, _ name: String) -> Float? {
        guard let client else { return nil }
        let selector = NSSelectorFromString(name)
        return unsafeBitCast(client.method(for: selector), to: Read.self)(client, selector, id)
    }

    /// Immediate (no fade), uncommitted writes; success requires readback, including
    /// the measured level when turning off, because some systems ignore accepted writes.
    private func write(_ id: UInt64, _ value: Float) -> Bool {
        guard let client else { return false }
        func attempt(_ useFallback: Bool) -> Bool {
            let accepted: Bool
            if useFallback {
                guard let fallback else { return false }
                let selector = NSSelectorFromString("setProperty:withKey:keyboardID:")
                accepted = unsafeBitCast(fallback.method(for: selector), to: PropertyWrite.self)(
                    fallback, selector, NSNumber(value: value), "KeyboardBacklightBrightness", id)
            } else {
                let selector = NSSelectorFromString("setBrightness:fadeSpeed:commit:forKeyboard:")
                accepted = unsafeBitCast(client.method(for: selector), to: Write.self)(client, selector, value, 0, false, id)
            }
            guard accepted, let brightness = read(id, "brightnessForKeyboard:"), brightness.isFinite,
                  abs(brightness - value) <= 0.01 else { return false }
            guard value == 0 else { return true }
            guard let level = read(id, "backlightLevelForKeyboard:"), level.isFinite else { return false }
            return abs(level) <= 0.05
        }
        if attempt(preferFallback) { return true }
        if attempt(!preferFallback) { preferFallback.toggle(); return true }
        return false
    }

    private static func builtInDisplayActive() -> Bool {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return false }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &ids, &count) == .success else { return false }
        return ids.prefix(Int(count)).contains { CGDisplayIsBuiltin($0) != 0 }
    }

    deinit { if let handle { dlclose(handle) } }
}
