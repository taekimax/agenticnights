import CoreGraphics
import ColorSync
import Foundation

// Gamma blackout follows Curtain's HostBlackout and RustDesk's macOS privacy
// mode: darken the physical output without covering the captured desktop.
// Preserve the exact original ramps rather than resetting the ColorSync profile.
// Reference: github.com/acamarata/curtain, MIT, Copyright (c) 2026 Aric Camarata.
// API success cannot prove that a physical panel is black; verify each setup.
final class DisplayBlackout {
    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    private struct Ramp {
        let red: [CGGammaValue]
        let green: [CGGammaValue]
        let blue: [CGGammaValue]

        func restore(to display: CGDirectDisplayID) -> CGError {
            CGSetDisplayTransferByTable(display, UInt32(red.count), red, green, blue)
        }
    }

    // UUIDs survive display-ID changes when a monitor reconnects during a session.
    private var originals: [String: Ramp] = [:]
    private(set) var isActive = false
    private(set) var isPaused = false

    /// Lifecycle methods are called on the main thread by the cover controller.
    func begin() throws {
        guard !isActive else { return }
        originals.removeAll()
        isActive = true
        isPaused = false
        do {
            try refresh()
        } catch {
            let restorationErrors = end()
            if !restorationErrors.isEmpty {
                throw Failure(message: "\(error.localizedDescription) Restore: \(restorationErrors.joined(separator: "; "))")
            }
            throw error
        }
    }

    /// Reconcile newly connected displays before blackening any new output.
    /// Call periodically and after display/wake notifications; macOS may reset ramps.
    func refresh() throws {
        guard isActive else { return }
        let displays = try onlineDisplays()
        guard !displays.isEmpty else { throw Failure(message: "No active display is available.") }
        for (uuid, display) in displays where originals[uuid] == nil {
            originals[uuid] = try readRamp(display)
        }
        guard !isPaused else { return }
        for (_, display) in displays { try blacken(display) }
    }

    /// Show the password windows before pausing, so restoring gamma reveals only
    /// those windows. On failure reapply blackout and leave the pause uncommitted.
    func pause() throws {
        guard isActive, !isPaused else { return }
        let displays = try onlineDisplays()
        do {
            for (uuid, display) in displays {
                guard let ramp = originals[uuid] else { continue }
                let result = ramp.restore(to: display)
                guard result == .success else { throw failure("Restore", display, result) }
            }
            isPaused = true
        } catch {
            for (_, display) in displays { try? blacken(display) }
            throw error
        }
    }

    /// Reapply blackout before removing the password windows.
    func resume() throws {
        guard isActive, isPaused else { return }
        let displays = try onlineDisplays()
        for (uuid, display) in displays where originals[uuid] == nil {
            originals[uuid] = try readRamp(display)
        }
        for (_, display) in displays { try blacken(display) }
        isPaused = false
    }

    /// Attempt every restoration even when one output fails. Disconnected outputs
    /// cannot be restored; macOS owns their next connection's configuration.
    @discardableResult
    func end() -> [String] {
        guard isActive else { return [] }
        var errors: [String] = []
        do {
            for (uuid, display) in try onlineDisplays() {
                guard let ramp = originals[uuid] else { continue }
                let result = ramp.restore(to: display)
                if result != .success { errors.append(failure("Restore", display, result).message) }
            }
        } catch {
            errors.append(error.localizedDescription)
        }
        originals.removeAll()
        isActive = false
        isPaused = false
        return errors
    }

    private func onlineDisplays() throws -> [(String, CGDirectDisplayID)] {
        var count: UInt32 = 0
        var result = CGGetActiveDisplayList(0, nil, &count)
        guard result == .success else { throw Failure(message: "Cannot enumerate displays (\(result.rawValue)).") }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        result = CGGetActiveDisplayList(count, &ids, &count)
        guard result == .success else { throw Failure(message: "Cannot enumerate displays (\(result.rawValue)).") }
        return try ids.prefix(Int(count)).map { display in
            guard let uuid = CGDisplayCreateUUIDFromDisplayID(display)?.takeRetainedValue() else {
                throw Failure(message: "Cannot identify display \(display).")
            }
            return (CFUUIDCreateString(nil, uuid) as String, display)
        }
    }

    private func readRamp(_ display: CGDirectDisplayID) throws -> Ramp {
        let capacity = CGDisplayGammaTableCapacity(display)
        guard capacity > 0 else { throw Failure(message: "Display \(display) does not expose gamma tables.") }
        var red = [CGGammaValue](repeating: 0, count: Int(capacity))
        var green = red
        var blue = red
        var count: UInt32 = 0
        let result = CGGetDisplayTransferByTable(display, capacity, &red, &green, &blue, &count)
        guard result == .success, count > 0, count <= capacity else {
            throw failure("Read gamma", display, result)
        }
        return Ramp(red: Array(red.prefix(Int(count))), green: Array(green.prefix(Int(count))),
                    blue: Array(blue.prefix(Int(count))))
    }

    private func blacken(_ display: CGDirectDisplayID) throws {
        let capacity = CGDisplayGammaTableCapacity(display)
        guard capacity > 0 else { throw Failure(message: "Display \(display) does not expose gamma tables.") }
        let zeros = [CGGammaValue](repeating: 0, count: Int(capacity))
        let result = CGSetDisplayTransferByTable(display, capacity, zeros, zeros, zeros)
        guard result == .success else { throw failure("Blackout", display, result) }
    }

    private func failure(_ operation: String, _ display: CGDirectDisplayID, _ result: CGError) -> Failure {
        Failure(message: "\(operation) failed for display \(display) (\(result.rawValue)).")
    }

    deinit { end() }
}
