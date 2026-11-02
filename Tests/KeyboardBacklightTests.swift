import Darwin
import Foundation

private final class Keyboards {
    var displayActive = true
    var ids: [UInt64] = [7]
    var values: [UInt64: Float] = [7: 0.637]
    var overridden: Set<UInt64> = []
    var reads: [UInt64] = []
    var writes: [(UInt64, Float)] = []
    var beforeWrite: ((UInt64, Float) -> Void)?
    var acceptsWrites = true

    var backend: KeyboardBacklight.Backend {
        .init(builtInDisplayActive: { self.displayActive }, keyboards: { self.ids },
              read: { self.reads.append($0); return self.values[$0] },
              isOverridden: { self.overridden.contains($0) },
              write: { id, value in
                  self.beforeWrite?(id, value)
                  self.writes.append((id, value))
                  if self.acceptsWrites { self.values[id] = value }
                  return self.acceptsWrites
              })
    }
}

@main
struct KeyboardBacklightTests {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let journal = root.appendingPathComponent("nested/keyboard.json")
        let livePID: Int32 = 1          // launchd: running, owned by another user
        let liveStart = KeyboardBacklight.startTime(livePID)!
        let deadPID: Int32 = 99_999_999 // beyond the PID range
        func exists() -> Bool { FileManager.default.fileExists(atPath: journal.path) }
        func saved() -> KeyboardBacklight.Journal? {
            (try? Data(contentsOf: journal)).flatMap { try? JSONDecoder().decode(KeyboardBacklight.Journal.self, from: $0) }
        }
        func plant(_ originals: [String: Float], pid: Int32, start: Int = 0) throws {
            try FileManager.default.createDirectory(at: journal.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(KeyboardBacklight.Journal(pid: pid, start: start, originals: originals)).write(to: journal, options: .atomic)
        }

        let devices = Keyboards()
        let keyboard = KeyboardBacklight(backend: devices.backend, journal: journal)
        keyboard.refresh()
        precondition(devices.writes.isEmpty)
        devices.beforeWrite = { id, value in
            if value == 0 { precondition(saved()?.originals[String(id)] == devices.values[id], "Journal precedes dimming") }
        }
        keyboard.begin()
        precondition(keyboard.isActive && devices.values[7] == 0 && saved() == .init(pid: getpid(), start: KeyboardBacklight.startTime(getpid())!, originals: ["7": 0.637]))
        keyboard.begin()
        keyboard.refresh()
        keyboard.refresh()
        precondition(devices.reads == [7] && devices.writes.count == 1, "Save and dim only once")
        KeyboardBacklight(backend: devices.backend, journal: journal).recoverPending()
        precondition(devices.values[7] == 0 && exists(), "Recovery cannot run during blackout")
        keyboard.end()
        precondition(!keyboard.isActive && devices.values[7] == 0.637 && !exists())
        keyboard.end()
        precondition(devices.writes.count == 2)
        print("PASS: keyboard single save, repeated refresh, exact restore, journal ordering/removal and active recovery guard")

        devices.beforeWrite = nil
        devices.ids = [7, 8, 9, 10, 11, 12, 13, 14]
        devices.values = [7: 0.4, 8: .nan, 9: .infinity, 10: -0.1, 11: 1.1, 12: 0.5, 14: 0.0005]
        devices.overridden = [7]
        devices.writes = []
        keyboard.begin()
        keyboard.end()
        precondition(devices.writes.count == 2 && devices.writes.allSatisfy { $0.0 == 12 })
        print("PASS: keyboard overridden, nil, non-finite, out-of-range and near-zero reads skipped")

        devices.ids = [7]
        devices.overridden = []
        devices.values[7] = 0.55
        keyboard.begin()
        devices.values[7] = 0.23
        keyboard.refresh()
        keyboard.end()
        precondition(devices.values[7] == 0.23 && !exists(), "Keep user brightness changes")
        print("PASS: keyboard user brightness preserved across refresh and end")

        devices.displayActive = false
        devices.writes = []
        keyboard.begin()
        precondition(keyboard.isActive && devices.writes.isEmpty && !exists())
        devices.displayActive = true
        keyboard.refresh()
        precondition(devices.values[7] == 0)
        devices.displayActive = false
        keyboard.refresh()
        precondition(keyboard.isActive && devices.values[7] == 0.23 && !exists())
        devices.values[7] = 0.7
        devices.displayActive = true
        keyboard.refresh()
        precondition(devices.values[7] == 0)
        keyboard.end()
        precondition(devices.values[7] == 0.7)
        print("PASS: keyboard external-only no-op, active/inactive transitions and re-dimming")

        devices.ids = []
        devices.writes = []
        keyboard.begin()
        keyboard.refresh()
        keyboard.end()
        precondition(devices.writes.isEmpty && !exists())
        print("PASS: unavailable keyboard backend no-op")

        // Failed dimming is retried; failed restoration is retried by the next blackout.
        devices.ids = [7]
        devices.values[7] = 0.61
        devices.writes = []
        devices.acceptsWrites = false
        keyboard.begin()
        precondition(devices.values[7] == 0.61 && exists())
        devices.acceptsWrites = true
        keyboard.refresh()
        precondition(devices.values[7] == 0 && devices.writes.count == 2, "Retry failed dimming without replacing original")
        devices.acceptsWrites = false
        keyboard.end()
        precondition(saved()?.originals == ["7": 0.61], "Failed restore retains recovery journal")
        devices.acceptsWrites = true
        keyboard.begin()
        precondition(devices.values[7] == 0 && saved()?.originals == ["7": 0.61], "Next blackout adopts, never saves zero")
        keyboard.end()
        precondition(devices.values[7] == 0.61 && !exists(), "Adopted original restored")
        print("PASS: keyboard failed write retry and same-process restore retry")

        // A pending restore resolves on session return without another blackout.
        keyboard.begin()
        devices.acceptsWrites = false
        keyboard.end()
        precondition(devices.values[7] == 0 && exists())
        devices.acceptsWrites = true
        KeyboardBacklight(backend: devices.backend, journal: journal).recoverPending()
        precondition(devices.values[7] == 0.61 && !exists())
        print("PASS: keyboard pending restore recovered outside blackout")

        // Adopting drops entries the user has raised since; dimming starts from current value.
        try plant(["7": 0.9], pid: deadPID)
        devices.values[7] = 0.3
        keyboard.begin()
        precondition(saved()?.originals == ["7": 0.3])
        keyboard.end()
        precondition(devices.values[7] == 0.3 && !exists())
        print("PASS: keyboard adoption keeps user-raised values")

        // Recovery keeps unresolved entries and drops resolved or user-changed ones.
        devices.ids = [7, 8, 9, 10]
        devices.values = [7: 0, 8: 0.001, 9: 0.2, 10: .nan]
        try plant(["7": 0.42, "8": 0.8, "9": 0.9, "10": 0.6, "999": 0.5, "11": 2], pid: deadPID)
        KeyboardBacklight(backend: devices.backend, journal: journal).recoverPending()
        precondition(devices.values[7] == 0.42 && devices.values[8] == 0.8 && devices.values[9] == 0.2)
        precondition(saved()?.originals == ["10": 0.6, "999": 0.5], "Unreadable and missing keyboards stay journaled")
        devices.ids = [7, 10, 999]
        devices.values = [7: 0.42, 10: 0, 999: 0]
        devices.acceptsWrites = false
        KeyboardBacklight(backend: devices.backend, journal: journal).recoverPending()
        precondition(saved()?.originals == ["10": 0.6, "999": 0.5], "Failed writes stay journaled")
        devices.acceptsWrites = true
        KeyboardBacklight(backend: devices.backend, journal: journal).recoverPending()
        precondition(devices.values[10] == 0.6 && devices.values[999] == 0.5 && !exists())
        print("PASS: keyboard crash recovery restores near-zero values and keeps unresolved entries")

        // Another running instance owns its journal.
        devices.ids = [7]
        devices.values = [7: 0]
        try plant(["7": 0.5], pid: livePID, start: liveStart)
        devices.writes = []
        KeyboardBacklight(backend: devices.backend, journal: journal).recoverPending()
        keyboard.begin()
        keyboard.end()
        precondition(devices.writes.isEmpty && saved()?.originals == ["7": 0.5], "Live owner journal untouched")
        try plant(["7": 0.5], pid: livePID, start: liveStart - 1)
        KeyboardBacklight(backend: devices.backend, journal: journal).recoverPending()
        precondition(devices.values[7] == 0.5 && !exists(), "Reused PID does not keep a stale journal")
        print("PASS: keyboard journal of another running instance untouched; reused PID recovered")

        // Adopting a dead owner's journal rewrites ownership before any other instance looks.
        devices.values[7] = 0
        try plant(["7": 0.45, "8": 0.0005], pid: deadPID)
        keyboard.begin()
        precondition(saved()?.pid == getpid() && saved()?.originals == ["7": 0.45], "Adoption takes ownership")
        KeyboardBacklight(backend: devices.backend, journal: journal, pid: deadPID).recoverPending()
        precondition(devices.values[7] == 0 && exists(), "Second instance leaves an adopted journal")
        keyboard.end()
        precondition(devices.values[7] == 0.45 && !exists())
        print("PASS: keyboard adoption takes ownership and ignores near-zero originals")

        let blocked = root.appendingPathComponent("file")
        try Data().write(to: blocked)
        let unwritable = KeyboardBacklight(backend: devices.backend, journal: blocked.appendingPathComponent("journal.json"))
        devices.values[7] = 0.5
        devices.writes = []
        unwritable.begin()
        unwritable.end()
        precondition(devices.writes.isEmpty, "Journal failure must prevent dimming")
        print("PASS: keyboard journal failure prevents hardware writes")

        devices.values[7] = 0.67
        do {
            let scoped = KeyboardBacklight(backend: devices.backend, journal: journal)
            scoped.begin()
            precondition(devices.values[7] == 0)
        }
        precondition(devices.values[7] == 0.67 && !exists(), "Deinit restores")
        print("PASS: keyboard deinit restores brightness")
    }
}
