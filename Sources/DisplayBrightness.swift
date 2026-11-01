import CoreGraphics
import ColorSync
import Darwin
import Foundation

/// Best-effort backlight reduction alongside gamma blackout. All lifecycle calls
/// run on the controller's main thread. No DDC or permission requests are used.
final class DisplayBrightness {
    struct Display {
        let uuid: String
        let id: CGDirectDisplayID
    }

    struct Backend {
        let displays: () -> [Display]
        let read: (CGDirectDisplayID) -> Float?
        let write: (CGDirectDisplayID, Float) -> Bool
    }

    private let backend: Backend
    private var originals: [String: Float] = [:]
    private(set) var isActive = false

    init() {
        let services = SystemBrightness()
        backend = Backend(displays: Self.connectedDisplays,
                          read: { services.read($0) },
                          write: { services.write($0, $1) })
    }

    /// Inject devices for tests without touching the physical displays.
    init(backend: Backend) { self.backend = backend }

    func begin() {
        guard !isActive else { return }
        isActive = true
        refresh()
    }

    /// Keep saved values across ID changes and disconnected/reconnected screens.
    /// Repeated configuration notifications must never save an already-dim value.
    func refresh() {
        guard isActive else { return }
        for display in backend.displays() {
            if originals[display.uuid] == nil {
                guard let value = backend.read(display.id), value.isFinite,
                      (0...1).contains(value) else { continue }
                originals[display.uuid] = value
            }
            _ = backend.write(display.id, 0)
        }
    }

    /// Also used before suspension; begin() captures current values on resumption.
    /// A disconnected display cannot be restored after this session ends.
    func end() {
        guard isActive else { return }
        for display in backend.displays() {
            guard let value = originals[display.uuid] else { continue }
            _ = backend.write(display.id, value)
        }
        originals.removeAll()
        isActive = false
    }

    private static func connectedDisplays() -> [Display] {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetOnlineDisplayList(count, &ids, &count) == .success else { return [] }
        return ids.prefix(Int(count)).compactMap { id in
            guard let uuid = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() else { return nil }
            return Display(uuid: CFUUIDCreateString(nil, uuid) as String, id: id)
        }
    }

    deinit { end() }
}

/// Load optionally: a missing framework/symbol or unsupported monitor simply
/// leaves its brightness alone. DisplayServices controls macOS-supported panels.
private final class SystemBrightness {
    private typealias GetBrightness = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetBrightness = @convention(c) (UInt32, Float) -> Int32
    private let handle: UnsafeMutableRawPointer?
    private let getBrightness: GetBrightness?
    private let setBrightness: SetBrightness?

    init() {
        handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY | RTLD_LOCAL)
        if let handle,
           let get = dlsym(handle, "DisplayServicesGetBrightness"),
           let set = dlsym(handle, "DisplayServicesSetBrightness") {
            getBrightness = unsafeBitCast(get, to: GetBrightness.self)
            setBrightness = unsafeBitCast(set, to: SetBrightness.self)
        } else {
            getBrightness = nil
            setBrightness = nil
        }
    }

    func read(_ display: CGDirectDisplayID) -> Float? {
        guard let getBrightness, setBrightness != nil else { return nil }
        var value: Float = 0
        guard getBrightness(display, &value) == 0 else { return nil }
        return value
    }

    func write(_ display: CGDirectDisplayID, _ value: Float) -> Bool {
        guard let setBrightness else { return false }
        return setBrightness(display, value) == 0
    }

    deinit { if let handle { dlclose(handle) } }
}
