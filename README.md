<p align="center">
  <img src="docs/logo.png" width="128" height="128" alt="LiveSnip icon">
</p>

<h1 align="center">LiveSnip</h1>

<p align="center">
  Copy text from anywhere on your screen with Apple's Live Text.
</p>

<p align="center">
  <a href="https://eman.sa/livesnip/"><strong>Website</strong></a> ·
  <a href="https://github.com/Eman-x/LiveSnip/releases/latest/download/LiveSnip.zip"><strong>Download for Mac</strong></a>
</p>

<p align="center">
  <a href="https://github.com/Eman-x/LiveSnip/releases/latest"><img src="https://img.shields.io/github/v/release/Eman-x/LiveSnip" alt="Latest release"></a>
  <img src="https://img.shields.io/badge/macOS-26%2B-blue" alt="macOS 26 or later">
  <a href="LICENSE"><img src="https://img.shields.io/github/license/Eman-x/LiveSnip" alt="MIT license"></a>
</p>

LiveSnip is a small menu bar app for macOS, like TextSniper but free and open source. Press **⇧⌘2**, drag over any text (in an image, a video, a scanned PDF, or an app that won't let you select it), and the text is on your clipboard.

![Selecting a slide's text with LiveSnip and the "Text copied" confirmation](docs/demo.png)

## Features

- **Live Text accuracy.** Uses VisionKit's `ImageAnalyzer`, the same on-device engine as Live Text in Photos and Preview. Nothing leaves your Mac.
- **English, Arabic, Spanish, and more.** Reads every language Live Text does, accents and right-to-left text included. That also covers Chinese, Japanese, Korean, French, German, Portuguese, and others.
- **Your shortcut.** Keep ⇧⌘2 or record any shortcut you like.
- **Stays out of the way.** Lives in the menu bar, can open at login, confirms each copy with a small toast, and never steals focus.
- **Keep or join lines.** Keep the original line breaks, or turn them off to get one clean paragraph.

<p align="center">
  <img src="docs/arabic.png" width="49%" alt="Arabic text copied with LiveSnip">
  <img src="docs/spanish.png" width="49%" alt="Spanish text copied with LiveSnip">
</p>

## Install

1. Download the zip from [eman.sa/livesnip](https://eman.sa/livesnip/) or the [latest release](https://github.com/Eman-x/LiveSnip/releases/latest), unzip it, and move **LiveSnip** to **Applications**.
2. Open it. LiveSnip isn't notarized by Apple, so macOS blocks the first launch. Go to **System Settings → Privacy & Security**, scroll down, and click **Open Anyway**.
3. LiveSnip opens its **Permissions** tab. Click **Open System Settings**, turn LiveSnip on under **Screen & System Audio Recording**, then choose **Quit & Reopen**. A green check confirms it's done. This lets it see other apps' windows.

Requires macOS 26 Tahoe or later, on Apple Silicon or Intel.

## Usage

| Press | To |
| --- | --- |
| **⇧⌘2**, then drag | Copy the text in an area |
| **⇧⌘2**, then **Space**, then click a window | Copy the text in a window |
| **Esc** | Cancel |

To use a different shortcut, choose **Change Shortcut…** from the menu bar icon and press the keys you want. To start LiveSnip with your Mac, choose **Open at Login**. **Settings…** has all of this plus the permission status, and its **About** tab has a **Send Feedback** button. If your menu bar is too full to show the icon, open LiveSnip again from Applications or Spotlight to get the settings window.

The menu also has **Keep Line Breaks** and **Quit**.

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

`./build.sh` builds `build/LiveSnip.app` and a release zip, and `install` also copies the app to `~/Applications` and launches it.

## License

[MIT](LICENSE)
