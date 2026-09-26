import AppKit
import ServiceManagement

/// Opening LiveSnip at login, as one of the system's login items.
enum LoginItem {
    enum Problem: LocalizedError {
        case notInApplications, needsApproval

        var errorDescription: String? {
            switch self {
            case .notInApplications: "Move LiveSnip to your Applications folder first, then try again."
            case .needsApproval: "Turn on LiveSnip in System Settings → General → Login Items."
            }
        }
    }

    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    /// True when the system opened LiveSnip at login, rather than someone opening it.
    static var launchedAtLogin: Bool {
        let event = NSAppleEventManager.shared().currentAppleEvent
        return event?.eventID == kAEOpenApplication
            && event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }

    static func setEnabled(_ enabled: Bool) throws {
        guard enabled else {
            try SMAppService.mainApp.unregister()
            return
        }
        // An app opened straight from Downloads runs from a temporary copy that disappears,
        // so a login item pointing at it would fail after a restart.
        guard !Bundle.main.bundlePath.contains("/AppTranslocation/") else { throw Problem.notInApplications }

        try SMAppService.mainApp.register()
        if SMAppService.mainApp.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
            throw Problem.needsApproval
        }
    }
}
