// The process-lifetime caffeinate approach is adapted from KeepingYouAwake.
// Copyright (c) 2014 - present Marcel Dierkes. MIT; see THIRD_PARTY_NOTICES.md.
import Foundation

final class SleepPrevention {
    private var process: Process?
    private(set) var lastError: String?

    var isRunning: Bool { process?.isRunning == true }
    var processIdentifier: Int32? { isRunning ? process?.processIdentifier : nil }

    func start() {
        guard !isRunning else { return }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        task.arguments = ["-di", "-w", String(ProcessInfo.processInfo.processIdentifier)]
        do {
            try task.run()
            process = task
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func stop() {
        if let process, process.isRunning { process.terminate() }
        process = nil
        lastError = nil
    }

    deinit { stop() }
}
