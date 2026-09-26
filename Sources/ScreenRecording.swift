import AppKit

/// The one permission LiveSnip needs: screen recording, so a capture includes other apps' windows.
enum ScreenRecording {
    static var isAllowed: Bool { CGPreflightScreenCaptureAccess() }

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

    /// A newly allowed permission applies after LiveSnip restarts, so this quits and reopens it.
    static func relaunch() {
        let reopen = Process()
        reopen.executableURL = URL(fileURLWithPath: "/bin/sh")
        // Wait for this process to exit, then open the app again.
        reopen.arguments = ["-c", "while /bin/kill -0 \"$1\" 2>/dev/null; do /bin/sleep 0.1; done; /usr/bin/open \"$0\"",
                            Bundle.main.bundlePath, String(ProcessInfo.processInfo.processIdentifier)]
        try? reopen.run()
        NSApp.terminate(nil)
    }
}
