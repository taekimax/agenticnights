import Foundation

/// Carbon key codes and modifier bits, kept independent of AppKit for persistence.
struct KeyboardShortcut: Codable, Equatable, Sendable {
    var keyCode: UInt32
    var modifiers: UInt32

    static let command: UInt32 = 1 << 8
    static let shift: UInt32 = 1 << 9
    static let option: UInt32 = 1 << 11
    static let control: UInt32 = 1 << 12
    static let defaults = KeyboardShortcut(keyCode: 11, modifiers: command | option | control)
    static let keyLabels: [UInt32: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 25: "9", 26: "7", 28: "8", 29: "0",
        31: "O", 32: "U", 34: "I", 35: "P", 37: "L", 38: "J", 40: "K", 45: "N", 46: "M",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8",
        101: "F9", 109: "F10", 103: "F11", 111: "F12", 105: "F13", 107: "F14", 113: "F15",
        106: "F16", 64: "F17", 79: "F18", 80: "F19", 90: "F20"
    ]

    var isValid: Bool {
        let primary = Self.command | Self.option | Self.control
        return Self.keyLabels[keyCode] != nil && modifiers & primary != 0 &&
            modifiers & ~(primary | Self.shift) == 0
    }

    var displayName: String {
        var text = ""
        for (flag, symbol) in [(Self.control, "⌃"), (Self.option, "⌥"), (Self.shift, "⇧"), (Self.command, "⌘")] {
            if modifiers & flag != 0 { text += symbol }
        }
        return text + (Self.keyLabels[keyCode] ?? "?")
    }
}
