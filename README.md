# LiveSnip

Copy text from anywhere on your screen with Apple's Live Text.

LiveSnip is a tiny menu bar app for macOS, like TextSniper but free and open source. Press **⇧⌘2**, drag over any text (in an image, a video, a scanned PDF, or an app that won't let you select it), and the text is on your clipboard.

![Selecting a slide's text with LiveSnip and the "Text copied" confirmation](docs/demo.png)

## Features

- **Live Text accuracy.** Uses VisionKit's `ImageAnalyzer`, the same on-device engine as Live Text in Photos and Preview. Nothing leaves your Mac.
- **Many languages.** Reads every language Live Text does, including English, Arabic, Chinese, Japanese, Korean, French, German, and Spanish.
- **Stays out of the way.** Lives in the menu bar, confirms each copy with a small toast, and never steals focus.
- **Keep or join lines.** Keep the original line breaks, or turn them off to get one clean paragraph.
- **Tiny.** A 72 KB download with no dependencies.

![Arabic text copied with LiveSnip](docs/arabic.png)

## Install

1. Download **LiveSnip-1.0.0.zip** from the [latest release](https://github.com/Eman-x/LiveSnip/releases/latest), unzip it, and move **LiveSnip** to **Applications**.
2. Open it. LiveSnip isn't notarized by Apple, so macOS blocks the first launch. Go to **System Settings → Privacy & Security**, scroll down, and click **Open Anyway**.
3. Press **⇧⌘2**. When macOS asks, turn LiveSnip on under **Privacy & Security → Screen & System Audio Recording**, then choose **Quit & Reopen**. This lets it see other apps' windows.

Requires macOS 26 Tahoe or later, on Apple Silicon or Intel.

## Usage

| Press | To |
| --- | --- |
| **⇧⌘2**, then drag | Copy the text in an area |
| **⇧⌘2**, then **Space**, then click a window | Copy the text in a window |
| **Esc** | Cancel |

The menu bar icon has **Capture Text**, **Keep Line Breaks**, and **Quit**.

LiveSnip also reads image files from the terminal:

```sh
/Applications/LiveSnip.app/Contents/MacOS/LiveSnip --ocr screenshot.png
```

## Build from source

You need Xcode 26, or the Command Line Tools with the macOS 26 SDK.

```sh
git clone https://github.com/Eman-x/LiveSnip.git
cd LiveSnip
./build.sh install
```

`./build.sh` builds `build/LiveSnip.app` and a release zip, and `install` also copies the app to `~/Applications` and launches it. To use a different shortcut, change `Shortcut` in [`Sources/AppDelegate.swift`](Sources/AppDelegate.swift).

## License

[MIT](LICENSE)
