<p align="center">
  <img src="MDRead/MDRead/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" width="128" height="128" alt="MDRead Icon">
</p>

<h1 align="center">MDRead</h1>

<p align="center">
  A simple, beautiful Markdown reader for macOS.
  <br>
  GitHub-style rendering. No editing. Just reading.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS_15+-blue" alt="Platform">
  <img src="https://img.shields.io/badge/swift-5-orange" alt="Swift">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="License">
</p>

---

## Features

### Rendering
- **GitHub-style Markdown rendering** — Looks just like a GitHub README
- **Syntax highlighting** — Code blocks with language-aware coloring via [highlight.js](https://highlightjs.org/)
- **YAML frontmatter stripping** — Metadata blocks are hidden, just like on GitHub
- **Light / Dark / Auto mode** — Toggle in the toolbar or follow system appearance

### Navigation
- **File Explorer** — Built-in filesystem browser starting from `/`, showing only folders and `.md` files
- **Table of Contents** — Auto-generated from headings with scroll-synced active highlight
- **Tabbed sidebar** — Switch between File Explorer and Table of Contents
- **Tabs & Windows** — Open files in new tabs or windows, with configurable Option+click behavior

### Productivity
- **Search** — Find text within documents (Cmd+F)
- **Font size control** — Zoom in/out with Cmd+Plus / Cmd+Minus / Cmd+0
- **Print & PDF export** — Print (Cmd+P) or export as PDF (Cmd+Shift+E)
- **Right-click context menus** — Open, Open in New Tab/Window, Reveal in Finder, Export to PDF, Copy Path, Copy as Markdown Link
- **Window position memory** — Remembers where you left off

### File Access
- **Sandbox-safe** — Runs in App Sandbox with granular folder access
- **Grant Folder Access** — Unlock restricted directories with one click, persisted across restarts
- **Current file tracking** — Open file is highlighted in the explorer; collapsed parents show a blue dot indicator

## Installation

### Download

Download the latest `.dmg` from the [Releases](https://github.com/AltamimiYasser/MDRead/releases) page.

1. Open the DMG and drag `MDRead.app` to your Applications folder
2. On first launch, right-click > Open to bypass Gatekeeper (app is not notarized)
3. Open any `.md` file — from the built-in explorer, File > Open, or double-click in Finder

### Build from Source

```bash
git clone https://github.com/AltamimiYasser/MDRead.git
cd MDRead/MDRead
xcodebuild -scheme MDRead -configuration Release build
```

Or open `MDRead/MDRead.xcodeproj` in Xcode and press Cmd+R.

## Usage

1. **Browse files** — Use the File Explorer sidebar to navigate your filesystem
2. **Open a file** — Click any `.md` file, or use File > Open (Cmd+O)
3. **Navigate headings** — Switch to the Headings tab to see the Table of Contents
4. **Search** — Cmd+F to find text within the document
5. **Zoom** — Cmd+Plus to zoom in, Cmd+Minus to zoom out, Cmd+0 to reset
6. **Theme** — Use the toolbar toggle to switch between Light, Dark, and Auto modes
7. **Tabs** — Option+click a file to open in a new tab (configurable in Preferences)
8. **Export** — Cmd+P to print, Cmd+Shift+E to export as PDF, or right-click > Export to PDF

## Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Open file | Cmd+O |
| Find | Cmd+F |
| Zoom in | Cmd++ |
| Zoom out | Cmd+- |
| Reset zoom | Cmd+0 |
| Print | Cmd+P |
| Export PDF | Cmd+Shift+E |
| Close Tabs to the Right | Cmd+Option+Shift+W |
| Preferences | Cmd+, |

## Right-Click Context Menu

### On Markdown Files
- Open / Open in New Tab / Open in New Window
- Reveal in Finder
- Export to PDF
- Copy Path / Copy as Markdown Link

### On Folders
- Reveal in Finder
- Copy Path
- Collapse

## Tech Stack

- **SwiftUI** — Native macOS UI framework
- **WebKit (WKWebView)** — Markdown rendering engine
- **[marked.js](https://marked.js.org/)** v15.0.7 — Markdown to HTML parser
- **[highlight.js](https://highlightjs.org/)** v11.11.1 — Syntax highlighting
- **App Sandbox** — Secure file access with security-scoped bookmarks

## Requirements

- macOS 15.0 or later
- Xcode 16+ (for building from source)

## License

MIT License. See [LICENSE](LICENSE) for details.

---

<p align="center">
  Built with SwiftUI and a lot of Markdown.
</p>
