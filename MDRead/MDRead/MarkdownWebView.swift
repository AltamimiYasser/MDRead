//
//  MarkdownWebView.swift
//  MDRead
//
//  Created by Yasser Tamimi on 03/04/2026.
//

import SwiftUI
import WebKit

struct MarkdownWebView: NSViewRepresentable {
    let markdown: String
    var theme: String = "auto" // "auto", "light", "dark"
    var fontSize: CGFloat = 14
    var searchText: String = ""
    var onTOCUpdate: (([TOCItem]) -> Void)?
    var onLoadComplete: (() -> Void)?
    var onWebViewReady: ((WKWebView) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "tocHandler")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        context.coordinator.onTOCUpdate = onTOCUpdate
        context.coordinator.onLoadComplete = onLoadComplete

        DispatchQueue.main.async {
            onWebViewReady?(webView)
        }

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.onTOCUpdate = onTOCUpdate
        context.coordinator.onLoadComplete = onLoadComplete

        let contentChanged = context.coordinator.lastMarkdown != markdown
        let themeChanged = context.coordinator.lastTheme != theme
        let fontChanged = context.coordinator.lastFontSize != fontSize
        let searchChanged = context.coordinator.lastSearchText != searchText

        if contentChanged {
            context.coordinator.lastMarkdown = markdown
            context.coordinator.lastTheme = theme
            context.coordinator.lastFontSize = fontSize
            let stripped = Self.stripFrontmatter(markdown)
            let html = buildHTML(from: stripped)
            webView.loadHTMLString(html, baseURL: nil)
        } else {
            if themeChanged {
                context.coordinator.lastTheme = theme
                webView.evaluateJavaScript("setTheme('\(theme)')")
            }
            if fontChanged {
                context.coordinator.lastFontSize = fontSize
                webView.evaluateJavaScript("setFontSize(\(fontSize))")
            }
        }

        if searchChanged {
            context.coordinator.lastSearchText = searchText
            if searchText.isEmpty {
                webView.evaluateJavaScript("clearSearch()")
            } else {
                let escaped = searchText.replacingOccurrences(of: "'", with: "\\'")
                webView.evaluateJavaScript("searchInPage('\(escaped)')")
            }
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var webView: WKWebView?
        var lastMarkdown: String?
        var lastTheme: String?
        var lastFontSize: CGFloat?
        var lastSearchText: String?
        var onTOCUpdate: (([TOCItem]) -> Void)?
        var onLoadComplete: (() -> Void)?

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            onLoadComplete?()
        }

