import Foundation

@main
enum KeyboardActivityTests {
    static func main() {
        var activity = KeyboardActivity()
        typealias Snapshot = KeyboardActivity.Snapshot
        precondition(!activity.consume(Snapshot(keys: 100, modifiers: 20)))
        precondition(!activity.consume(Snapshot(keys: 100, modifiers: 20)))
        precondition(activity.consume(Snapshot(keys: 101, modifiers: 20)), "A key between polls must restore the screen")
        precondition(!activity.consume(Snapshot(keys: 101, modifiers: 20)), "Do not reuse an earlier key")
        precondition(activity.consume(Snapshot(keys: 101, modifiers: 21)), "Modifier-only input must restore the screen")
        activity.reset(to: Snapshot(keys: 200, modifiers: 30))
        precondition(!activity.consume(Snapshot(keys: 200, modifiers: 30)), "Input during suspension must not dismiss a resumed cover")
        activity.reset(to: Snapshot(keys: UInt32.max, modifiers: 30))
        precondition(activity.consume(Snapshot(keys: 0, modifiers: 30)), "Handle counter wraparound")
        print("PASS: keyboard activity, modifier-only input, stale input, resume baseline and counter wraparound")
    }
}
