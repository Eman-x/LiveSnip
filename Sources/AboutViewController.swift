import AppKit

/// The About tab: what LiveSnip is, its version, and a way to send feedback.
@MainActor
final class AboutViewController: NSViewController {
    private static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""

    override func loadView() {
        let icon = NSImageView(image: NSApp.applicationIconImage)
        icon.imageScaling = .scaleProportionallyUpOrDown
        let name = NSTextField(labelWithString: "LiveSnip")
        name.font = .systemFont(ofSize: 22, weight: .bold)
        let version = NSTextField(labelWithString: "Version \(Self.version)")
        version.textColor = .secondaryLabelColor
        let summary = NSTextField(wrappingLabelWithString: "Copy text from anywhere on your screen with Apple's Live Text.")
        summary.alignment = .center
        summary.textColor = .secondaryLabelColor
        summary.preferredMaxLayoutWidth = 300

        let feedback = NSButton(title: "Send Feedback…", target: self, action: #selector(sendFeedback))
        feedback.controlSize = .large
        feedback.keyEquivalent = "\r"
        // No target: the app delegate handles it, the same as the menu item.
        let update = NSButton(title: "Check for Updates…", target: nil, action: #selector(AppDelegate.checkForUpdates(_:)))
        update.controlSize = .large
        let buttons = NSStackView(views: [feedback, update])
        buttons.spacing = 10
        let links = NSStackView(views: [link("Website", #selector(openWebsite)), link("Source on GitHub", #selector(openGitHub))])
        links.spacing = 18
        let credit = NSTextField(labelWithString: "© 2026 Eman Alamari · MIT License")
        credit.font = .systemFont(ofSize: 11)
        credit.textColor = .tertiaryLabelColor

        let stack = NSStackView(views: [icon, name, version, summary, buttons, links, credit])
        stack.orientation = .vertical
        stack.spacing = 6
        stack.setCustomSpacing(10, after: icon)
        stack.setCustomSpacing(12, after: version)
        stack.setCustomSpacing(20, after: summary)
        stack.setCustomSpacing(14, after: buttons)
        stack.setCustomSpacing(18, after: links)
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 22, right: 24)
        NSLayoutConstraint.activate([
            stack.widthAnchor.constraint(equalToConstant: 420),
            icon.widthAnchor.constraint(equalToConstant: 96),
            icon.heightAnchor.constraint(equalToConstant: 96),
        ])
        view = stack
        preferredContentSize = stack.fittingSize
    }

    private func link(_ title: String, _ action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.isBordered = false
        button.contentTintColor = .linkColor
        return button
    }

    /// Opens an email to me@eman.sa with the versions filled in, which helps with bug reports.
    @objc private func sendFeedback() {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        var mail = URLComponents()
        mail.scheme = "mailto"
        mail.path = "me@eman.sa"
        mail.queryItems = [
            URLQueryItem(name: "subject", value: "LiveSnip feedback"),
            URLQueryItem(name: "body", value: "\n\n—\nLiveSnip \(Self.version) · macOS \(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"),
        ]
        if let url = mail.url { NSWorkspace.shared.open(url) }
    }

    @objc private func openWebsite() {
        NSWorkspace.shared.open(URL(string: "https://eman.sa/livesnip/")!)
    }

    @objc private func openGitHub() {
        NSWorkspace.shared.open(URL(string: "https://github.com/Eman-x/LiveSnip")!)
    }
}
