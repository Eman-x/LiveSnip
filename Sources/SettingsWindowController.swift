import AppKit

/// LiveSnip's settings window, with General, Permissions, and About tabs in its toolbar.
@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    enum Tab: Int {
        case general, permissions, about
    }

    private let tabs = SizingTabViewController()
    private let general: GeneralSettingsViewController
    private let permissions = PermissionsViewController()

    init(shortcut: Shortcut, beginRecording: @escaping () -> Void, finishRecording: @escaping (Shortcut?) -> Bool) {
        general = GeneralSettingsViewController(shortcut: shortcut, beginRecording: beginRecording,
                                                finishRecording: finishRecording)
        tabs.tabStyle = .toolbar
        let pages: [(NSViewController, String, String)] = [
            (general, "General", "gearshape"),
            (permissions, "Permissions", "lock.shield"),
            (AboutViewController(), "About", "info.circle"),
        ]
        for (controller, label, symbol) in pages {
            // Load each tab now so its preferredContentSize is ready to size the window.
            _ = controller.view
            controller.title = label
            let item = NSTabViewItem(viewController: controller)
            item.label = label
            item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
            tabs.addTabViewItem(item)
        }

        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable]
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Shows the window on `tab`, recording a new shortcut right away if `recording` is true.
    func show(_ tab: Tab, recording: Bool = false) {
        tabs.selectedTabViewItemIndex = tab.rawValue
        general.refresh()
        permissions.refresh()
        if window?.isVisible == false { window?.center() }
        NSApp.activate()
        showWindow(nil)
        if recording { general.startRecording() }
    }

    func windowWillClose(_ notification: Notification) {
        general.cancelRecording()
    }
}

/// Fits the window to the selected tab. A plain tab view controller keeps the first tab's size.
private final class SizingTabViewController: NSTabViewController {
    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, didSelect: tabViewItem)
        fitWindow()
    }

    override func preferredContentSizeDidChange(for viewController: NSViewController) {
        super.preferredContentSizeDidChange(for: viewController)
        if viewController === tabViewItems[selectedTabViewItemIndex].viewController { fitWindow() }
    }

    private func fitWindow() {
        guard let window = view.window,
              let size = tabViewItems[selectedTabViewItemIndex].viewController?.preferredContentSize,
              size != .zero else { return }
        // Keep the top edge where it is, so the toolbar doesn't jump.
        var frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: size))
        frame.origin = NSPoint(x: window.frame.minX, y: window.frame.maxY - frame.height)
        window.setFrame(frame, display: true, animate: window.isVisible)
    }
}
