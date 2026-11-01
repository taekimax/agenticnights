import Foundation

private struct TestFailure: Error, CustomStringConvertible {
    let description: String
}

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw TestFailure(description: message) }
}

private var utc: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}

private func date(_ hour: Int, _ minute: Int = 0, _ second: Int = 0, day: Int = 28) -> Date {
    utc.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute, second: second))!
}

@main
enum ScheduleTests {
    static func main() throws {
        let tests: [(String, () throws -> Void)] = [
            ("firstInterval", firstInterval),
            ("latestInput", latestInput),
            ("continuousInput", continuousInput),
            ("launchIdle", launchIdle),
            ("invalidIdleSamples", invalidIdleSamples),
            ("overdueCallback", overdueCallback),
            ("intervalChange", intervalChange),
            ("manualCover", manualCover),
            ("sleepReset", sleepReset),
            ("awakeTimer", awakeTimer),
            ("awakeTimerPersistence", awakeTimerPersistence),
            ("shortcutValidation", shortcutValidation),
            ("currentSettings", currentSettings),
            ("migration", migration),
            ("independentSleep", independentSleep),
            ("sleepArguments", sleepArguments),
        ]
        for (name, test) in tests {
            try test()
            print("PASS: \(name)")
        }
        print("PASS: \(tests.count) schedule tests")
    }

    private static func firstInterval() throws {
        let settings = VeilSettings.defaults
        try expect(settings.enabled && settings.intervalMinutes == 10, "Unexpected defaults")
        var scheduler = VeilSchedule()
        let start = date(10)
        try expect(!scheduler.tick(now: start, settings: settings, idleSeconds: 0, calendar: utc), "Enabling must wait a full interval")
        try expect(scheduler.active && scheduler.nextCover == date(10, 10), "First due time must be ten minutes later")
        try expect(!scheduler.tick(now: date(10, 9, 59), settings: settings, idleSeconds: 599, calendar: utc), "Must not fire early")
        try expect(scheduler.tick(now: date(10, 10), settings: settings, idleSeconds: 600, calendar: utc), "Must fire at exact due time")
        try expect(scheduler.nextCover == date(10, 20), "Next interval must advance")
    }

    private static func overdueCallback() throws {
        var scheduler = VeilSchedule()
        _ = scheduler.tick(now: date(10), settings: .defaults, idleSeconds: 0, calendar: utc)
        try expect(scheduler.tick(now: date(12), settings: .defaults, idleSeconds: 7200, calendar: utc), "One late callback should cover once")
        try expect(scheduler.nextCover == date(12, 10), "Late callback starts a fresh interval")
        try expect(!scheduler.tick(now: date(12), settings: .defaults, idleSeconds: 7200, calendar: utc), "Same timestamp must not drain a backlog")
        try expect(!scheduler.tick(now: date(12, 1), settings: .defaults, idleSeconds: 7260, calendar: utc), "No immediate catch-up cover")
    }

    private static func intervalChange() throws {
        var scheduler = VeilSchedule()
        _ = scheduler.tick(now: date(10), settings: .defaults, idleSeconds: 0, calendar: utc)
        scheduler.reset()
        try expect(!scheduler.active && scheduler.nextCover == nil, "Reset clears state")
        let settings = VeilSettings(intervalMinutes: 3)
        _ = scheduler.tick(now: date(10, 2), settings: settings, idleSeconds: 120, calendar: utc)
        try expect(scheduler.nextCover == date(10, 3), "Changed interval remains measured from the last input at 10:00")
    }

    private static func manualCover() throws {
        var scheduler = VeilSchedule()
        scheduler.didCover(at: date(10), settings: .defaults)
        try expect(scheduler.nextCover == nil && !scheduler.active, "Manual cover must not enable a disabled scheduler")
        _ = scheduler.tick(now: date(10), settings: .defaults, idleSeconds: 0, calendar: utc)
        scheduler.didCover(at: date(10, 5), settings: .defaults)
        try expect(scheduler.nextCover == date(10, 15), "Manual cover restarts interval")
        try expect(!scheduler.tick(now: date(10, 10), settings: .defaults, idleSeconds: 600, calendar: utc), "Old due time must no longer cover")
    }

