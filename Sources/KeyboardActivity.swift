import CoreGraphics

/// Content-free fallback when a keyboard event does not reach the event tap.
/// Read only HID state so normal session/private agent input is excluded.
struct KeyboardActivity {
    struct Snapshot: Equatable {
        let keys: UInt32
        let modifiers: UInt32

        static func current() -> Snapshot {
            Snapshot(keys: CGEventSource.counterForEventType(.hidSystemState, eventType: .keyDown),
                     modifiers: CGEventSource.counterForEventType(.hidSystemState, eventType: .flagsChanged))
        }
    }

    private var baseline: Snapshot?

    mutating func reset(to snapshot: Snapshot = .current()) {
        baseline = snapshot
    }

    mutating func consume(_ snapshot: Snapshot = .current()) -> Bool {
        defer { baseline = snapshot }
        guard let baseline else { return false }
        return snapshot != baseline
    }
}
