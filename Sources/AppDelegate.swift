import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    static let keepLineBreaksKey = "keepLineBreaks"

    /// What quitting from the Dock or with ⌘Q does.
    enum QuitBehavior: String, CaseIterable {
        case ask, menuBar, quit

        var title: String {
            switch self {
            case .ask: "Ask each time"
            case .menuBar: "Keep in the menu bar"
            case .quit: "Quit completely"
            }
        }
    }

    static var quitBehavior: QuitBehavior {
        get { QuitBehavior(rawValue: UserDefaults.standard.string(forKey: "quitBehavior") ?? "") ?? .ask }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "quitBehavior") }
    }

    /// Set to quit without the menu bar question: for Quit in the menu bar menu, updates, and restarts.
    static var quitsWithoutAsking = false

    private let hud = HUD()
    private lazy var updater = Updater(hud: hud)
    private var statusItem: NSStatusItem!
    private let permissionItem = NSMenuItem(title: "Allow Screen Recording…", action: #selector(AppDelegate.showPermissions), keyEquivalent: "")
    private let captureItem = NSMenuItem(title: "Capture Text", action: #selector(AppDelegate.captureText), keyEquivalent: "")
    private let lineBreaksItem = NSMenuItem(title: "Keep Line Breaks", action: #selector(AppDelegate.toggleLineBreaks(_:)), keyEquivalent: "")
    private let openAtLoginItem = NSMenuItem(title: "Open at Login", action: #selector(AppDelegate.toggleOpenAtLogin(_:)), keyEquivalent: "")
    private var shortcut = Shortcut.saved
    private var hotKey: HotKey?
    private var isCapturing = false

    private lazy var settingsWindow = SettingsWindowController(
        shortcut: shortcut,
        beginRecording: { [weak self] in self?.hotKey = nil },
        finishRecording: { [weak self] in self?.finishRecording($0) ?? false })

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [Self.keepLineBreaksKey: true, Updater.automaticChecksKey: true])

        // Opened by someone, LiveSnip shows in the Dock. Opened at login, it stays in the menu bar.
        if LoginItem.launchedAtLogin { NSApp.setActivationPolicy(.accessory) }
        NSApp.mainMenu = makeMainMenu()
        updater.startAutomaticChecks()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "text.viewfinder", accessibilityDescription: "LiveSnip")
        statusItem.menu = makeMenu()

        let hotKeyRegistered = registerHotKey()
        // Missing screen recording opens the Permissions tab to allow it. On the launch after it's
        // allowed (usually from Quit & Reopen), the tab opens once more to show the green check.
        let showPermissions = !ScreenRecording.isAllowed || ScreenRecording.awaitingConfirmation
        if showPermissions {
            if ScreenRecording.isAllowed { ScreenRecording.awaitingConfirmation = false }
            settingsWindow.show(.permissions)
        }

        if !hotKeyRegistered {
            hud.show(symbol: "exclamationmark.triangle", title: "\(shortcut.displayName) is already in use",
                     detail: "Open LiveSnip again to pick another shortcut")
        } else if !showPermissions && !LoginItem.launchedAtLogin {
            hud.show(symbol: "text.viewfinder", title: "LiveSnip is running",
                     detail: "Press \(shortcut.displayName) to capture text")
        }
    }

    /// Opening LiveSnip while it's running shows its settings, which helps when the
    /// menu bar is too full to show the icon.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NSApp.setActivationPolicy(.regular)
        settingsWindow.show(ScreenRecording.isAllowed ? .general : .permissions)
        return false
    }

    /// Quitting from the Dock or with ⌘Q can keep LiveSnip running in the menu bar instead.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !Self.quitsWithoutAsking, NSApp.activationPolicy() == .regular, !Self.isSystemQuit else { return .terminateNow }

        var keepInMenuBar = Self.quitBehavior == .menuBar
        if Self.quitBehavior == .ask {
            let alert = NSAlert()
            alert.messageText = "Keep LiveSnip in the menu bar?"
            alert.informativeText = "It keeps running without a Dock icon, so \(shortcut.displayName) still works. "
                + "You can quit it from the menu bar icon at any time."
            alert.addButton(withTitle: "Keep in Menu Bar")
            alert.addButton(withTitle: "Quit")
            alert.showsSuppressionButton = true
            alert.suppressionButton?.title = "Remember my choice"
            keepInMenuBar = alert.runModal() == .alertFirstButtonReturn
            if alert.suppressionButton?.state == .on { Self.quitBehavior = keepInMenuBar ? .menuBar : .quit }
        }
        guard keepInMenuBar else { return .terminateNow }

        settingsWindow.close()
        NSApp.setActivationPolicy(.accessory)
        hud.show(symbol: "menubar.arrow.up.rectangle", title: "LiveSnip is still running",
                 detail: "Press \(shortcut.displayName) to capture text")
        return .terminateCancel
    }

    /// Logging out, restarting, and shutting down send a quit with a reason, and shouldn't be held up.
    private static var isSystemQuit: Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent, event.eventID == kAEQuitApplication else { return false }
        return event.paramDescriptor(forKeyword: kAEQuitReason) != nil
            || event.attributeDescriptor(forKeyword: kAEQuitReason) != nil
    }

    /// Quits and opens LiveSnip again, to apply an update or a newly allowed permission.
    static func relaunch() {
        quitsWithoutAsking = true
        let reopen = Process()
        reopen.executableURL = URL(fileURLWithPath: "/bin/sh")
        // Wait for this process to exit, then open the app again.
        reopen.arguments = ["-c", "while /bin/kill -0 \"$1\" 2>/dev/null; do /bin/sleep 0.1; done; /usr/bin/open \"$0\"",
                            Bundle.main.bundlePath, String(ProcessInfo.processInfo.processIdentifier)]
        try? reopen.run()
        NSApp.terminate(nil)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        // These can also change in System Settings or the settings window, so check each time the menu opens.
        permissionItem.isHidden = ScreenRecording.isAllowed
        lineBreaksItem.state = UserDefaults.standard.bool(forKey: Self.keepLineBreaksKey) ? .on : .off
        openAtLoginItem.state = LoginItem.isEnabled ? .on : .off
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()

        permissionItem.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: nil)
        for item in [permissionItem, captureItem] {
            item.target = self
            menu.addItem(item)
        }
        menu.addItem(.separator())

        let changeShortcut = NSMenuItem(title: "Change Shortcut…", action: #selector(changeShortcut), keyEquivalent: "")
        for item in [lineBreaksItem, openAtLoginItem, changeShortcut] {
            item.target = self
            menu.addItem(item)
        }
        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        let updates = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates(_:)), keyEquivalent: "")
        let about = NSMenuItem(title: "About LiveSnip", action: #selector(showAbout), keyEquivalent: "")
        let quit = NSMenuItem(title: "Quit LiveSnip", action: #selector(quitCompletely), keyEquivalent: "q")
        for item in [settings, updates, about, quit] {
            item.target = self
            menu.addItem(item)
        }
        menu.delegate = self
        return menu
    }

    /// The app menu and Window menu, shown while LiveSnip is in the Dock.
    private func makeMainMenu() -> NSMenu {
        let appMenu = NSMenu()
        for (title, action, key) in [("About LiveSnip", #selector(showAbout), ""),
                                     ("Check for Updates…", #selector(checkForUpdates(_:)), ""),
                                     ("Settings…", #selector(showSettings), ",")] {
            appMenu.addItem(withTitle: title, action: action, keyEquivalent: key).target = self
        }
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide LiveSnip", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit LiveSnip", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        NSApp.windowsMenu = windowMenu

        let main = NSMenu()
        for submenu in [appMenu, windowMenu] {
            let item = NSMenuItem()
            item.submenu = submenu
            main.addItem(item)
        }
        return main
    }

    @objc func checkForUpdates(_ sender: Any?) {
        updater.check(userInitiated: true)
    }

    /// Quit from the menu bar menu means quit, so it skips the menu bar question.
    @objc private func quitCompletely() {
        Self.quitsWithoutAsking = true
        NSApp.terminate(nil)
    }

    @objc private func showPermissions() {
        settingsWindow.show(.permissions)
    }

    @objc private func showSettings() {
        settingsWindow.show(.general)
    }

    @objc private func showAbout() {
        settingsWindow.show(.about)
    }

    @objc private func changeShortcut() {
        settingsWindow.show(.general, recording: true)
    }

    @objc private func toggleOpenAtLogin(_ item: NSMenuItem) {
        do {
            try LoginItem.setEnabled(item.state != .on)
        } catch {
            hud.show(symbol: "exclamationmark.triangle", title: "Couldn't change Open at Login",
                     detail: error.localizedDescription)
        }
    }

    /// Registers the current shortcut, replacing the previous registration.
    @discardableResult
    private func registerHotKey() -> Bool {
        hotKey = nil
        hotKey = HotKey(keyCode: Int(shortcut.keyCode), modifiers: shortcut.carbonModifiers) { [weak self] in
            self?.captureText()
        }
        captureItem.keyEquivalent = shortcut.keyEquivalent
        captureItem.keyEquivalentModifierMask = shortcut.modifiers
        return hotKey != nil
    }

    /// Switches to a newly recorded shortcut, keeping the current one if another app already uses it.
    /// With nil (recording was cancelled), it turns the current shortcut back on.
    private func finishRecording(_ newShortcut: Shortcut?) -> Bool {
        guard let newShortcut, newShortcut != shortcut else { return registerHotKey() }

        let previous = shortcut
        shortcut = newShortcut
        if registerHotKey() {
            shortcut.save()
            return true
        }
        shortcut = previous
        registerHotKey()
        return false
    }

    @objc private func toggleLineBreaks(_ item: NSMenuItem) {
        let keep = item.state != .on
        UserDefaults.standard.set(keep, forKey: Self.keepLineBreaksKey)
        item.state = keep ? .on : .off
    }

    @objc private func captureText() {
        guard !isCapturing else { return }
        // Without screen recording, a capture would only show the wallpaper, so explain what's missing instead.
        guard ScreenRecording.isAllowed else {
            settingsWindow.show(.permissions)
            return
        }
        isCapturing = true

        let imageURL = FileManager.default.temporaryDirectory.appendingPathComponent("LiveSnip-\(UUID().uuidString).png")
        let screencapture = Process()
        screencapture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        // -i: drag to select (Space switches to window mode, Esc cancels), -x: no sound, -o: no window shadow.
        screencapture.arguments = ["-i", "-x", "-o", imageURL.path]
        screencapture.terminationHandler = { _ in
            Task { @MainActor in await self.copyText(from: imageURL) }
        }
        do {
            try screencapture.run()
        } catch {
            isCapturing = false
            hud.show(symbol: "exclamationmark.triangle", title: "Couldn't start the screen capture",
                     detail: error.localizedDescription)
        }
    }

    private func copyText(from imageURL: URL) async {
        defer {
            isCapturing = false
            try? FileManager.default.removeItem(at: imageURL)
        }
        // No image means the selection was cancelled.
        guard FileManager.default.fileExists(atPath: imageURL.path) else { return }

        do {
            let transcript = try await LiveText.recognize(imageAt: imageURL)
            let singleLine = transcript.split(whereSeparator: \.isNewline).joined(separator: " ")
                .trimmingCharacters(in: .whitespaces)
            guard !singleLine.isEmpty else {
                hud.show(symbol: "text.magnifyingglass", title: "No text found")
                return
            }

            let keepLineBreaks = UserDefaults.standard.bool(forKey: Self.keepLineBreaksKey)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(keepLineBreaks ? transcript : singleLine, forType: .string)
            hud.show(symbol: "checkmark.circle", title: "Text copied", detail: singleLine)
        } catch {
            hud.show(symbol: "exclamationmark.triangle", title: "Couldn't read the text",
                     detail: error.localizedDescription)
        }
    }
}
