// The process-lifetime caffeinate approach is adapted from KeepingYouAwake.
// Copyright (c) 2014 - present Marcel Dierkes. MIT; see THIRD_PARTY_NOTICES.md.
import Foundation

final class SleepPrevention {
    private struct Configuration: Equatable {
        let keepDisplayOn: Bool
        let deadline: Date?
        let pendingDuration: Int?
    }

    private var process: Process?
    private var configuration: Configuration?
    private(set) var lastError: String?

    var isRunning: Bool { process?.isRunning == true }
    var processIdentifier: Int32? { isRunning ? process?.processIdentifier : nil }

    /// The parent PID bounds every assertion; a finite timer also bounds its
    /// lifetime independently if the app's expiry callback runs late.
    static func arguments(
        settings: AwakeSettings,
        now: Date = Date(),
        parentPID: Int32 = ProcessInfo.processInfo.processIdentifier
    ) -> [String]? {
        let settings = settings.validated()
        guard settings.isActive(at: now) else { return nil }
        var result = [settings.keepDisplayOn ? "-di" : "-i", "-w", String(parentPID)]
        if settings.timerEnabled {
            let remaining = settings.expiresAt?.timeIntervalSince(now) ?? TimeInterval(settings.durationMinutes * 60)
            guard remaining.isFinite, remaining > 0, remaining < TimeInterval(Int.max) else { return nil }
            result += ["-t", String(Int(ceil(remaining)))]
        }
        return result
    }

    func start(settings: AwakeSettings, now: Date = Date()) {
        guard let arguments = Self.arguments(settings: settings, now: now) else {
            stop()
            return
        }
        let desired = Configuration(
            keepDisplayOn: settings.keepDisplayOn,
            deadline: settings.timerEnabled ? settings.expiresAt : nil,
            pendingDuration: settings.timerEnabled && settings.expiresAt == nil ? settings.validated().durationMinutes : nil
        )
        guard !isRunning || configuration != desired else { return }
        stop()
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        task.arguments = arguments
        do {
            try task.run()
            process = task
            configuration = desired
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func stop() {
        if let process, process.isRunning { process.terminate() }
        process = nil
        configuration = nil
        lastError = nil
    }

    deinit { stop() }
}
