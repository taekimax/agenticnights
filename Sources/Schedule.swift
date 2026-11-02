import Foundation

/// Sleep prevention has one optional elapsed-time deadline, independent of blackout.
struct AwakeSettings: Codable, Equatable, Sendable {
    var enabled = true
    var keepDisplayOn = true
    var timerEnabled = false
    var durationMinutes = 60
    var expiresAt: Date?

    static let defaults = AwakeSettings()

    func validated() -> AwakeSettings {
        var result = self
        result.durationMinutes = min(max(durationMinutes, 1), 1_440)
        return result
    }

    /// A timer without a deadline starts on the next update.
    func isActive(at date: Date, calendar: Calendar = .current) -> Bool {
        enabled && (!timerEnabled || expiresAt.map { date < $0 } != false)
    }

    /// Starts once and expires once. Input, wake, and relaunch do not renew it.
    /// Persist changes after calling this method. Duration edits explicitly clear
    /// the old deadline before updating, so the new duration starts at the edit.
    mutating func update(at date: Date, calendar: Calendar = .current) -> Bool {
        self = validated()
        guard enabled else {
            expiresAt = nil
            return false
        }
        guard timerEnabled else {
            expiresAt = nil
            return true
        }
        if let expiresAt, date >= expiresAt {
            enabled = false
            self.expiresAt = nil
            return false
        }
        if expiresAt == nil {
            expiresAt = date.addingTimeInterval(TimeInterval(durationMinutes * 60))
        }
        return true
    }
}

extension AwakeSettings {
    private enum CodingKeys: String, CodingKey {
        case enabled, keepDisplayOn, timerEnabled, durationMinutes, expiresAt
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            enabled: try values.decodeIfPresent(Bool.self, forKey: .enabled) ?? Self.defaults.enabled,
            keepDisplayOn: try values.decodeIfPresent(Bool.self, forKey: .keepDisplayOn) ?? true,
            timerEnabled: try values.decodeIfPresent(Bool.self, forKey: .timerEnabled) ?? false,
            durationMinutes: try values.decodeIfPresent(Int.self, forKey: .durationMinutes) ?? 60,
            expiresAt: try values.decodeIfPresent(Date.self, forKey: .expiresAt)
        )
    }
}

enum IconAction: String, Codable, CaseIterable, Sendable {
    case openMenu, blackOut, toggleSleep

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        switch value {
        case "openMenu": self = .openMenu
        case "awake", "toggleSleep": self = .toggleSleep
        default: self = .blackOut
        }
    }
}

struct VeilSettings: Codable, Equatable, Sendable {
    var enabled = true
    var intervalMinutes = 10
    var awake = AwakeSettings.defaults
    var iconAction = IconAction.blackOut
    var requireAuthentication = false
    var shortcut = KeyboardShortcut.defaults

    static let defaults = VeilSettings()

    func validated() -> VeilSettings {
        var result = self
        result.intervalMinutes = min(max(intervalMinutes, 1), 1_440)
        result.awake = awake.validated()
        if !shortcut.isValid { result.shortcut = .defaults }
        return result
    }

    func isActive(at date: Date, calendar: Calendar = .current) -> Bool { enabled }
}

extension VeilSettings {
    private enum CodingKeys: String, CodingKey {
        case enabled, intervalMinutes, awake, iconAction, requireAuthentication, shortcut
    }
    private enum LegacyKeys: String, CodingKey { case passwordProtection }

    /// Read obsolete fields once; only current preferences are written back.
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let legacy = try decoder.container(keyedBy: LegacyKeys.self)
        self.init(
            enabled: try values.decodeIfPresent(Bool.self, forKey: .enabled) ?? true,
            intervalMinutes: try values.decodeIfPresent(Int.self, forKey: .intervalMinutes) ?? 10
        )
        requireAuthentication = try values.decodeIfPresent(Bool.self, forKey: .requireAuthentication)
            ?? legacy.decodeIfPresent(Bool.self, forKey: .passwordProtection) ?? false
        iconAction = try values.decodeIfPresent(IconAction.self, forKey: .iconAction) ?? .blackOut
        shortcut = (try? values.decode(KeyboardShortcut.self, forKey: .shortcut)) ?? .defaults
        // Very old releases tied sleep prevention to the blackout switch.
        // Preserve that switch once while discarding obsolete daily hours.
        awake = try values.decodeIfPresent(AwakeSettings.self, forKey: .awake)
            ?? AwakeSettings(enabled: enabled)
    }
}

/// Automatic blackout follows the physical-input inactivity threshold.
func isIdleReady(_ seconds: TimeInterval, settings: VeilSettings) -> Bool {
    seconds.isFinite && seconds >= TimeInterval(settings.validated().intervalMinutes * 60)
}

/// Input postpones blackout until a full quiet interval has elapsed.
/// A manual/automatic cover also prevents repeated covers within one interval.
struct VeilSchedule: Sendable {
    private(set) var nextCover: Date?
    private(set) var active = false
    private var lastCover: Date?

    mutating func reset() {
        nextCover = nil
        active = false
        lastCover = nil
    }

    mutating func tick(
        now: Date,
        settings: VeilSettings,
        idleSeconds: TimeInterval,
        calendar: Calendar = .current
    ) -> Bool {
        let settings = settings.validated()
        guard settings.isActive(at: now, calendar: calendar) else {
            reset()
            return false
        }

        active = true
        let interval = TimeInterval(settings.intervalMinutes * 60)
        let idle = idleSeconds.isFinite && idleSeconds >= 0 ? idleSeconds : 0
        let inputDeadline = now.addingTimeInterval(max(0, interval - idle))
        nextCover = max(inputDeadline, lastCover?.addingTimeInterval(interval) ?? inputDeadline)
        guard isIdleReady(idleSeconds, settings: settings), let due = nextCover, now >= due else { return false }
        didCover(at: now, settings: settings)
        return true
    }

    mutating func didCover(at date: Date, settings: VeilSettings) {
        guard active else { return }
        lastCover = date
        nextCover = date.addingTimeInterval(TimeInterval(settings.validated().intervalMinutes * 60))
    }
}
