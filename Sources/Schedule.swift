import Foundation

/// Daily local-time range, inclusive at the start and exclusive at the end.
/// Equal endpoints mean all day, including across daylight-saving changes.
private func withinDailySchedule(
    at date: Date,
    enabled: Bool,
    startMinute: Int,
    endMinute: Int,
    calendar: Calendar
) -> Bool {
    guard enabled, startMinute != endMinute else { return true }
    let components = calendar.dateComponents([.hour, .minute], from: date)
    guard let hour = components.hour, let minute = components.minute else { return false }
    let minuteOfDay = hour * 60 + minute
    if startMinute < endMinute {
        return minuteOfDay >= startMinute && minuteOfDay < endMinute
    }
    return minuteOfDay >= startMinute || minuteOfDay < endMinute
}

struct AwakeSettings: Codable, Equatable, Sendable {
    var enabled = true
    var timerEnabled = false
    var durationMinutes = 60
    var scheduleEnabled = false
    var startMinute = 22 * 60
    var endMinute = 7 * 60
    var expiresAt: Date?

    static let defaults = AwakeSettings()

    func validated() -> AwakeSettings {
        var result = self
        result.durationMinutes = min(max(durationMinutes, 1), 1_440)
        result.startMinute = min(max(startMinute, 0), 1_439)
        result.endMinute = min(max(endMinute, 0), 1_439)
        return result
    }

    func isWithinSchedule(at date: Date, calendar: Calendar = .current) -> Bool {
        let settings = validated()
        return withinDailySchedule(
            at: date,
            enabled: settings.scheduleEnabled,
            startMinute: settings.startMinute,
            endMinute: settings.endMinute,
            calendar: calendar
        )
    }

    /// A timer without a deadline is pending its first activation.
    /// Use `update` to start or expire it and persist any changed settings.
    func isActive(at date: Date, calendar: Calendar = .current) -> Bool {
        guard enabled, isWithinSchedule(at: date, calendar: calendar) else { return false }
        if timerEnabled, let expiresAt, date >= expiresAt { return false }
        return true
    }

    /// The finite timer measures elapsed time, including hours outside the daily
    /// range. It starts only on the first actual activation and never renews on
    /// tick, wake, or relaunch. The app persists the resulting deadline/state.
    mutating func update(at date: Date, calendar: Calendar = .current) -> Bool {
        self = validated()
        guard enabled else {
            expiresAt = nil
            return false
        }
        guard timerEnabled else {
            expiresAt = nil
            return isWithinSchedule(at: date, calendar: calendar)
        }
        if let expiresAt, date >= expiresAt {
            enabled = false
            self.expiresAt = nil
            return false
        }
        guard isWithinSchedule(at: date, calendar: calendar) else { return false }
        if expiresAt == nil {
            expiresAt = date.addingTimeInterval(TimeInterval(durationMinutes * 60))
        }
        return true
    }
}

extension AwakeSettings {
    private enum CodingKeys: String, CodingKey {
        case enabled, timerEnabled, durationMinutes, scheduleEnabled, startMinute, endMinute, expiresAt
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            enabled: try values.decodeIfPresent(Bool.self, forKey: .enabled) ?? Self.defaults.enabled,
            timerEnabled: try values.decodeIfPresent(Bool.self, forKey: .timerEnabled) ?? Self.defaults.timerEnabled,
            durationMinutes: try values.decodeIfPresent(Int.self, forKey: .durationMinutes) ?? Self.defaults.durationMinutes,
            scheduleEnabled: try values.decodeIfPresent(Bool.self, forKey: .scheduleEnabled) ?? Self.defaults.scheduleEnabled,
            startMinute: try values.decodeIfPresent(Int.self, forKey: .startMinute) ?? Self.defaults.startMinute,
            endMinute: try values.decodeIfPresent(Int.self, forKey: .endMinute) ?? Self.defaults.endMinute,
            expiresAt: try values.decodeIfPresent(Date.self, forKey: .expiresAt)
        )
    }
}

enum IconAction: String, Codable, CaseIterable, Sendable {
    case cover, awake, both
}

