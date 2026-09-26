# Changelog

All notable changes to LiveSnip are documented here. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and LiveSnip follows [Semantic Versioning](https://semver.org/).

## [1.3.0] - 2026-09-26

### Added

- A **Permissions** tab showing whether Screen Recording is allowed: a green check when it is, and a button to the right page of System Settings when it isn't. LiveSnip opens it automatically when the permission is missing, and once more after it's allowed, to confirm it worked.
- An **About** tab with the version and a **Send Feedback…** button that emails me@eman.sa.
- **Settings…** and **About LiveSnip** in the menu, plus **Allow Screen Recording…** while the permission is missing.

### Changed

- Settings is now a window with tabs. **General** has the shortcut, **Open at Login**, and **Keep Line Breaks**, so everything in the menu is also there.
- Pressing the shortcut without Screen Recording opens the Permissions tab instead of System Settings.

## [1.2.0] - 2026-09-26

### Added

- **Open at Login**, in the menu bar menu and in the settings window, so LiveSnip starts with your Mac. At login it opens quietly, without the "LiveSnip is running" toast.

### Changed

- The shortcut window is now **LiveSnip Settings**. Opening LiveSnip while it's running shows it without starting to record a new shortcut.

## [1.1.0] - 2026-09-26

### Added

- App icon.
- **Change Shortcut…** in the menu bar menu records a new shortcut for Capture Text and remembers it.
- Opening LiveSnip while it's running shows the shortcut window, for when the menu bar is too full to show the icon.

## [1.0.0] - 2026-09-26

### Added

- Copy the text in any area of the screen with **⇧⌘2**, or press **Space** to pick a whole window.
- Text recognition with Apple's Live Text engine (VisionKit `ImageAnalyzer`), fully on device, in every language Live Text supports, including English and Arabic.
- Recognized text goes straight to the clipboard, and no screenshot is saved.
- A glass toast that confirms each copy with a preview of the text.
- **Keep Line Breaks** option to keep the original lines or join them into one paragraph.
- Menu bar icon with **Capture Text**, **Keep Line Breaks**, and **Quit**.
- `--ocr <image>` command-line mode that prints the text in an image file.
- Universal build for Apple Silicon and Intel Macs running macOS 26 or later.

[1.3.0]: https://github.com/Eman-x/LiveSnip/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/Eman-x/LiveSnip/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/Eman-x/LiveSnip/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/Eman-x/LiveSnip/releases/tag/v1.0.0