        nonisolated func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            MainActor.assumeIsolated {
                guard message.name == "tocHandler",
                      let body = message.body as? String,
                      let data = body.data(using: .utf8),
                      let items = try? JSONDecoder().decode([TOCItem].self, from: data)
                else { return }
                onTOCUpdate?(items)
            }
        }
    }

    // MARK: - Frontmatter

    private static func stripFrontmatter(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("---") else { return text }
        let startIndex = trimmed.index(trimmed.startIndex, offsetBy: 3)
        let rest = trimmed[startIndex...]
        guard let closingRange = rest.range(of: "\n---") else { return text }
        let afterFrontmatter = rest[closingRange.upperBound...]
        return String(afterFrontmatter).trimmingCharacters(in: .newlines)
    }

    // MARK: - HTML Builder

    private func buildHTML(from markdown: String) -> String {
        let escapedMarkdown = markdown
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")

        let markedScript = Self.loadResource("marked.min", ext: "js")
        let highlightScript = Self.loadResource("highlight.min", ext: "js")
        let highlightLightCSS = Self.loadResource("github.min", ext: "css")
        let highlightDarkCSS = Self.loadResource("github-dark.min", ext: "css")

        return """
        <!DOCTYPE html>
        <html data-theme="\(theme)" style="--base-font-size: \(fontSize)px;">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        \(Self.githubCSS)
        </style>
        <style id="hljs-light">
        \(highlightLightCSS)
        </style>
        <style id="hljs-dark">
        \(highlightDarkCSS)
        </style>
        <style>
        /* Only apply one highlight theme at a time */
        html[data-theme="dark"] #hljs-light { display: none; }
        html[data-theme="light"] #hljs-dark { display: none; }
        html[data-theme="auto"] #hljs-dark { display: none; }
        @media (prefers-color-scheme: dark) {
            html[data-theme="auto"] #hljs-dark { display: initial; }
            html[data-theme="auto"] #hljs-light { display: none; }
        }
        /* Override highlight.js backgrounds to use our code block styles */
        pre code.hljs { background: transparent; padding: 0; }
        mark.search-highlight { background-color: #fff3bf; color: #1f2328; border-radius: 2px; padding: 0 1px; }
        @media (prefers-color-scheme: dark) {
            html[data-theme="auto"] mark.search-highlight { background-color: #6e5e1e; color: #e6edf3; }
        }
        html[data-theme="dark"] mark.search-highlight { background-color: #6e5e1e; color: #e6edf3; }
        </style>
        <script>\(markedScript)</script>
        <script>\(highlightScript)</script>
        </head>
        <body>
        <article class="markdown-body">
        </article>
        <script>
        // Theme management
        function setTheme(theme) {
            document.documentElement.setAttribute('data-theme', theme);
        }

        // Font size management
        function setFontSize(size) {
            document.documentElement.style.setProperty('--base-font-size', size + 'px');
        }

        // Search
        function clearSearch() {
            document.querySelectorAll('mark.search-highlight').forEach(el => {
                const parent = el.parentNode;
                parent.replaceChild(document.createTextNode(el.textContent), el);
                parent.normalize();
            });
        }

        function searchInPage(query) {
            clearSearch();
            if (!query) return;
            const body = document.querySelector('.markdown-body');
            const walker = document.createTreeWalker(body, NodeFilter.SHOW_TEXT);
            const matches = [];
            while (walker.nextNode()) {
                const node = walker.currentNode;
                if (node.parentElement && node.parentElement.tagName === 'SCRIPT') continue;
                const idx = node.textContent.toLowerCase().indexOf(query.toLowerCase());
                if (idx >= 0) matches.push({ node, idx, len: query.length });
            }
            for (let i = matches.length - 1; i >= 0; i--) {
                const { node, idx, len } = matches[i];
                const range = document.createRange();
                range.setStart(node, idx);
                range.setEnd(node, idx + len);
                const mark = document.createElement('mark');
                mark.className = 'search-highlight';
                range.surroundContents(mark);
            }
            const first = document.querySelector('mark.search-highlight');
            if (first) first.scrollIntoView({ behavior: 'smooth', block: 'center' });
        }

        // Smooth anchor scrolling
        document.addEventListener('click', function(e) {
            const anchor = e.target.closest('a[href^="#"]');
            if (anchor) {
                e.preventDefault();
                const targetId = anchor.getAttribute('href').substring(1);
                const target = document.getElementById(targetId);
                if (target) {
                    target.scrollIntoView({ behavior: 'smooth', block: 'start' });
                }
            }
        });

        // Render markdown
        const markdown = `\(escapedMarkdown)`;
        if (typeof marked !== 'undefined') {
            document.querySelector('.markdown-body').innerHTML = marked.parse(markdown);

            // Syntax highlighting
            if (typeof hljs !== 'undefined') {
                document.querySelectorAll('pre code').forEach(block => {
                    hljs.highlightElement(block);
                });
            }

            // Extract TOC and assign heading IDs
            const headings = [];
            document.querySelectorAll('h1, h2, h3, h4, h5, h6').forEach((el, i) => {
                const slug = el.textContent.trim().toLowerCase()
                    .replace(/[^\\w\\s-]/g, '').replace(/\\s+/g, '-');
                const id = slug || ('heading-' + i);
                el.id = id;
                headings.push({ id: id, level: parseInt(el.tagName[1]), text: el.textContent.trim() });
            });
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.tocHandler) {
                window.webkit.messageHandlers.tocHandler.postMessage(JSON.stringify(headings));
            }
        } else {
            document.querySelector('.markdown-body').innerText = markdown;
        }
        </script>
        </body>
        </html>
        """
    }

    private static func loadResource(_ name: String, ext: String) -> String {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext),
              let content = try? String(contentsOf: url, encoding: .utf8)
        else { return "" }
        return content
    }

    // MARK: - CSS

    private static let githubCSS = """
    html { scroll-behavior: smooth; }
    body {
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", "Noto Sans", Helvetica, Arial, sans-serif;
        font-size: var(--base-font-size, 14px);
        line-height: 1.6;
        color: #1f2328;
        background-color: transparent;
        margin: 0;
        padding: 16px 32px;
    }
    /* Light theme (default) */
    a { color: #0969da; text-decoration: none; }
    a:hover { text-decoration: underline; }

    /* Dark mode - system preference */
    @media (prefers-color-scheme: dark) {
        html[data-theme="auto"] body { color: #e6edf3; }
        html[data-theme="auto"] a { color: #58a6ff; }
        html[data-theme="auto"] code, html[data-theme="auto"] pre { background-color: #282c34; }
        html[data-theme="auto"] pre { border-color: #444c56; }
        html[data-theme="auto"] blockquote { border-left-color: #444c56; color: #9198a1; }
        html[data-theme="auto"] table th, html[data-theme="auto"] table td { border-color: #444c56; }
        html[data-theme="auto"] table tr:nth-child(2n) { background-color: rgba(255,255,255,0.04); }
        html[data-theme="auto"] hr { background-color: #444c56; }
        html[data-theme="auto"] h1, html[data-theme="auto"] h2 { border-bottom-color: #444c56; }
        html[data-theme="auto"] img { filter: brightness(.9); }
    }

    /* Dark mode - forced */
    html[data-theme="dark"] body { color: #e6edf3; }
    html[data-theme="dark"] a { color: #58a6ff; }
    html[data-theme="dark"] code, html[data-theme="dark"] pre { background-color: #282c34; }
    html[data-theme="dark"] pre { border-color: #444c56; }
    html[data-theme="dark"] blockquote { border-left-color: #444c56; color: #9198a1; }
    html[data-theme="dark"] table th, html[data-theme="dark"] table td { border-color: #444c56; }
    html[data-theme="dark"] table tr:nth-child(2n) { background-color: rgba(255,255,255,0.04); }
    html[data-theme="dark"] hr { background-color: #444c56; }
    html[data-theme="dark"] h1, html[data-theme="dark"] h2 { border-bottom-color: #444c56; }
    html[data-theme="dark"] img { filter: brightness(.9); }

    .markdown-body {
        max-width: 980px;
        margin: 0 auto;
    }
    h1, h2, h3, h4, h5, h6 {
        margin-top: 24px;
        margin-bottom: 16px;
        font-weight: 600;
        line-height: 1.25;
    }
    h1 { font-size: 2em; padding-bottom: 0.3em; border-bottom: 1px solid #d1d9e0; }
    h2 { font-size: 1.5em; padding-bottom: 0.3em; border-bottom: 1px solid #d1d9e0; }
    h3 { font-size: 1.25em; }
    h4 { font-size: 1em; }
    h5 { font-size: 0.875em; }
    h6 { font-size: 0.85em; color: #636c76; }
    p { margin-top: 0; margin-bottom: 16px; }
    code {
        font-family: ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, monospace;
        font-size: 85%;
        padding: 0.2em 0.4em;
        background-color: rgba(175, 184, 193, 0.2);
        border-radius: 6px;
    }
    pre {
        font-family: ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, monospace;
        font-size: 85%;
        padding: 16px;
        overflow: auto;
        line-height: 1.45;
        background-color: #f6f8fa;
        border-radius: 6px;
        border: 1px solid #d1d9e0;
    }
    pre code {
        background-color: transparent;
        padding: 0;
        font-size: 100%;
        border-radius: 0;
    }
    blockquote {
        margin: 0 0 16px 0;
        padding: 0 1em;
        color: #636c76;
        border-left: 0.25em solid #d1d9e0;
    }
    ul, ol { margin-top: 0; margin-bottom: 16px; padding-left: 2em; }
    li + li { margin-top: 0.25em; }
    table { border-collapse: collapse; border-spacing: 0; margin-bottom: 16px; display: block; width: max-content; max-width: 100%; overflow: auto; }
    table th, table td { padding: 6px 13px; border: 1px solid #d1d9e0; }
    table th { font-weight: 600; }
    table tr:nth-child(2n) { background-color: #f6f8fa; }
    img { max-width: 100%; height: auto; }
    hr { height: 0.25em; padding: 0; margin: 24px 0; background-color: #d1d9e0; border: 0; }
    input[type="checkbox"] { margin-right: 0.5em; }
    """
}

// MARK: - TOC Model

struct TOCItem: Identifiable, Codable {
    let id: String
    let level: Int
    let text: String
}