struct VeilSettings: Codable, Equatable, Sendable {
    var enabled = true
    var intervalMinutes = 10
    var scheduleEnabled = false
    var startMinute = 22 * 60
    var endMinute = 7 * 60
    var hideMenuBar = true
    var awake = AwakeSettings.defaults
    var iconAction = IconAction.both

    static let defaults = VeilSettings()

    var iconFeaturesEnabled: Bool {
        switch iconAction {
        case .cover: return enabled
        case .awake: return awake.enabled
        case .both: return enabled || awake.enabled
        }
    }

    mutating func toggleIconFeatures() {
        // If any selected feature is on, one click stops the selected group.
        // Features outside the selected group keep their existing state.
        let turnOn = !iconFeaturesEnabled
        if iconAction != .awake { enabled = turnOn }
        if iconAction != .cover { awake.enabled = turnOn }
    }

    func validated() -> VeilSettings {
        var result = self
        result.intervalMinutes = min(max(intervalMinutes, 1), 1_440)
        result.startMinute = min(max(startMinute, 0), 1_439)
        result.endMinute = min(max(endMinute, 0), 1_439)
        result.awake = awake.validated()
        return result
    }

    func isActive(at date: Date, calendar: Calendar = .current) -> Bool {
        let settings = validated()
        guard settings.enabled else { return false }
        return withinDailySchedule(
            at: date,
            enabled: settings.scheduleEnabled,
            startMinute: settings.startMinute,
            endMinute: settings.endMinute,
            calendar: calendar
        )
    }
}

extension VeilSettings {
    private enum CodingKeys: String, CodingKey {
        case enabled, intervalMinutes, scheduleEnabled, startMinute, endMinute, hideMenuBar, awake, iconAction
    }

    /// Preserve saved settings when a newer version adds an optional preference.
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            enabled: try values.decodeIfPresent(Bool.self, forKey: .enabled) ?? Self.defaults.enabled,
            intervalMinutes: try values.decodeIfPresent(Int.self, forKey: .intervalMinutes) ?? Self.defaults.intervalMinutes,
            scheduleEnabled: try values.decodeIfPresent(Bool.self, forKey: .scheduleEnabled) ?? Self.defaults.scheduleEnabled,
            startMinute: try values.decodeIfPresent(Int.self, forKey: .startMinute) ?? Self.defaults.startMinute,
            endMinute: try values.decodeIfPresent(Int.self, forKey: .endMinute) ?? Self.defaults.endMinute,
            hideMenuBar: try values.decodeIfPresent(Bool.self, forKey: .hideMenuBar) ?? Self.defaults.hideMenuBar
        )
        iconAction = try values.decodeIfPresent(IconAction.self, forKey: .iconAction) ?? .both
        if let savedAwake = try values.decodeIfPresent(AwakeSettings.self, forKey: .awake) {
            awake = savedAwake
        } else {
            // Older releases tied sleep prevention to the cover toggle/hours.
            // Copy that behavior once; later updates remain independent.
            awake = AwakeSettings(
                enabled: enabled,
                scheduleEnabled: scheduleEnabled,
                startMinute: startMinute,
                endMinute: endMinute
            )
        }
    }
}

/// The app calls `reset()` after changing settings and on wake.
/// Late timer callbacks emit once and start a fresh interval, never a backlog.
struct VeilSchedule: Sendable {
    private(set) var nextCover: Date?
    private(set) var active = false

    mutating func reset() {
        nextCover = nil
        active = false
    }

    mutating func tick(
        now: Date,
        settings: VeilSettings,
        calendar: Calendar = .current
    ) -> Bool {
        let settings = settings.validated()
        guard settings.isActive(at: now, calendar: calendar) else {
            reset()
            return false
        }

        if !active || nextCover == nil {
            active = true
            nextCover = now.addingTimeInterval(TimeInterval(settings.intervalMinutes * 60))
            return false
        }

        guard let due = nextCover, now >= due else { return false }
        nextCover = now.addingTimeInterval(TimeInterval(settings.intervalMinutes * 60))
        return true
    }

    mutating func didCover(at date: Date, settings: VeilSettings) {
        guard active else { return }
        nextCover = date.addingTimeInterval(TimeInterval(settings.validated().intervalMinutes * 60))
    }
}
