// Bounded, disposable input/capture experiment. Never stores arbitrary key contents.
// Compare Curtain's session tap and RustDesk's HID tap without installing either app.
import AppKit
import ApplicationServices
import ScreenCaptureKit
import ImageIO
import UniformTypeIdentifiers

let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "/tmp/agenticnights-privacy-probe")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let logLock = NSLock()
func record(_ value: [String: Any]) {
    var row = value
    row["time"] = ISO8601DateFormatter().string(from: Date())
    guard let data = try? JSONSerialization.data(withJSONObject: row, options: [.sortedKeys]) else { return }
    logLock.lock(); defer { logLock.unlock() }
    let url = output.appendingPathComponent("events.jsonl")
    if !FileManager.default.fileExists(atPath: url.path) { FileManager.default.createFile(atPath: url.path, contents: nil) }
    if let f = try? FileHandle(forWritingTo: url) { _ = try? f.seekToEnd(); try? f.write(contentsOf: data + Data([10])); try? f.close() }
}

struct Ramp {
    let id: CGDirectDisplayID
    let red: [CGGammaValue]
    let green: [CGGammaValue]
    let blue: [CGGammaValue]
    static func read(_ id: CGDirectDisplayID) -> Ramp? {
        let capacity = Int(CGDisplayGammaTableCapacity(id))
        guard capacity > 0, capacity <= 65536 else { return nil }
        var r = [CGGammaValue](repeating: 0, count: capacity), g = r, b = r
        var count: UInt32 = 0
        guard CGGetDisplayTransferByTable(id, UInt32(capacity), &r, &g, &b, &count) == .success, count > 0 else { return nil }
        return Ramp(id: id, red: Array(r.prefix(Int(count))), green: Array(g.prefix(Int(count))), blue: Array(b.prefix(Int(count))))
    }
    func write() -> CGError { CGSetDisplayTransferByTable(id, UInt32(red.count), red, green, blue) }
    func black() -> CGError {
        let zeros = [CGGammaValue](repeating: 0, count: red.count)
        return CGSetDisplayTransferByTable(id, UInt32(zeros.count), zeros, zeros, zeros)
    }
    func difference(_ other: Ramp) -> Float {
        guard red.count == other.red.count else { return .infinity }
        return zip(red + green + blue, other.red + other.green + other.blue).map { abs($0 - $1) }.max() ?? 0
    }
}

final class Tap {
    private let lock = NSLock()
    private var port: CFMachPort?
    private var source: CFRunLoopSource?
    var blocking = false
    var seen = 0
    var blocked = 0
    var counts: [String: Int] = [:]
    func install(hid: Bool, block: Bool) -> Bool {
        stop()
        blocking = block
        let callback: CGEventTapCallBack = { _, type, event, context in
            let owner = Unmanaged<Tap>.fromOpaque(context!).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let p = owner.port { CGEvent.tapEnable(tap: p, enable: true) }
                record(["kind": "tapDisabled", "type": type.rawValue])
                return Unmanaged.passUnretained(event)
            }
            let state = event.getIntegerValueField(.eventSourceStateID)
            let pid = event.getIntegerValueField(.eventSourceUnixProcessID)
            let tag = event.getIntegerValueField(.eventSourceUserData)
            let drop = owner.blocking && state == 1
            owner.lock.lock()
            owner.seen += 1
            if drop { owner.blocked += 1 }
            let key = "type=\(type.rawValue),state=\(state),pid=\(pid),tag=\(tag),drop=\(drop)"
            owner.counts[key, default: 0] += 1
            owner.lock.unlock()
            return drop ? nil : Unmanaged.passUnretained(event)
        }
        // All event types: include modifier/system-defined/gesture types offered by CGEventTap.
        // Whether macOS system gestures traverse this tap is an empirical question.
        guard let p = CGEvent.tapCreate(tap: hid ? .cghidEventTap : .cgSessionEventTap,
            place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: ~CGEventMask(0),
            callback: callback, userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return false }
        port = p
        source = CFMachPortCreateRunLoopSource(nil, p, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: p, enable: true)
        return CGEvent.tapIsEnabled(tap: p)
    }
    func snapshot() -> [String: Any] {
        lock.lock(); defer { lock.unlock() }
        return ["seen": seen, "blocked": blocked, "events": counts]
    }
    func stop() {
        if let p = port { CGEvent.tapEnable(tap: p, enable: false); CFMachPortInvalidate(p) }
        if let s = source { CFRunLoopRemoveSource(CFRunLoopGetMain(), s, .commonModes) }
        source = nil; port = nil
    }
}

final class Chart: NSView {
    override func draw(_ rect: NSRect) {
        NSColor(srgbRed: 0.2, green: 0.2, blue: 0.2, alpha: 1).setFill(); bounds.fill()
        for i in 0..<24 {
            let column = i % 8, row = i / 8
            let colors: [NSColor] = [.red, .green, .blue, .cyan, .magenta, .yellow, .white, .black]
            let color = row == 0 ? colors[column] : NSColor(srgbRed: CGFloat(column) / 7, green: row == 1 ? CGFloat(column) / 7 : 0.3, blue: row == 1 ? CGFloat(column) / 7 : 0.7, alpha: 1)
            color.setFill()
            NSRect(x: 10 + column * 85, y: 10 + row * 90, width: 80, height: 85).fill()
        }
    }
}

