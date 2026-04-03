# MDRead

A simple, read-only Markdown viewer for macOS built with Swift and SwiftUI.

## Architecture

- **Document-based app** using `DocumentGroup(viewing:)` — read-only, no editing
- **Rendering**: WKWebView with marked.js (v15.0.7) for Markdown-to-HTML conversion
- **Syntax highlighting**: highlight.js (v11.11.1) with GitHub light/dark themes
- **Styling**: Inline GitHub-style CSS with `data-theme` attribute for light/dark/auto mode
- **Communication**: JS-to-Swift via `WKScriptMessageHandler` (TOC extraction), Swift-to-JS via `evaluateJavaScript` (theme, font size, search)

## Project Structure

```
MDRead/MDRead/
  MDReadApp.swift          - App entry point, menu commands (zoom, print, PDF export)
  MDReadDocument.swift     - FileDocument for .md/.markdown files
  ContentView.swift        - Main view: NavigationSplitView with TOC sidebar + WebView
  MarkdownWebView.swift    - NSViewRepresentable wrapping WKWebView, HTML/CSS/JS rendering
  AppearanceManager.swift  - @Observable class for light/dark/auto mode (UserDefaults)
  TableOfContentsView.swift - Sidebar listing headings extracted from rendered HTML
  WindowAccessor.swift     - NSWindow frame autosave for window position persistence
  FocusedValues+Extensions.swift - FocusedValueKey for font size, print, PDF export
  marked.min.js            - Markdown parser library
  highlight.min.js         - Syntax highlighting library
  github.min.css           - Highlight.js light theme
  github-dark.min.css      - Highlight.js dark theme
```

## Build

```bash
cd MDRead && xcodebuild -scheme MDRead -configuration Debug build
```

## Key Patterns

- **FocusedValue** pattern connects per-window state (font size, print action) to app-level Commands
- **Coordinator** in MarkdownWebView deduplicates reloads and handles WKNavigationDelegate + WKScriptMessageHandler
- YAML frontmatter (`---` blocks) is stripped before rendering
- CSS uses `var(--base-font-size)` and `data-theme` attribute for runtime changes without full page reload
- App Sandbox is enabled; `com.apple.security.network.client` entitlement is required for WKWebView
