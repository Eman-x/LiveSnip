# Changelog

All notable changes to LiveSnip are documented here. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and LiveSnip follows [Semantic Versioning](https://semver.org/).

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

[1.2.0]: https://github.com/Eman-x/LiveSnip/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/Eman-x/LiveSnip/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/Eman-x/LiveSnip/releases/tag/v1.0.0
