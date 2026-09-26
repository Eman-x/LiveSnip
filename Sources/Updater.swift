import AppKit
import Security

/// Checks GitHub for a newer LiveSnip and installs it, but only when the download is signed with
/// the same certificate as the running app, so a tampered download can't install itself.
@MainActor
final class Updater {
    struct Release {
        let version: String
        let notes: String
        let download: URL
    }

    enum Problem: LocalizedError {
        case noDownload, notSignedLikeThisApp, notInApplications

        var errorDescription: String? {
            switch self {
            case .noDownload: "The latest release doesn't include LiveSnip.zip."
            case .notSignedLikeThisApp: "The download isn't signed with LiveSnip's certificate, so it wasn't installed."
            case .notInApplications: "Move LiveSnip to your Applications folder first, then try again."
            }
        }
    }

    static let automaticChecksKey = "checkForUpdates"
    private static let skippedVersionKey = "skippedVersion"
    private static let latestRelease = URL(string: "https://api.github.com/repos/Eman-x/LiveSnip/releases/latest")!
    private static let website = URL(string: "https://eman.sa/livesnip/")!
    static let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"

    private let hud: HUD
    private var timer: Timer?
    private var isBusy = false

    init(hud: HUD) {
        self.hud = hud
    }

    /// Checks shortly after launch and then once a day, while automatic checks are on.
    func startAutomaticChecks() {
        timer = Timer.scheduledTimer(withTimeInterval: 24 * 60 * 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.check(userInitiated: false) }
        }
        Task {
            try? await Task.sleep(for: .seconds(5))
            check(userInitiated: false)
        }
    }

    func check(userInitiated: Bool) {
        guard !isBusy, userInitiated || UserDefaults.standard.bool(forKey: Self.automaticChecksKey) else { return }
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                let release = try await Self.fetchLatest()
                if Self.isNewer(release.version, than: Self.currentVersion) {
                    let skipped = UserDefaults.standard.string(forKey: Self.skippedVersionKey)
                    if userInitiated || release.version != skipped { await offer(release) }
                } else if userInitiated {
                    tell("LiveSnip is up to date", "Version \(Self.currentVersion) is the newest version.")
                }
            } catch {
                if userInitiated { tell("Couldn't check for updates", error.localizedDescription) }
            }
        }
    }

    private func offer(_ release: Release) async {
        let alert = NSAlert()
        alert.messageText = "LiveSnip \(release.version) is available"
        alert.informativeText = "You have \(Self.currentVersion).\n\n" + Self.summary(of: release.notes)
        alert.addButton(withTitle: "Install and Relaunch")
        alert.addButton(withTitle: "Later")
        alert.addButton(withTitle: "Skip This Version")
        NSApp.activate()
        switch alert.runModal() {
        case .alertFirstButtonReturn: await install(release)
        case .alertThirdButtonReturn: UserDefaults.standard.set(release.version, forKey: Self.skippedVersionKey)
        default: break
        }
    }

    private func install(_ release: Release) async {
        hud.show(symbol: "arrow.down.circle", title: "Downloading LiveSnip \(release.version)…")
        do {
            let app = Bundle.main.bundleURL
            // An app opened straight from Downloads runs from a temporary, read-only copy.
            guard !app.path.contains("/AppTranslocation/") else { throw Problem.notInApplications }

            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("LiveSnip-update-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let (download, _) = try await URLSession.shared.download(from: release.download)
            let zip = folder.appendingPathComponent("LiveSnip.zip")
            try FileManager.default.moveItem(at: download, to: zip)
            let newApp = try Self.extract(zip, into: folder)
            guard Self.isSignedLikeThisApp(newApp) else { throw Problem.notSignedLikeThisApp }

            _ = try FileManager.default.replaceItemAt(app, withItemAt: newApp)
            AppDelegate.relaunch()
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn't update LiveSnip"
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: "Download from Website")
            alert.addButton(withTitle: "Cancel")
            NSApp.activate()
            if alert.runModal() == .alertFirstButtonReturn { NSWorkspace.shared.open(Self.website) }
        }
    }

    private func tell(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        NSApp.activate()
        alert.runModal()
    }

    // MARK: - Steps, kept separate so they can be checked on their own

    static func fetchLatest() async throws -> Release {
        var request = URLRequest(url: latestRelease)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let release = try decoder.decode(GitHubRelease.self, from: data)
        guard let asset = release.assets.first(where: { $0.name == "LiveSnip.zip" }) else { throw Problem.noDownload }
        return Release(version: String(release.tagName.trimmingPrefix("v")), notes: release.body ?? "",
                       download: asset.browserDownloadUrl)
    }

    /// Compares dotted version numbers, so 1.10.0 is newer than 1.9.2.
    static func isNewer(_ version: String, than current: String) -> Bool {
        let new = version.split(separator: ".").map { Int($0) ?? 0 }
        let old = current.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(new.count, old.count) {
            let a = i < new.count ? new[i] : 0, b = i < old.count ? old[i] : 0
            if a != b { return a > b }
        }
        return false
    }

    /// The "What's new" bullets from the release notes, without Markdown.
    static func summary(of notes: String) -> String {
        let section = notes.components(separatedBy: "## What's new").dropFirst().first ?? notes
        let bullets = section.components(separatedBy: "\n## ").first?
            .split(separator: "\n")
            .filter { $0.hasPrefix("- ") }
            .map { "• " + $0.dropFirst(2).replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "`", with: "") }
            ?? []
        return bullets.prefix(6).joined(separator: "\n")
    }

    static func extract(_ zip: URL, into folder: URL) throws -> URL {
        let ditto = Process()
        ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        ditto.arguments = ["-x", "-k", zip.path, folder.path]
        try ditto.run()
        ditto.waitUntilExit()
        let app = folder.appendingPathComponent("LiveSnip.app")
        guard ditto.terminationStatus == 0, FileManager.default.fileExists(atPath: app.path) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return app
    }

    static func isSignedLikeThisApp(_ app: URL) -> Bool {
        var running: SecCode?
        var runningStatic: SecStaticCode?
        guard SecCodeCopySelf([], &running) == errSecSuccess, let running,
              SecCodeCopyStaticCode(running, [], &runningStatic) == errSecSuccess, let runningStatic
        else { return false }
        return isSigned(app, like: runningStatic)
    }

    /// True when `app` has a valid signature that meets `reference`'s designated requirement:
    /// same identifier, same signing certificate. An ad-hoc build's requirement is its own hash,
    /// which no other build can meet, so ad-hoc builds never update themselves.
    static func isSigned(_ app: URL, like reference: SecStaticCode) -> Bool {
        var requirement: SecRequirement?
        var candidate: SecStaticCode?
        guard SecCodeCopyDesignatedRequirement(reference, [], &requirement) == errSecSuccess, let requirement,
              SecStaticCodeCreateWithPath(app as CFURL, [], &candidate) == errSecSuccess, let candidate
        else { return false }
        let flags = SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSStrictValidate | kSecCSCheckNestedCode)
        return SecStaticCodeCheckValidity(candidate, flags, requirement) == errSecSuccess
    }

    private struct GitHubRelease: Decodable {
        struct Asset: Decodable {
            let name: String
            let browserDownloadUrl: URL
        }

        let tagName: String
        let body: String?
        let assets: [Asset]
    }
}
