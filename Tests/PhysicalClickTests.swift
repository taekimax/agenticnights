import Foundation
@main enum Tests {
    static func main() {
        precondition(isPhysicalClick(sourceStateID: 1))
        for source: Int64? in [nil, -1, 0, 2] { precondition(!isPhysicalClick(sourceStateID: source)) }
        print("PASS: hardware source accepted; session/private/missing/unknown sources ignored")
    }
}
