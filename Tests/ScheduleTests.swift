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
            ("defaults and first interval", firstInterval),
            ("daytime schedule boundaries", daytimeBoundaries),
            ("overnight schedule boundaries", overnightBoundaries),
            ("disabled and all-day states", activationStates),
            ("schedule uses the supplied local time zone", localTimeZone),
            ("repeated daylight-saving hour", daylightSavingHour),
            ("settings validation and persistence", validationAndPersistence),
            ("legacy settings preserve values and gain defaults", legacySettings),
            ("late callback emits once", overdueCallback),
            ("end of schedule cancels a due cover", endCancelsCover),
            ("next day starts a new interval", nextDay),
            ("settings reset applies new interval", intervalChange),
            ("manual cover postpones the next cover", manualCover),
            ("reset discards elapsed sleep time", sleepReset),
            ("awake and cover controls are independent", independentAwake),
            ("awake timer starts once and expires", awakeTimer),
            ("awake deadline survives relaunch", awakeTimerPersistence),
            ("awake timer waits for its operating hours", awakeTimerPending),
            ("awake deadline runs outside operating hours", awakeTimerOutsideHours),
            ("disabling awake or its timer clears the deadline", awakeTimerDisabled),
            ("awake overnight and equal-time schedules", awakeScheduleBoundaries),
            ("awake defaults validation and partial decoding", awakeDefaults),
            ("interaction preferences migrate and persist", interactionPreferences),
            ("shortcut validation preserves safe defaults", shortcutValidation),
        ]
        for (name, test) in tests {
            try test()
            print("PASS: \(name)")
        }
        print("PASS: \(tests.count) schedule tests")
    }

    private static func firstInterval() throws {
        let settings = VeilSettings.defaults
        try expect(settings.enabled && settings.intervalMinutes == 10 && !settings.scheduleEnabled && settings.hideMenuBar, "Unexpected defaults")
        var scheduler = VeilSchedule()
        let start = date(10)
        try expect(!scheduler.tick(now: start, settings: settings, calendar: utc), "Enabling must wait a full interval")
        try expect(scheduler.active && scheduler.nextCover == date(10, 10), "First due time must be ten minutes later")
        try expect(!scheduler.tick(now: date(10, 9, 59), settings: settings, calendar: utc), "Must not fire early")
        try expect(scheduler.tick(now: date(10, 10), settings: settings, calendar: utc), "Must fire at exact due time")
        try expect(scheduler.nextCover == date(10, 20), "Next interval must advance")
    }

    private static func daytimeBoundaries() throws {
        let settings = VeilSettings(scheduleEnabled: true, startMinute: 9 * 60, endMinute: 17 * 60)
        try expect(!settings.isActive(at: date(8, 59, 59), calendar: utc), "Before daytime start must be inactive")
        try expect(settings.isActive(at: date(9), calendar: utc), "Daytime start must be included")
        try expect(settings.isActive(at: date(16, 59, 59), calendar: utc), "Last minute must be included")
        try expect(!settings.isActive(at: date(17), calendar: utc), "Daytime end must be excluded")
    }

    private static func overnightBoundaries() throws {
        let settings = VeilSettings(scheduleEnabled: true)
        try expect(!settings.isActive(at: date(21, 59, 59), calendar: utc), "Before night start must be inactive")
        try expect(settings.isActive(at: date(22), calendar: utc), "Night start must be included")
        try expect(settings.isActive(at: date(0, day: 29), calendar: utc), "Midnight must remain active")
        try expect(settings.isActive(at: date(6, 59, 59, day: 29), calendar: utc), "Last night minute must be active")
        try expect(!settings.isActive(at: date(7, day: 29), calendar: utc), "Night end must be excluded")
    }

    private static func activationStates() throws {
        let disabled = VeilSettings(enabled: false)
        let allDay = VeilSettings(scheduleEnabled: true, startMinute: 300, endMinute: 300)
        let noSchedule = VeilSettings(scheduleEnabled: false, startMinute: 300, endMinute: 301)
        for hour in [0, 5, 12, 23] {
            try expect(!disabled.isActive(at: date(hour), calendar: utc), "Off must override any time")
            try expect(allDay.isActive(at: date(hour), calendar: utc), "Equal endpoints mean all day")
            try expect(noSchedule.isActive(at: date(hour), calendar: utc), "Disabled time restriction means all day")
        }
        var scheduler = VeilSchedule()
        _ = scheduler.tick(now: date(10), settings: .defaults, calendar: utc)
        try expect(!scheduler.tick(now: date(10, 10), settings: disabled, calendar: utc), "Turning off at due time must not cover")
        try expect(!scheduler.active && scheduler.nextCover == nil, "Off must clear the scheduled cover")
    }

    private static func localTimeZone() throws {
        var seoul = utc
        seoul.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let settings = VeilSettings(scheduleEnabled: true)
        try expect(settings.isActive(at: date(13), calendar: seoul), "13:00 UTC is 22:00 Seoul")
        try expect(!settings.isActive(at: date(13), calendar: utc), "The same instant is outside the UTC schedule")
    }

    private static func daylightSavingHour() throws {
        var calendar = utc
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let settings = VeilSettings(scheduleEnabled: true, startMinute: 60, endMinute: 120)
        let first = utc.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 8, minute: 30))!
        let repeated = first.addingTimeInterval(3_600)
        try expect(settings.isActive(at: first, calendar: calendar), "First local 01:30 must be active")
        try expect(settings.isActive(at: repeated, calendar: calendar), "Repeated local 01:30 must be active")
        try expect(!settings.isActive(at: repeated.addingTimeInterval(1_800), calendar: calendar), "Local 02:00 must be excluded")
    }

    private static func validationAndPersistence() throws {
        let low = VeilSettings(intervalMinutes: -10, startMinute: -1, endMinute: -200).validated()
        try expect(low.intervalMinutes == 1 && low.startMinute == 0 && low.endMinute == 0, "Negative values must clamp")
        let high = VeilSettings(intervalMinutes: Int.max, startMinute: 2_000, endMinute: 5_000).validated()
        try expect(high.intervalMinutes == 1_440 && high.startMinute == 1_439 && high.endMinute == 1_439, "Oversized values must clamp")
        let custom = VeilSettings(enabled: false, intervalMinutes: 25, scheduleEnabled: true, startMinute: 123, endMinute: 456, hideMenuBar: false)
        let restored = try JSONDecoder().decode(VeilSettings.self, from: JSONEncoder().encode(custom))
        try expect(restored == custom, "Saved preferences must round-trip without changing values")
        try expect(!restored.hideMenuBar && !restored.validated().hideMenuBar, "False menu bar choice must survive persistence and validation")
    }

    private static func legacySettings() throws {
        let legacy = Data(#"{"enabled":false,"intervalMinutes":5,"scheduleEnabled":true,"startMinute":1380,"endMinute":420}"#.utf8)
        let settings = try JSONDecoder().decode(VeilSettings.self, from: legacy)
        let migratedAwake = AwakeSettings(enabled: false, scheduleEnabled: true, startMinute: 1380, endMinute: 420)
        try expect(settings == VeilSettings(enabled: false, intervalMinutes: 5, scheduleEnabled: true, startMinute: 1380, endMinute: 420, hideMenuBar: true, awake: migratedAwake), "Legacy values and the old sleep-prevention state/hours must be retained")
        try expect(!settings.awake.timerEnabled && settings.awake.expiresAt == nil, "Migration must not create a finite timer")
        let legacyOn = try JSONDecoder().decode(VeilSettings.self, from: Data(#"{"enabled":true,"scheduleEnabled":true,"startMinute":1320,"endMinute":420}"#.utf8))
        try expect(legacyOn.awake.enabled && legacyOn.awake.isActive(at: date(23), calendar: utc), "Legacy enabled overnight sleep prevention must stay enabled")
        try expect(!legacyOn.awake.isActive(at: date(12), calendar: utc), "Legacy operating hours must also carry over")
        let empty = try JSONDecoder().decode(VeilSettings.self, from: Data("{}".utf8))
        try expect(empty == .defaults, "Missing preferences must use intrinsic defaults, including interval ten")
        let partial = try JSONDecoder().decode(VeilSettings.self, from: Data(#"{"hideMenuBar":false}"#.utf8))
        try expect(!partial.hideMenuBar && partial.intervalMinutes == 10 && partial.enabled, "A partial record must retain explicit false and default other values")
    }

    private static func overdueCallback() throws {
        var scheduler = VeilSchedule()
        _ = scheduler.tick(now: date(10), settings: .defaults, calendar: utc)
        try expect(scheduler.tick(now: date(12), settings: .defaults, calendar: utc), "One late callback should cover once")
        try expect(scheduler.nextCover == date(12, 10), "Late callback starts a fresh interval")
        try expect(!scheduler.tick(now: date(12), settings: .defaults, calendar: utc), "Same timestamp must not drain a backlog")
        try expect(!scheduler.tick(now: date(12, 1), settings: .defaults, calendar: utc), "No immediate catch-up cover")
    }

    private static func endCancelsCover() throws {
        let settings = VeilSettings(scheduleEnabled: true, startMinute: 9 * 60, endMinute: 17 * 60)
        var scheduler = VeilSchedule()
        _ = scheduler.tick(now: date(16, 50), settings: settings, calendar: utc)
        try expect(!scheduler.tick(now: date(17), settings: settings, calendar: utc), "Schedule end wins over an exactly due cover")
        try expect(scheduler.nextCover == nil && !scheduler.active, "End clears active state")
    }

    private static func nextDay() throws {
        let settings = VeilSettings(scheduleEnabled: true, startMinute: 9 * 60, endMinute: 17 * 60)
        var scheduler = VeilSchedule()
        _ = scheduler.tick(now: date(16, 50), settings: settings, calendar: utc)
        _ = scheduler.tick(now: date(17), settings: settings, calendar: utc)
        try expect(!scheduler.tick(now: date(9, day: 29), settings: settings, calendar: utc), "Reentering time range waits a full interval")
        try expect(scheduler.nextCover == date(9, 10, day: 29), "New day must have a new due time")
    }

    private static func intervalChange() throws {
        var scheduler = VeilSchedule()
        _ = scheduler.tick(now: date(10), settings: .defaults, calendar: utc)
        scheduler.reset()
        try expect(!scheduler.active && scheduler.nextCover == nil, "Reset clears state")
        let settings = VeilSettings(intervalMinutes: 3)
        _ = scheduler.tick(now: date(10, 2), settings: settings, calendar: utc)
        try expect(scheduler.nextCover == date(10, 5), "Changed interval starts at reset time")
    }

    private static func manualCover() throws {
        var scheduler = VeilSchedule()
        scheduler.didCover(at: date(10), settings: .defaults)
        try expect(scheduler.nextCover == nil && !scheduler.active, "Manual cover must not enable a disabled scheduler")
        _ = scheduler.tick(now: date(10), settings: .defaults, calendar: utc)
        scheduler.didCover(at: date(10, 5), settings: .defaults)
        try expect(scheduler.nextCover == date(10, 15), "Manual cover restarts interval")
        try expect(!scheduler.tick(now: date(10, 10), settings: .defaults, calendar: utc), "Old due time must no longer cover")
    }

    private static func sleepReset() throws {
        var scheduler = VeilSchedule()
        _ = scheduler.tick(now: date(10), settings: .defaults, calendar: utc)
        scheduler.reset()
        try expect(!scheduler.tick(now: date(14), settings: .defaults, calendar: utc), "Wake must not immediately replay overdue cover")
        try expect(scheduler.nextCover == date(14, 10), "Wake starts a full interval")
    }

    private static func independentAwake() throws {
        var settings = VeilSettings(
            scheduleEnabled: true, startMinute: 9 * 60, endMinute: 17 * 60,
            awake: AwakeSettings(scheduleEnabled: true)
        )
        try expect(settings.isActive(at: date(10), calendar: utc), "Cover has daytime hours")
        try expect(!settings.awake.update(at: date(10), calendar: utc), "Awake has separate overnight hours")
        try expect(!settings.isActive(at: date(23), calendar: utc), "Cover must stop outside its own hours")
        try expect(settings.awake.update(at: date(23), calendar: utc), "Awake can run while cover is inactive")
        settings.enabled = false
        try expect(settings.awake.update(at: date(23), calendar: utc), "Turning off covers must not stop awake")
        settings.enabled = true
        settings.awake.enabled = false
        try expect(settings.isActive(at: date(10), calendar: utc), "Turning off awake must not stop daytime covers")
        try expect(!settings.awake.update(at: date(23), calendar: utc), "Awake toggle must stop only awake")
        let restored = try JSONDecoder().decode(VeilSettings.self, from: JSONEncoder().encode(settings))
        try expect(restored == settings, "Explicit independent settings must survive saving without legacy migration")
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

    private static func awakeTimerPending() throws {
        var awake = AwakeSettings(timerEnabled: true, durationMinutes: 60, scheduleEnabled: true, startMinute: 9 * 60, endMinute: 17 * 60)
        try expect(!awake.update(at: date(8), calendar: utc), "Enabling outside operating hours must wait")
        try expect(awake.enabled && awake.expiresAt == nil, "Pending timer must not spend its duration early")
        let pending = try JSONEncoder().encode(awake)
        awake = try JSONDecoder().decode(AwakeSettings.self, from: pending)
        try expect(!awake.update(at: date(8, 59, 59), calendar: utc) && awake.expiresAt == nil, "Relaunch while waiting must remain pending")
        try expect(awake.update(at: date(9), calendar: utc), "Operating hours trigger first activation")
        try expect(awake.expiresAt == date(10), "Countdown starts at first actual activation")
    }

    private static func awakeTimerOutsideHours() throws {
        var awake = AwakeSettings(timerEnabled: true, durationMinutes: 60, scheduleEnabled: true, startMinute: 9 * 60, endMinute: 17 * 60)
        _ = awake.update(at: date(16, 30), calendar: utc)
        try expect(!awake.update(at: date(17), calendar: utc), "Daily end releases assertion")
        try expect(awake.enabled && awake.expiresAt == date(17, 30), "Daily end must retain the running deadline")
        try expect(!awake.update(at: date(17, 30), calendar: utc), "Deadline must expire even outside operating hours")
        try expect(!awake.enabled && awake.expiresAt == nil, "Outside-hours expiry must disable awake")
        try expect(!awake.update(at: date(9, day: 29), calendar: utc), "Expired timer must not restart next day")

        var longTimer = AwakeSettings(timerEnabled: true, durationMinutes: 1_440, scheduleEnabled: true)
        _ = longTimer.update(at: date(23), calendar: utc)
        try expect(!longTimer.update(at: date(8, day: 29), calendar: utc), "Overnight timer pauses assertion during daytime")
        try expect(longTimer.update(at: date(22, day: 29), calendar: utc), "Unexpired timer can reenter operating hours")
        try expect(longTimer.expiresAt == date(23, day: 29), "Reentering hours must not renew original deadline")
    }

    private static func awakeTimerDisabled() throws {
        var awake = AwakeSettings(timerEnabled: true, expiresAt: date(11))
        awake.enabled = false
        try expect(!awake.update(at: date(10), calendar: utc) && awake.expiresAt == nil, "Disabling awake must clear its timer")
        awake = AwakeSettings(timerEnabled: false, expiresAt: date(9))
        try expect(awake.update(at: date(10), calendar: utc), "Disabling timer chooses indefinite operation")
        try expect(awake.enabled && awake.expiresAt == nil, "A stale deadline must not turn off indefinite operation")
        awake = AwakeSettings(timerEnabled: false, scheduleEnabled: true, expiresAt: date(11))
        try expect(!awake.update(at: date(10), calendar: utc), "Indefinite awake still respects hours")
        try expect(awake.enabled && awake.expiresAt == nil, "Timer disabled outside hours still clears deadline")
    }

    private static func awakeScheduleBoundaries() throws {
        let overnight = AwakeSettings(scheduleEnabled: true)
        try expect(!overnight.isWithinSchedule(at: date(21, 59, 59), calendar: utc), "Awake night start must be exact")
        try expect(overnight.isWithinSchedule(at: date(22), calendar: utc), "Awake start is included")
        try expect(overnight.isWithinSchedule(at: date(0), calendar: utc), "Awake schedule crosses midnight")
        try expect(!overnight.isWithinSchedule(at: date(7), calendar: utc), "Awake end is excluded")
        let allDay = AwakeSettings(scheduleEnabled: true, startMinute: 100, endMinute: 100)
        for hour in [0, 2, 12, 23] {
            try expect(allDay.isWithinSchedule(at: date(hour), calendar: utc), "Equal awake endpoints mean all day")
        }
    }

    private static func awakeDefaults() throws {
        let empty = try JSONDecoder().decode(AwakeSettings.self, from: Data("{}".utf8))
        try expect(empty == .defaults && empty.enabled && !empty.timerEnabled && empty.durationMinutes == 60, "Missing awake fields must use defaults")
        let partial = try JSONDecoder().decode(AwakeSettings.self, from: Data(#"{"enabled":false,"durationMinutes":30}"#.utf8))
        try expect(!partial.enabled && partial.durationMinutes == 30 && partial.startMinute == 1320, "Partial awake record must preserve explicit values")
        let nested = try JSONDecoder().decode(VeilSettings.self, from: Data(#"{"enabled":false,"scheduleEnabled":true,"awake":{}}"#.utf8))
        try expect(nested.awake == .defaults, "Present awake settings must not inherit cover controls")
        let invalid = AwakeSettings(timerEnabled: true, durationMinutes: Int.max, startMinute: -10, endMinute: 2_000, expiresAt: date(15))
        let normalized = VeilSettings(awake: invalid).validated().awake
        try expect(normalized.durationMinutes == 1_440 && normalized.startMinute == 0 && normalized.endMinute == 1_439, "Nested awake values must clamp")
        try expect(normalized.expiresAt == date(15), "Validation must preserve a running timer deadline")
        try expect(AwakeSettings(durationMinutes: -10).validated().durationMinutes == 1, "Timer minimum is one minute")
        let restored = try JSONDecoder().decode(AwakeSettings.self, from: JSONEncoder().encode(normalized))
        try expect(restored == normalized, "Full awake settings and deadline must round-trip")
    }
    private static func interactionPreferences() throws {
        let legacy = try JSONDecoder().decode(VeilSettings.self, from: Data(#"{"enabled":false,"intervalMinutes":15,"iconAction":"awake","awake":{"enabled":true,"timerEnabled":true,"durationMinutes":25}}"#.utf8))
        try expect(legacy.dismissOnMouseMove && legacy.shortcut == .defaults, "Existing users gain movement dismissal and the existing shortcut")
        try expect(!legacy.enabled && legacy.awake.enabled && legacy.intervalMinutes == 15, "Migration must preserve independent existing settings")
        var edited = legacy
        edited.dismissOnMouseMove = false
        edited.shortcut = KeyboardShortcut(keyCode: 45, modifiers: KeyboardShortcut.command | KeyboardShortcut.shift)
        edited.awake.expiresAt = date(12)
        let restored = try JSONDecoder().decode(VeilSettings.self, from: JSONEncoder().encode(edited)).validated()
        try expect(restored == edited, "Movement opt-out, custom shortcut, and awake deadline must survive relaunch")
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
}