final class TestWindow: NSWindow {
    var testKeyDowns = 0
    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown { testKeyDowns += 1 }
        super.sendEvent(event)
    }
}

final class Probe: NSObject, NSApplicationDelegate, NSTextFieldDelegate {
    var windows: [TestWindow] = []
    var fields: [NSTextField] = []
    var counters: [NSTextField] = []
    var clicks = 0
    var mode = "idle"
    var ramps: [Ramp] = []
    let tap = Tap()
    var timer: Timer?
    var deadline: Date?
    var generation = 0
    var capturing = false
    var lastCapture = ""
    var signalSource: DispatchSourceSignal?

    func applicationDidFinishLaunching(_ notification: Notification) {
        record(["kind": "preflight", "pid": getpid(), "accessibility": AXIsProcessTrusted(),
                "capture": CGPreflightScreenCaptureAccess(), "listen": CGPreflightListenEventAccess()])
        NSApp.setActivationPolicy(.regular)
        for (index, screen) in NSScreen.screens.enumerated() {
            let window = TestWindow(contentRect: NSRect(x: 0, y: 0, width: 720, height: 470),
                styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "Privacy Probe \(index + 1)"
            window.setFrameOrigin(NSPoint(x: screen.visibleFrame.midX - 360, y: screen.visibleFrame.midY - 235))
            window.isReleasedWhenClosed = false
            let content = window.contentView!
            let label = NSTextField(labelWithString: "Disposable input and color test — automatic restoration")
            label.frame = NSRect(x: 20, y: 430, width: 680, height: 24)
            content.addSubview(label)
            let field = NSTextField(frame: NSRect(x: 20, y: 385, width: 440, height: 30))
            field.placeholderString = "Agent test text"
            field.setAccessibilityIdentifier("probe-text-\(index + 1)")
            field.delegate = self
            content.addSubview(field); fields.append(field)
            let button = NSButton(title: "Increment", target: self, action: #selector(increment))
            button.bezelStyle = .rounded
            button.frame = NSRect(x: 480, y: 385, width: 120, height: 30)
            content.addSubview(button)
            let count = NSTextField(labelWithString: "Clicks: 0")
            count.frame = NSRect(x: 20, y: 345, width: 680, height: 24)
            content.addSubview(count); counters.append(count)
            let chart = Chart(frame: NSRect(x: 10, y: 20, width: 700, height: 290))
            content.addSubview(chart)
            window.makeKeyAndOrderFront(nil)
            windows.append(window)
        }
        NSApp.activate(ignoringOtherApps: true)
        windows.first?.makeKeyAndOrderFront(nil)
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in self?.tick() }
        signal(SIGTERM, SIG_IGN)
        signalSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        signalSource?.setEventHandler { [weak self] in self?.finish(); NSApp.terminate(nil) }
        signalSource?.resume()
        // Independent process bound, even if the AppKit run loop stalls.
        DispatchQueue.global().asyncAfter(deadline: .now() + 1200) { exit(0) }
        status()
    }
    @objc func increment() { clicks += 1; counters.forEach { $0.stringValue = "Clicks: \(clicks)" }; status() }
    func controlTextDidChange(_ notification: Notification) { status() }
    func applicationWillTerminate(_ notification: Notification) { finish() }
    func finish() {
        tap.stop()
        for ramp in ramps {
            let result = ramp.write()
            let diff = Ramp.read(ramp.id).map { ramp.difference($0) } ?? .infinity
            record(["kind": "restore", "display": ramp.id, "result": result.rawValue, "maximumRampError": diff.isFinite ? Double(diff) : -1])
        }
        ramps = []
        if mode != "idle" { record(["kind": "phaseEnd", "mode": mode, "tap": tap.snapshot()]) }
        mode = "idle"; deadline = nil; generation += 1
        status()
    }
    func tick() {
        if let deadline, Date() >= deadline { finish() }
        let command = output.appendingPathComponent("command.json")
        guard let data = try? Data(contentsOf: command),
              let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        try? FileManager.default.removeItem(at: command)
        if let sourceState = value["injectTestSourceState"] as? Int32 {
            // Deliberately simulated input, only into this disposable app. This verifies
            // event propagation/classification, never claims to be a physical device test.
            guard let id = CGEventSourceStateID(rawValue: sourceState), let src = CGEventSource(stateID: id),
                  let window = windows.first, let field = fields.first else { return }
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil); window.makeFirstResponder(field)
            src.userData = 731031
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                guard NSWorkspace.shared.frontmostApplication?.processIdentifier == getpid() else {
                    record(["kind": "injectionSkipped", "reason": "probe is not foreground"]); return
                }
                for down in [true, false] {
                    let event = CGEvent(keyboardEventSource: src, virtualKey: 40, keyDown: down)!
                    event.post(tap: .cghidEventTap)
                }
                record(["kind": "simulatedInjection", "sourceState": sourceState, "tag": 731031])
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { self.status() }
            }
            return
        }
        if let capture = value["capture"] as? String {
            guard !capturing, capture.range(of: "^[a-zA-Z0-9_-]+$", options: .regularExpression) != nil else { return }
            capturing = true
            Task { await self.capture(capture); self.capturing = false; self.lastCapture = capture; self.status() }
            return
        }
        guard let next = value["mode"] as? String else { return }
        finish()
        if next == "quit" { NSApp.terminate(nil); return }
        guard ["observe", "session", "hid", "gamma", "combined-session", "combined-hid"].contains(next) else { return }
        let duration = min(60, max(5, value["seconds"] as? Int ?? 30))
        if next != "gamma" {
            guard tap.install(hid: next.contains("hid"), block: next != "observe") else {
                record(["kind": "phaseFailed", "mode": next, "reason": "event tap unavailable"]); return
            }
        }
        if next == "gamma" || next.hasPrefix("combined") {
            for screen in NSScreen.screens {
                guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32,
                      let ramp = Ramp.read(id) else { finish(); record(["kind": "phaseFailed", "reason": "cannot save gamma"]); return }
                ramps.append(ramp)
            }
            for ramp in ramps {
                let result = ramp.black()
                record(["kind": "blackout", "display": ramp.id, "samples": ramp.red.count, "result": result.rawValue,
                        "readbackMaximum": Ramp.read(ramp.id).map { ($0.red + $0.green + $0.blue).max() ?? -1 } ?? -1])
                if result != .success { finish(); return }
            }
        }
        mode = next; deadline = Date().addingTimeInterval(Double(duration))
        let token = generation
        DispatchQueue.global().asyncAfter(deadline: .now() + Double(duration + 5)) { [weak self] in
            // Last resort for a stalled main loop. Process exit removes its event tap/gamma ownership.
            if self?.generation == token { exit(0) }
        }
        record(["kind": "phaseStart", "mode": mode, "seconds": duration]); status()
    }
    func status() {
        let value: [String: Any] = ["pid": getpid(), "mode": mode, "clicks": clicks,
            "testText": fields.map(\.stringValue), "testKeyDowns": windows.map(\.testKeyDowns), "lastCapture": lastCapture,
            "tap": tap.snapshot(), "windows": windows.map { ["id": $0.windowNumber, "title": $0.title, "frame": NSStringFromRect($0.frame)] }]
        if let d = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]) {
            try? d.write(to: output.appendingPathComponent("status.json"), options: .atomic)
        }
    }
    func save(_ image: CGImage, _ name: String) {
        let url = output.appendingPathComponent(name + ".png")
        if let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) {
            CGImageDestinationAddImage(dest, image, nil); CGImageDestinationFinalize(dest)
            record(["kind": "capture", "file": url.lastPathComponent, "width": image.width, "height": image.height,
                    "bitsPerComponent": image.bitsPerComponent, "colorSpace": image.colorSpace?.name as String? ?? "unknown"])
        }
    }
    @MainActor func capture(_ name: String) async {
        do {
            // CUA may operate a window in a background surface. Bring test charts onto
            // the physical displays for the DISPLAY-capture measurement, separately
            // from the independent-window capture measurement.
            for window in windows { window.level = .floating; window.orderFrontRegardless() }
            try await Task.sleep(nanoseconds: 200_000_000)
            defer { windows.forEach { $0.level = .normal } }
            let share = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            for window in windows {
                guard let w = share.windows.first(where: { $0.windowID == UInt32(window.windowNumber) }) else { continue }
                let config = SCStreamConfiguration()
                config.width = Int(w.frame.width) * 2; config.height = Int(w.frame.height) * 2
                config.showsCursor = false
                let image = try await SCScreenshotManager.captureImage(contentFilter: SCContentFilter(desktopIndependentWindow: w), configuration: config)
                // Fixed chart-only crop excludes cursor, caret and changing counters.
                if let chart = image.cropping(to: CGRect(x: 40, y: image.height - 580, width: 1360, height: 520)) {
                    save(chart, "\(name)-window-\(window.windowNumber)")
                }
                guard let display = share.displays.first(where: { $0.frame.contains(CGPoint(x: w.frame.midX, y: w.frame.midY)) }) else { continue }
                let dc = SCStreamConfiguration()
                dc.width = display.width; dc.height = display.height; dc.showsCursor = false
                let full = try await SCScreenshotManager.captureImage(contentFilter: SCContentFilter(display: display, excludingWindows: []), configuration: dc)
                let sx = CGFloat(full.width) / display.frame.width, sy = CGFloat(full.height) / display.frame.height
                let crop = CGRect(x: (w.frame.minX - display.frame.minX + 20) * sx,
                                  y: (w.frame.maxY - display.frame.minY - 290) * sy, width: 680 * sx, height: 260 * sy)
                if let chart = full.cropping(to: crop) { save(chart, "\(name)-display-\(display.displayID)") }
            }
        } catch { record(["kind": "captureError", "error": String(describing: error)]) }
    }
}

let app = NSApplication.shared
let delegate = Probe()
app.delegate = delegate
app.run()
