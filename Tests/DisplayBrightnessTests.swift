import CoreGraphics
import Foundation

@main
enum DisplayBrightnessTests {
    private final class Devices {
        var displays = [DisplayBrightness.Display(uuid: "built-in", id: 1)]
        var values: [CGDirectDisplayID: Float] = [1: 0.77]
        var reads: [CGDirectDisplayID] = []
        var writes: [(CGDirectDisplayID, Float)] = []
        var failedWrites: Set<CGDirectDisplayID> = []

        var backend: DisplayBrightness.Backend {
            .init(displays: { self.displays }, read: {
                self.reads.append($0)
                return self.values[$0]
            }, write: {
                self.writes.append(($0, $1))
                guard !self.failedWrites.contains($0) else { return false }
                self.values[$0] = $1
                return true
            })
        }
    }

    static func main() {
        let devices = Devices()
        let brightness = DisplayBrightness(backend: devices.backend)
        brightness.refresh()
        precondition(devices.reads.isEmpty && devices.writes.isEmpty)
        brightness.begin()
        precondition(brightness.isActive && devices.values[1] == 0)
        brightness.begin()
        brightness.refresh()
        precondition(devices.reads == [1], "Repeated begin/refresh must preserve original brightness")

        devices.displays = []
        brightness.refresh()
        devices.displays = [.init(uuid: "built-in", id: 9), .init(uuid: "apple", id: 2),
                            .init(uuid: "unsupported", id: 3), .init(uuid: "invalid", id: 4)]
        devices.values[9] = 0
        devices.values[2] = 0.42
        devices.values[4] = .nan
        brightness.refresh()
        precondition(!devices.reads.contains(9), "Reconnect must use saved UUID, not a new zero reading")
        precondition(devices.values[2] == 0)
        precondition(!devices.writes.contains { $0.0 == 3 || $0.0 == 4 }, "Unsupported/invalid readings must be skipped")
        brightness.end()
        precondition(!brightness.isActive && devices.values[9] == 0.77 && devices.values[2] == 0.42)
        let writeCount = devices.writes.count
        brightness.end()
        precondition(devices.writes.count == writeCount, "End must be idempotent")

        devices.values[9] = 0.6
        brightness.begin()
        brightness.end()
        precondition(devices.values[9] == 0.6, "A resumed/new session must capture the current brightness")

        devices.failedWrites.insert(9)
        brightness.begin()
        precondition(devices.values[2] == 0, "Failure on one display must not prevent dimming another")
        devices.failedWrites.remove(9)
        brightness.end()
        precondition(devices.values[9] == 0.6 && devices.values[2] == 0.42)
        print("PASS: brightness save/dim/restore, repeated refresh, UUID reconnect, new displays, unsupported values, fresh session and write failure")
    }
}
