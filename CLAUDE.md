# MDRead

A simple, read-only Markdown viewer for macOS built with Swift and SwiftUI.

## Architecture

- **WindowGroup app** with per-window `DocumentManager` — read-only, no editing, files open in the same window by default
- **AppDelegate** handles Finder double-click and dock drag-and-drop via `application(_:open:)`
- **Rendering**: WKWebView with marked.js (v15.0.7) for Markdown-to-HTML conversion
- **Syntax highlighting**: highlight.js (v11.11.1) with GitHub light/dark themes
- **Styling**: Inline GitHub-style CSS with `data-theme` attribute for light/dark/auto mode
- **Communication**: JS-to-Swift via `WKScriptMessageHandler` (TOC extraction, active heading tracking), Swift-to-JS via `evaluateJavaScript` (theme, font size, search)
- **File Explorer**: Full filesystem tree (from `/`) showing only folders and `.md` files, with lazy loading and sandbox bookmark management

## Project Structure

```
MDRead/MDRead/
  MDReadApp.swift              - App entry point, WindowGroup, AppDelegate, Commands, Settings
  DocumentManager.swift        - @Observable per-window document state, file opening, tabs, PDF export
  ContentView.swift            - Main view: NavigationSplitView with tabbed sidebar + WebView
  MarkdownWebView.swift        - NSViewRepresentable wrapping WKWebView, HTML/CSS/JS rendering
  SidebarContainerView.swift   - Tabbed sidebar container (Headings / Files toggle)
  TableOfContentsView.swift    - TOC sidebar with scroll-synced active heading highlight
  FileExplorerView.swift       - Filesystem tree with context menus, Option+click, current file highlight
  FileExplorerViewModel.swift  - FileNode tree model, lazy directory scanning, async reveal
  SandboxBookmarkManager.swift - Security-scoped bookmark persistence for folder access
  AppearanceManager.swift      - @Observable class for light/dark/auto mode (UserDefaults)
  WindowAccessor.swift         - NSWindow frame autosave for window position persistence
  FocusedValues+Extensions.swift - FocusedValueKey for font size, print, PDF export, search
  marked.min.js                - Markdown parser library (v15.0.7)
  highlight.min.js             - Syntax highlighting library (v11.11.1)
  github.min.css               - Highlight.js light theme
  github-dark.min.css          - Highlight.js dark theme
```

## Build

```bash
cd MDRead && xcodebuild -scheme MDRead -configuration Debug build
```

## Key Patterns

- **Per-window DocumentManager** — Each window/tab has its own `@State DocumentManager` instance. `FileExplorerViewModel` and `SandboxBookmarkManager` are shared across all windows via `@State` on `MDReadApp` + `.environment()`.
- **Notification-based routing** — File > Open (Cmd+O) and Finder double-click use `NotificationCenter` to route to the active window's `DocumentManager`.
- **Static `pendingFileURL`** — When opening a file in a new tab/window, the URL is stored statically and consumed by the new `ContentView.onAppear` via `loadInitialState()`.
- **FocusedValue** pattern connects per-window state (font size, print action) to app-level Commands.
- **Coordinator** in MarkdownWebView deduplicates reloads and handles WKNavigationDelegate + WKScriptMessageHandler.
- **Async file reveal** — `revealFile` scans directories on a background thread to avoid blocking the UI.
- YAML frontmatter (`---` blocks) is stripped before rendering.
- CSS uses `var(--base-font-size)` and `data-theme` attribute for runtime changes without full page reload.
- App Sandbox is enabled with `files.user-selected.read-write`, `network.client`, and `files.bookmarks.app-scope` entitlements.

## File Explorer Context Menus

**Files:** Open, Open in New Tab, Open in New Window, Reveal in Finder, Export to PDF, Copy Path, Copy as Markdown Link

**Folders:** Reveal in Finder, Copy Path, Collapse

## Sandbox & Permissions

- App Sandbox is enabled
- `com.apple.security.files.user-selected.read-write` — File open/save dialogs
- `com.apple.security.network.client` — Required for WKWebView
- `com.apple.security.files.bookmarks.app-scope` — Persist folder access grants
- Users can grant access to restricted folders via "Grant Access" button in the file explorer
- Security-scoped bookmarks persist across app restarts