    private static func sleepReset() throws {
        var activity = UserActivity()
        var scheduler = VeilSchedule()
        activity.reset(uptime: 1000)
        let atWake = activity.elapsed(systemIdle: 14_400, uptime: 1000)
        try expect(!scheduler.tick(now: date(14), settings: .defaults, idleSeconds: atWake, calendar: utc), "Sleep time must not trigger an immediate cover on wake")
        try expect(scheduler.nextCover == date(14, 10), "Wake starts a full quiet interval")
        let later = activity.elapsed(systemIdle: 15_000, uptime: 1600)
        try expect(scheduler.tick(now: date(14, 10), settings: .defaults, idleSeconds: later, calendar: utc), "A full quiet interval after wake is eligible")
        try expect(activity.elapsed(systemIdle: 2, uptime: 1602) == 2, "New input after wake takes precedence over elapsed wake time")
        activity.reset(uptime: 2000)
        try expect(activity.elapsed(systemIdle: 3000, uptime: 2001) == 1, "A later session resume resets the cap again")
    }

    private static func latestInput() throws {
        let settings = VeilSettings(intervalMinutes: 5)
        var scheduler = VeilSchedule()
        try expect(!scheduler.tick(now: date(10, 4), settings: settings, idleSeconds: 240, calendar: utc), "Four quiet minutes must wait")
        try expect(scheduler.nextCover == date(10, 5), "Initial deadline follows the input at 10:00")
        // A mouse, keyboard, or trackpad event arrives at 10:04:59.
        try expect(!scheduler.tick(now: date(10, 5), settings: settings, idleSeconds: 1, calendar: utc), "Input just before the old deadline must cancel that deadline")
        try expect(scheduler.nextCover == date(10, 9, 59), "Five minutes must be measured from the latest event")
        try expect(!scheduler.tick(now: date(10, 9, 58), settings: settings, idleSeconds: 299, calendar: utc), "The restarted delay must not fire early")
        try expect(scheduler.tick(now: date(10, 9, 59), settings: settings, idleSeconds: 300, calendar: utc), "Exactly five quiet minutes permits blackout")
    }

    private static func continuousInput() throws {
        let settings = VeilSettings(intervalMinutes: 5)
        var scheduler = VeilSchedule()
        for minute in 0..<60 {
            let now = date(10).addingTimeInterval(TimeInterval(minute * 60))
            let idle = TimeInterval(minute % 4)
            try expect(!scheduler.tick(now: now, settings: settings, idleSeconds: idle, calendar: utc), "An hour of ongoing input must never black out")
        }
    }

    private static func launchIdle() throws {
        let activity = UserActivity()
        let settings = VeilSettings(intervalMinutes: 5)
        var scheduler = VeilSchedule()
        let idle = activity.elapsed(systemIdle: 240, uptime: 20_000)
        try expect(!scheduler.tick(now: date(10), settings: settings, idleSeconds: idle, calendar: utc), "Launch after four quiet minutes waits only the remaining minute")
        try expect(scheduler.nextCover == date(10, 1), "App launch must not restart the input clock")
        var alreadyIdle = VeilSchedule()
        try expect(alreadyIdle.tick(now: date(10), settings: settings, idleSeconds: 600, calendar: utc), "Launch after sufficient inactivity can cover immediately")
    }

    private static func invalidIdleSamples() throws {
        let activity = UserActivity()
        let settings = VeilSettings(intervalMinutes: 5)
        for invalid in [-1.0, Double.nan, Double.infinity, -Double.infinity] {
            var scheduler = VeilSchedule()
            try expect(activity.elapsed(systemIdle: invalid, uptime: 1000) == 0, "Invalid system readings must behave as recent input")
            try expect(!scheduler.tick(now: date(10), settings: settings, idleSeconds: invalid, calendar: utc), "Invalid samples cannot black out")
        }
    }

    private static func awakeTimer() throws {
        var awake = AwakeSettings(timerEnabled: true, durationMinutes: 30)
        try expect(awake.isActive(at: date(9), calendar: utc) && awake.expiresAt == nil, "Read-only eligibility must not start a timer")
        try expect(awake.update(at: date(9), calendar: utc), "Eligible timer should start")
        try expect(awake.expiresAt == date(9, 30), "Deadline must use selected duration")
        try expect(awake.update(at: date(9, 15), calendar: utc), "Timer remains active before expiry")
        try expect(awake.expiresAt == date(9, 30), "Ticks must not renew the deadline")
        try expect(!awake.isActive(at: date(9, 30), calendar: utc), "Read-only state must exclude exact expiry")
        try expect(!awake.update(at: date(9, 30), calendar: utc), "Exact expiry stops assertion")
        try expect(!awake.enabled && awake.expiresAt == nil, "Expiry must turn off the toggle and clear deadline")
        try expect(!awake.update(at: date(10), calendar: utc), "Later ticks must not restart an expired timer")
        awake.enabled = true
        try expect(awake.update(at: date(11), calendar: utc), "Explicitly enabling again starts a new session")
        try expect(awake.expiresAt == date(11, 30), "Restart deadline begins at explicit activation")
    }

