import CoreGraphics
import Foundation

/// Reads elapsed input time, not the input contents. No global event tap is needed.
/// Use the login session's combined state for keyboard, mouse and trackpad events.
/// This matches Chromium's ui/base/idle/idle_mac.mm. ActivityWatch uses the HID
/// state instead; DEVELOPMENT.md documents the comparison and why we use session input.
struct UserActivity {
    private var resumedAt: TimeInterval?

    mutating func reset(uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        resumedAt = uptime
    }

    func idleSeconds() -> TimeInterval {
        elapsed(systemIdle: CGEventSource.secondsSinceLastEventType(
            .combinedSessionState, eventType: CGEventType(rawValue: UInt32.max)!),
            uptime: ProcessInfo.processInfo.systemUptime)
    }

    func elapsed(systemIdle: TimeInterval, uptime: TimeInterval) -> TimeInterval {
        guard systemIdle.isFinite, systemIdle >= 0 else { return 0 }
        guard let resumedAt else { return systemIdle }
        // Time spent asleep or in another user session is not a quiet interval.
        return min(systemIdle, max(0, uptime - resumedAt))
    }
}
