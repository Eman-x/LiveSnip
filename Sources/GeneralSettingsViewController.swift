import AppKit
import Carbon.HIToolbox

/// The General tab: the Capture Text shortcut, opening at login, line breaks, updates, and quitting.
@MainActor
final class GeneralSettingsViewController: NSViewController {
    private let recorder = NSButton()
    private let message = NSTextField(wrappingLabelWithString: "")
    private let openAtLogin = NSButton(checkboxWithTitle: "Open LiveSnip at login", target: nil, action: nil)
    private let keepLineBreaks = NSButton(checkboxWithTitle: "Keep line breaks when copying", target: nil, action: nil)
    private let checkForUpdates = NSButton(checkboxWithTitle: "Check for updates automatically", target: nil, action: nil)
    private let quitBehavior = NSPopUpButton()
    private var shortcut: Shortcut
    private var monitor: Any?
    /// Called before recording, so pressing the current shortcut doesn't start a capture.
    private let beginRecording: () -> Void
    /// Called with the new shortcut, or nil when recording is cancelled.
    /// Returns false if the shortcut couldn't be registered.
    private let finishRecording: (Shortcut?) -> Bool

    init(shortcut: Shortcut, beginRecording: @escaping () -> Void, finishRecording: @escaping (Shortcut?) -> Bool) {
        self.shortcut = shortcut
        self.beginRecording = beginRecording
        self.finishRecording = finishRecording
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        let heading = NSTextField(labelWithString: "Capture Text shortcut")
        heading.font = .systemFont(ofSize: 13, weight: .semibold)

        recorder.bezelStyle = .push
        recorder.controlSize = .large
        recorder.font = .systemFont(ofSize: 15, weight: .medium)
        recorder.target = self
        recorder.action = #selector(startRecording)
        recorder.widthAnchor.constraint(equalToConstant: 180).isActive = true
        let standard = NSButton(title: "Use \(Shortcut.standard.displayName)", target: self, action: #selector(useStandard))
        let shortcutRow = NSStackView(views: [recorder, standard])
        shortcutRow.spacing = 10

        message.font = .systemFont(ofSize: 11)

        let separator = NSBox()
        separator.boxType = .separator
        openAtLogin.target = self
        openAtLogin.action = #selector(toggleOpenAtLogin)
        keepLineBreaks.target = self
        keepLineBreaks.action = #selector(toggleLineBreaks)
        checkForUpdates.target = self
        checkForUpdates.action = #selector(toggleUpdateChecks)

        let quitLabel = NSTextField(labelWithString: "Quitting from the Dock:")
        quitBehavior.addItems(withTitles: AppDelegate.QuitBehavior.allCases.map(\.title))
        quitBehavior.target = self
        quitBehavior.action = #selector(chooseQuitBehavior)
        let quitRow = NSStackView(views: [quitLabel, quitBehavior])
        quitRow.spacing = 8

        let stack = NSStackView(views: [heading, shortcutRow, message, separator, openAtLogin, keepLineBreaks,
                                        checkForUpdates, quitRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.setCustomSpacing(16, after: message)
        stack.setCustomSpacing(16, after: separator)
        stack.setCustomSpacing(14, after: checkForUpdates)
        stack.edgeInsets = NSEdgeInsets(top: 22, left: 24, bottom: 24, right: 24)
        NSLayoutConstraint.activate([
            stack.widthAnchor.constraint(equalToConstant: 420),
            message.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -48),
            separator.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -48),
        ])
        message.preferredMaxLayoutWidth = 420 - 48
        view = stack
        refresh()
        preferredContentSize = stack.fittingSize
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        cancelRecording()
    }

    /// Shows the current settings. Login items can also change in System Settings, so this rereads them.
    func refresh() {
        openAtLogin.state = LoginItem.isEnabled ? .on : .off
        keepLineBreaks.state = UserDefaults.standard.bool(forKey: AppDelegate.keepLineBreaksKey) ? .on : .off
        checkForUpdates.state = UserDefaults.standard.bool(forKey: Updater.automaticChecksKey) ? .on : .off
        quitBehavior.selectItem(at: AppDelegate.QuitBehavior.allCases.firstIndex(of: AppDelegate.quitBehavior) ?? 0)
        guard monitor == nil else { return }
        recorder.title = shortcut.displayName
        setMessage("Click the shortcut to change it.")
    }

    @objc func startRecording() {
        guard monitor == nil else { return }
        beginRecording()
        recorder.title = "Type Shortcut…"
        setMessage("Press Esc to cancel.")
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            self?.handle(event)
            return nil
        }
    }

    func cancelRecording() {
        if monitor != nil { stopRecording(with: nil) }
    }

    private func handle(_ event: NSEvent) {
        if event.type == .flagsChanged {
            let held = Shortcut.symbols(for: event.modifierFlags)
            recorder.title = held.isEmpty ? "Type Shortcut…" : held
        } else if event.keyCode == UInt16(kVK_Escape) {
            stopRecording(with: nil)
        } else if let newShortcut = Shortcut(event: event) {
            stopRecording(with: newShortcut)
        } else {
            setMessage("Include ⌘, ⌥, or ⌃ so the shortcut doesn't get in the way of typing.", isError: true)
        }
    }

    @objc private func useStandard() {
        stopRecording(with: .standard)
    }

    private func stopRecording(with newShortcut: Shortcut?) {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil

        if finishRecording(newShortcut), let newShortcut {
            shortcut = newShortcut
            setMessage("Saved. Press \(newShortcut.displayName) to capture text.")
        } else if let newShortcut {
            setMessage("Another app is already using \(newShortcut.displayName).", isError: true)
        } else {
            setMessage("Click the shortcut to change it.")
        }
        recorder.title = shortcut.displayName
    }

    @objc private func toggleOpenAtLogin() {
        do {
            try LoginItem.setEnabled(openAtLogin.state == .on)
        } catch {
            setMessage(error.localizedDescription, isError: true)
        }
        openAtLogin.state = LoginItem.isEnabled ? .on : .off
    }

    @objc private func toggleLineBreaks() {
        UserDefaults.standard.set(keepLineBreaks.state == .on, forKey: AppDelegate.keepLineBreaksKey)
    }

    @objc private func toggleUpdateChecks() {
        UserDefaults.standard.set(checkForUpdates.state == .on, forKey: Updater.automaticChecksKey)
    }

    @objc private func chooseQuitBehavior() {
        AppDelegate.quitBehavior = AppDelegate.QuitBehavior.allCases[quitBehavior.indexOfSelectedItem]
    }

    private func setMessage(_ text: String, isError: Bool = false) {
        message.stringValue = text
        message.textColor = isError ? .systemRed : .secondaryLabelColor
    }
}
