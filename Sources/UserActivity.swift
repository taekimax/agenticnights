import CoreGraphics
import Foundation

/// Reads elapsed input time, not the input contents. This idle query needs no tap.
/// HID state keeps normal synthetic agent activity from postponing blackout.
struct UserActivity {
    private var resumedAt: TimeInterval?

    mutating func reset(uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        resumedAt = uptime
    }

    func idleSeconds() -> TimeInterval {
        elapsed(systemIdle: CGEventSource.secondsSinceLastEventType(
            .hidSystemState, eventType: CGEventType(rawValue: UInt32.max)!),
            uptime: ProcessInfo.processInfo.systemUptime)
    }

    func elapsed(systemIdle: TimeInterval, uptime: TimeInterval) -> TimeInterval {
        guard systemIdle.isFinite, systemIdle >= 0 else { return 0 }
        guard let resumedAt else { return systemIdle }
        // Time spent asleep or in another user session is not a quiet interval.
        return min(systemIdle, max(0, uptime - resumedAt))
    }
}
