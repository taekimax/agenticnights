import Foundation
import ServiceManagement

/// Registers the app bundle itself as a login item. macOS owns the state; the app
/// stores no copy of it, so changes made in System Settings are always reflected.
enum LaunchAtLogin {
    enum State: String {
        case enabled, disabled, requiresApproval, unavailable
    }

    static var state: State {
        switch SMAppService.mainApp.status {
        case .enabled: return .enabled
        case .requiresApproval: return .requiresApproval
        // macOS reports .notFound for an app that has never been registered;
        // register() surfaces any real failure as an error.
        case .notRegistered, .notFound: return .disabled
        @unknown default: return .unavailable
        }
    }

    /// Returns a user-facing error, or nil when macOS accepted the request.
    /// Registration can still need approval in System Settings; read `state` afterward.
    static func set(_ enabled: Bool) -> String? {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            return nil
        } catch {
            // Unregistering an item macOS no longer has already reached the goal.
            if !enabled, state == .disabled { return nil }
            return error.localizedDescription
        }
    }

    static func openSystemSettings() { SMAppService.openSystemSettingsLoginItems() }
}