    private static func awakeTimerPersistence() throws {
        var settings = VeilSettings(awake: AwakeSettings(timerEnabled: true, durationMinutes: 60))
        _ = settings.awake.update(at: date(10), calendar: utc)
        let saved = try JSONEncoder().encode(settings)
        var relaunched = try JSONDecoder().decode(VeilSettings.self, from: saved)
        try expect(relaunched.awake.update(at: date(10, 45), calendar: utc), "Restart before deadline must keep assertion active")
        try expect(relaunched.awake.expiresAt == date(11), "Relaunch must preserve original deadline")
        var lateRelaunch = try JSONDecoder().decode(VeilSettings.self, from: saved)
        try expect(!lateRelaunch.awake.update(at: date(12), calendar: utc), "Relaunch after expiry must stay off")
        try expect(!lateRelaunch.awake.enabled && lateRelaunch.awake.expiresAt == nil, "Expired persisted state must be consumed")
    }

    private static func shortcutValidation() throws {
        for shortcut in [KeyboardShortcut(keyCode: 999, modifiers: KeyboardShortcut.command),
                         KeyboardShortcut(keyCode: 11, modifiers: KeyboardShortcut.shift),
                         KeyboardShortcut(keyCode: 11, modifiers: UInt32.max)] {
            try expect(!shortcut.isValid, "Unsupported keys and plain typing must not be global shortcuts")
            var settings = VeilSettings(intervalMinutes: 25, shortcut: shortcut)
            settings = settings.validated()
            try expect(settings.shortcut == .defaults && settings.intervalMinutes == 25, "Invalid shortcut must not discard other settings")
        }
        let malformed = try JSONDecoder().decode(VeilSettings.self, from: Data(#"{"intervalMinutes":25,"shortcut":{"keyCode":"bad"}}"#.utf8))
        try expect(malformed.intervalMinutes == 25 && malformed.shortcut == .defaults, "Malformed shortcut must recover without losing other settings")
        try expect(KeyboardShortcut.defaults.displayName == "⌃⌥⌘B", "Default shortcut must remain familiar")
        try expect(KeyboardShortcut(keyCode: 122, modifiers: KeyboardShortcut.control).isValid, "Function-key combinations must be supported")
    }

    private static func currentSettings() throws {
        let defaults = try JSONDecoder().decode(VeilSettings.self, from: Data("{}".utf8))
        try expect(defaults == .defaults, "Empty record uses current defaults")
        try expect(defaults.awake.keepDisplayOn && defaults.iconAction == .blackOut, "Display stays on and icon blacks out by default")
        let edited = VeilSettings(enabled: false, intervalMinutes: 25,
            awake: AwakeSettings(enabled: true, keepDisplayOn: false, timerEnabled: true, durationMinutes: 40, expiresAt: date(12)),
            iconAction: .openMenu, requireAuthentication: true,
            shortcut: KeyboardShortcut(keyCode: 45, modifiers: KeyboardShortcut.command | KeyboardShortcut.shift))
        let restored = try JSONDecoder().decode(VeilSettings.self, from: JSONEncoder().encode(edited))
        try expect(restored == edited, "Current preferences and deadlines round trip")
        try expect(VeilSettings(intervalMinutes: Int.max, awake: AwakeSettings(durationMinutes: -2)).validated().intervalMinutes == 1440, "Blackout maximum clamps")
        try expect(edited.awake.validated().durationMinutes == 40 && AwakeSettings(durationMinutes: -2).validated().durationMinutes == 1, "Sleep duration validation")
    }

    private static func migration() throws {
        for (legacy, current) in [("cover", IconAction.blackOut), ("both", .blackOut), ("awake", .toggleSleep)] {
            let record = "{\"enabled\":false,\"intervalMinutes\":15,\"passwordProtection\":true,\"dismissOnMouseMove\":true,\"scheduleEnabled\":true,\"startMinute\":1320,\"endMinute\":420,\"iconAction\":\"" + legacy + "\",\"awake\":{\"enabled\":true,\"timerEnabled\":true,\"durationMinutes\":25,\"scheduleEnabled\":true}}"
            let migrated = try JSONDecoder().decode(VeilSettings.self, from: Data(record.utf8))
            try expect(!migrated.enabled && migrated.intervalMinutes == 15 && migrated.requireAuthentication, "Migration preserves blackout and authentication choices")
            try expect(migrated.iconAction == current && migrated.awake.enabled && migrated.awake.keepDisplayOn, "Legacy icon mapping and independent awake preserved")
            var awake = migrated.awake
            try expect(awake.update(at: date(12)) && awake.expiresAt == date(12, 25), "Removed hours do not delay timer")
            let saved = String(decoding: try JSONEncoder().encode(migrated), as: UTF8.self)
            for obsolete in ["scheduleEnabled", "startMinute", "endMinute", "dismissOnMouseMove", "passwordProtection"] {
                try expect(!saved.contains(obsolete), "Saved settings must omit obsolete fields")
            }
        }
        let explicit = try JSONDecoder().decode(VeilSettings.self, from: Data(#"{"requireAuthentication":false,"passwordProtection":true}"#.utf8))
        try expect(!explicit.requireAuthentication, "Current authentication preference overrides legacy value")
        let oldest = try JSONDecoder().decode(VeilSettings.self, from: Data(#"{"enabled":false,"scheduleEnabled":true}"#.utf8))
        try expect(!oldest.awake.enabled, "Old shared switch migrates once")
        for action in IconAction.allCases {
            var settings = VeilSettings.defaults
            settings.iconAction = action
            let restored = try JSONDecoder().decode(VeilSettings.self, from: JSONEncoder().encode(settings))
            try expect(restored == settings, "All current icon actions persist")
        }
    }

    private static func independentSleep() throws {
        var settings = VeilSettings(enabled: false, awake: AwakeSettings(timerEnabled: true, durationMinutes: 20))
        try expect(settings.awake.update(at: date(10)), "Sleep prevention starts while blackout disabled")
        settings.enabled = true
        try expect(settings.awake.update(at: date(10, 10)) && settings.awake.expiresAt == date(10, 20), "Blackout changes do not restart sleep timer")
        settings.awake.durationMinutes = 5
        settings.awake.expiresAt = nil
        try expect(settings.awake.update(at: date(10, 10)) && settings.awake.expiresAt == date(10, 15), "Duration edit starts its new duration now")
        settings.awake.enabled = false
        try expect(!settings.awake.update(at: date(10, 11)) && settings.awake.expiresAt == nil && settings.enabled, "Stopping sleep clears only its deadline")
        settings.awake.enabled = true
        settings.awake.timerEnabled = false
        settings.awake.expiresAt = date(9)
        try expect(settings.awake.update(at: date(10)) && settings.awake.expiresAt == nil, "No limit clears stale deadline")
    }

    private static func sleepArguments() throws {
        try expect(SleepPrevention.arguments(settings: .defaults, now: date(10), parentPID: 123) == ["-di", "-w", "123"], "Default assertion includes display and parent lifetime")
        let macOnly = AwakeSettings(keepDisplayOn: false)
        try expect(SleepPrevention.arguments(settings: macOnly, now: date(10), parentPID: 123) == ["-i", "-w", "123"], "Mac-only assertion allows display sleep")
        let finite = AwakeSettings(timerEnabled: true, durationMinutes: 60, expiresAt: date(10).addingTimeInterval(1.2))
        try expect(SleepPrevention.arguments(settings: finite, now: date(10), parentPID: 123) == ["-di", "-w", "123", "-t", "2"], "Finite assertion rounds remaining seconds up")
        try expect(SleepPrevention.arguments(settings: finite, now: date(10, 0, 2)) == nil, "Expired assertion cannot start")
        try expect(SleepPrevention.arguments(settings: AwakeSettings(enabled: false)) == nil, "Disabled assertion cannot start")
        let pending = AwakeSettings(timerEnabled: true, durationMinutes: 3)
        try expect(SleepPrevention.arguments(settings: pending, now: date(10), parentPID: 123)?.suffix(2) == ["-t", "180"], "Pending timer also has a finite process bound")
    }

}
