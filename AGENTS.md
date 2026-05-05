# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## Build & Run

```bash
# Debug build
cd MDRead && xcodebuild -scheme MDRead -configuration Debug build

# Release build
cd MDRead && xcodebuild -scheme MDRead -configuration Release build

# Open in Xcode
open MDRead/MDRead.xcodeproj

# Run tests (placeholder/scaffolding only — unit tests use Swift Testing, UI tests use XCTest)
cd MDRead && xcodebuild test -scheme MDRead -destination 'platform=macOS'
```

## Release

Tag-based GitHub Actions workflow (`.github/workflows/release.yml`). Push a `v*` tag to build a release DMG artifact.

## Architecture

- **WindowGroup app** with per-window `DocumentManager` — read-only, no editing, files open in the same window by default
- **AppDelegate** handles Finder double-click and dock drag-and-drop via `application(_:open:)`
- **Rendering**: WKWebView with marked.js (v15.0.7) for Markdown-to-HTML conversion
- **Syntax highlighting**: highlight.js (v11.11.1) with GitHub light/dark themes
- **Styling**: Inline GitHub-style CSS with `data-theme` attribute for light/dark/auto mode
- **Communication**: JS-to-Swift via `WKScriptMessageHandler` (TOC extraction, active heading tracking), Swift-to-JS via `evaluateJavaScript` (theme, font size, search)
- **File Explorer**: Full filesystem tree (from `/`) showing only folders and `.md` files, with lazy loading and sandbox bookmark management
- **Registered document types**: md, markdown, mdown, mkdn, mkd, mdx (conforms to `net.daringfireball.markdown`)
- **Swift concurrency**: `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`
- **App Sandbox** enabled with `files.user-selected.read-write`, `network.client`, and `files.bookmarks.app-scope` entitlements (see `MDRead/MDRead/MDRead.entitlements`)

## Key Patterns

- **Per-window DocumentManager** — Each window/tab has its own `@State DocumentManager` instance. `FileExplorerViewModel` and `SandboxBookmarkManager` are shared across all windows via `@State` on `MDReadApp` + `.environment()`.
- **Notification-based routing** — File > Open (Cmd+O) and Finder double-click use `NotificationCenter` to route to the active window's `DocumentManager`.
- **Static `pendingFileURL`** — When opening a file in a new tab/window, the URL is stored statically and consumed by the new `ContentView.onAppear` via `loadInitialState()`.
- **FocusedValue** pattern connects per-window state (font size, print action) to app-level Commands.
- **Coordinator** in MarkdownWebView deduplicates reloads and handles WKNavigationDelegate + WKScriptMessageHandler.
- **Async file reveal** — `revealFile` scans directories on a background thread to avoid blocking the UI.
- YAML frontmatter (`---` blocks) is stripped before rendering.
- CSS uses `var(--base-font-size)` and `data-theme` attribute for runtime changes without full page reload.
