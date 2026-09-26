# Changelog

All notable changes to LiveSnip are documented here. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and LiveSnip follows [Semantic Versioning](https://semver.org/).

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

[1.0.0]: https://github.com/Eman-x/LiveSnip/releases/tag/v1.0.0
