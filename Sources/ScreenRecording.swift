import AppKit

/// The one permission LiveSnip needs: screen recording, so a capture includes other apps' windows.
@MainActor
enum ScreenRecording {
    /// Set once a fresh check sees the permission that this process hasn't picked up yet.
    private static var allowedInFreshCheck = false

    static var isAllowed: Bool { allowedInFreshCheck || CGPreflightScreenCaptureAccess() }

    /// Asks a new LiveSnip process, since this one can keep an old answer until it restarts.
    /// Captures run in their own process too, so they work as soon as this says yes.
    static func recheck() -> Bool {
        if let executable = Bundle.main.executableURL {
            let check = Process()
            check.executableURL = executable
            check.arguments = [freshCheckArgument]
            if (try? check.run()) != nil {
                check.waitUntilExit()
                if check.terminationStatus == 0 { allowedInFreshCheck = true }
            }
        }
        return isAllowed
    }

    /// Launching LiveSnip with this argument exits with status 0 when screen recording is allowed.
    static let freshCheckArgument = "--check-screen-recording"

    /// Set while the permission is missing, so the launch after it's allowed can show that it worked.
    static var awaitingConfirmation: Bool {
        get { UserDefaults.standard.bool(forKey: "awaitingScreenRecordingConfirmation") }
        set { UserDefaults.standard.set(newValue, forKey: "awaitingScreenRecordingConfirmation") }
    }

    /// Lists LiveSnip under Screen & System Audio Recording (macOS asks once, the first time)
    /// and opens that page of System Settings.
    static func openSettings() {
        CGRequestScreenCaptureAccess()
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
    }
}
