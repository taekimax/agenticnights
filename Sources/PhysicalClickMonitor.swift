import AppKit

/// AppKit preserves hardware source 1 in received mouse-event copies. Normal
/// session/private-source automation is ignored; see the recorded live probe.
func isPhysicalClick(sourceStateID: Int64?) -> Bool { sourceStateID == 1 }

final class PhysicalClickMonitor {
    var onClick: ((NSEvent) -> Void)?
    private var globalMonitor: Any?
    private var localMonitor: Any?

    func start() throws {
        stop()
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            self?.receive(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.receive(event)
            return event
        }
        guard globalMonitor != nil, localMonitor != nil else {
            stop()
            throw DisplayBlackout.Failure(message: "Could not monitor mouse clicks.")
        }
    }

    private func receive(_ event: NSEvent) {
        guard isPhysicalClick(sourceStateID: event.cgEvent?.getIntegerValueField(.eventSourceStateID)) else { return }
        onClick?(event)
    }

    func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
    }

    deinit { stop() }
}
