//
//  DocumentManager.swift
//  MDRead
//
//  Created by Yasser Tamimi on 03/04/2026.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers
import WebKit

extension Notification.Name {
    static let openFileRequest = Notification.Name("openFileRequest")
    static let showOpenPanel = Notification.Name("showOpenPanel")
    static let loadInitialStateRequest = Notification.Name("loadInitialStateRequest")
}

enum OptionClickBehavior: String, CaseIterable {
    case newTab = "newTab"
    case newWindow = "newWindow"

    var label: String {
        switch self {
        case .newTab: "New Tab"
        case .newWindow: "New Window"
        }
    }
}

enum UnsavedChangeResolution {
    case save
    case discard
    case cancel
}

@Observable
class DocumentManager {
    let windowSessionID = UUID().uuidString
    var currentFileURL: URL?
    var documentText: String = ""
    var draftText: String = ""
    var isEditing = false
    var lastSaveError: String?
    weak var webView: WKWebView?
    var unsavedChangeResolver: (URL?) -> UnsavedChangeResolution = { url in
        DocumentManager.promptForUnsavedChanges(fileURL: url)
    }

    var hasUnsavedChanges: Bool {
        isEditing && draftText != documentText
    }

    /// File URL to load in the next new window/tab (used for coordination)
    static var pendingFileURL: URL?
    private static var pendingLaunchFileURL: URL?
    private static var launchModeResolved = false
    private static var didRestoreSavedSession = false
    static var isAppTerminating = false

    var optionClickBehavior: OptionClickBehavior {
        didSet {
            UserDefaults.standard.set(optionClickBehavior.rawValue, forKey: "optionClickBehavior")
        }
    }

    static let markdownExtensions: Set<String> = [
        "md", "markdown", "mdown", "mkdn", "mkd", "mdx"
    ]

    private static let markdownContentTypes: [UTType] = [
        UTType(filenameExtension: "md"),
        UTType(filenameExtension: "markdown"),
        UTType(filenameExtension: "mdown"),
        UTType(filenameExtension: "mkdn"),
        UTType(filenameExtension: "mkd"),
        UTType(filenameExtension: "mdx"),
    ].compactMap { $0 }

    init() {
        let raw = UserDefaults.standard.string(forKey: "optionClickBehavior") ?? "newTab"
        optionClickBehavior = OptionClickBehavior(rawValue: raw) ?? .newTab
    }

    func beginEditing() {
        guard currentFileURL != nil else { return }
        draftText = documentText
        isEditing = true
    }

    @discardableResult
    func requestEndEditing() -> Bool {
        guard isEditing else { return true }
        return resolveUnsavedChangesBeforeLeavingEditMode()
    }

    func toggleEditing() {
        if isEditing {
            _ = requestEndEditing()
        } else {
            beginEditing()
        }
    }

    @discardableResult
    func saveDraft() -> Bool {
        guard let currentFileURL else { return false }
        do {
            try draftText.write(to: currentFileURL, atomically: true, encoding: .utf8)
            documentText = draftText
            lastSaveError = nil
            NSDocumentController.shared.noteNewRecentDocumentURL(currentFileURL)
            DocumentSessionStore.updateWindow(id: windowSessionID, fileURL: currentFileURL)
            return true
        } catch {
            lastSaveError = error.localizedDescription
            Self.showSaveError(error, fileURL: currentFileURL)
            return false
        }
    }

    func discardDraft() {
        draftText = documentText
        isEditing = false
    }

    func openFile(url: URL) {
        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            guard resolveUnsavedChangesBeforeLeavingEditMode() else { return }
            currentFileURL = url
            documentText = text
            draftText = text
            isEditing = false
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
            DocumentSessionStore.updateWindow(id: windowSessionID, fileURL: url)
        } catch {}
    }

    func openFileInNewWindow(url: URL) {
        Self.pendingFileURL = url
        // Open a new window — SwiftUI's WindowGroup creates a fresh instance
        if let currentWindow = NSApp.keyWindow,
           let windowController = currentWindow.windowController {
            windowController.newWindowForTab(nil)
            // Don't merge as tab — let it stay as a separate window
        }
    }

    func openFileInNewTab(url: URL) {
        guard let currentWindow = NSApp.keyWindow,
              let windowController = currentWindow.windowController else {
            openFileInNewWindow(url: url)
            return
        }

        Self.pendingFileURL = url

        // Create a new window and merge it as a tab
        windowController.newWindowForTab(nil)
        if let newWindow = NSApp.keyWindow, currentWindow != newWindow {
            currentWindow.addTabbedWindow(newWindow, ordered: .above)
            newWindow.makeKeyAndOrderFront(nil)
        }
    }

    func handleOptionClick(url: URL) {
        switch optionClickBehavior {
        case .newTab: openFileInNewTab(url: url)
        case .newWindow: openFileInNewWindow(url: url)
        }
    }

    func showOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = Self.markdownContentTypes
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        openFile(url: url)
    }

    func exportPDF(webView: WKWebView?) {
        guard let webView = webView ?? self.webView else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        let baseName = currentFileURL?.deletingPathExtension().lastPathComponent ?? "document"
        panel.nameFieldStringValue = baseName + ".pdf"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        webView.createPDF { result in
            if case .success(let data) = result {
                try? data.write(to: url)
            }
        }
    }

    func printDocument(webView: WKWebView?) {
        guard let webView else { return }
        let printInfo = NSPrintInfo.shared
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        let printOp = webView.printOperation(with: printInfo)
        printOp.showsPrintPanel = true
        printOp.showsProgressPanel = true
        printOp.run()
    }

    private var didLoadInitial = false

    /// Load pending files or restore the saved open-window session.
    func loadInitialState() {
        guard !didLoadInitial else { return }
        guard Self.launchModeResolved else { return }
        didLoadInitial = true

        if let pending = Self.pendingLaunchFileURL {
            Self.pendingLaunchFileURL = nil
            openFile(url: pending)
        } else if let pending = Self.pendingFileURL {
            Self.pendingFileURL = nil
            openFile(url: pending)
        } else {
            restoreSavedSessionIfNeeded()
        }
    }

    func windowDidClose() {
        guard !Self.isAppTerminating else { return }
        DocumentSessionStore.removeWindow(id: windowSessionID)
    }

    static func prepareInitialExternalOpen(url: URL) {
        DocumentSessionStore.clear()
        pendingLaunchFileURL = url
        didRestoreSavedSession = true
        launchModeResolved = true
    }

    static func resolveNormalLaunch() {
        guard !launchModeResolved else { return }
        launchModeResolved = true
    }

    private func restoreSavedSessionIfNeeded() {
        guard !Self.didRestoreSavedSession else { return }
        Self.didRestoreSavedSession = true

        let urls = DocumentSessionStore.restorableFileURLs()
        DocumentSessionStore.clear()
        guard let firstURL = urls.first else { return }
        openFile(url: firstURL)

        for url in urls.dropFirst() {
            openFileInNewWindow(url: url)
        }
    }

    private func resolveUnsavedChangesBeforeLeavingEditMode() -> Bool {
        guard hasUnsavedChanges else {
            isEditing = false
            draftText = documentText
            return true
        }

        switch unsavedChangeResolver(currentFileURL) {
        case .save:
            guard saveDraft() else { return false }
            isEditing = false
            return true
        case .discard:
            discardDraft()
            return true
        case .cancel:
            return false
        }
    }

    // MARK: - Static helpers

    static func promptForUnsavedChanges(fileURL: URL?) -> UnsavedChangeResolution {
        let alert = NSAlert()
        let name = fileURL?.lastPathComponent ?? "this document"
        alert.messageText = "Save changes to \(name)?"
        alert.informativeText = "Your changes will be lost if you do not save them."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Discard")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return .save
        case .alertSecondButtonReturn:
            return .discard
        default:
            return .cancel
        }
    }

    static func showSaveError(_ error: Error, fileURL: URL?) {
        let alert = NSAlert()
        let name = fileURL?.lastPathComponent ?? "document"
        alert.messageText = "Could not save \(name)"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    /// Export a file to PDF without opening it in the viewer
    static func exportFileToPDF(fileURL: URL) {
        guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = fileURL.deletingPathExtension().lastPathComponent + ".pdf"
        guard panel.runModal() == .OK, let saveURL = panel.url else { return }

        // Create offscreen WebView, render markdown, export PDF
        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))

        // Build minimal HTML with marked.js
        let escapedMarkdown = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")

        let markedScript: String
        if let jsURL = Bundle.main.url(forResource: "marked.min", withExtension: "js"),
           let js = try? String(contentsOf: jsURL, encoding: .utf8) {
            markedScript = js
        } else {
            markedScript = ""
        }

        let html = """
        <!DOCTYPE html><html><head><meta charset="utf-8">
        <style>body { font-family: -apple-system, sans-serif; font-size: 14px; line-height: 1.6; padding: 20px; max-width: 800px; margin: 0 auto; }</style>
        <script>\(markedScript)</script></head>
        <body><div id="content"></div>
        <script>document.getElementById('content').innerHTML = marked.parse(`\(escapedMarkdown)`);</script>
        </body></html>
        """

        // Use a delegate to know when loading finishes
        let delegate = PDFExportDelegate(saveURL: saveURL, webView: webView)
        webView.navigationDelegate = delegate
        // Keep delegate alive
        objc_setAssociatedObject(webView, "pdfDelegate", delegate, .OBJC_ASSOCIATION_RETAIN)
        webView.loadHTMLString(html, baseURL: nil)
    }

    static func revealInFinder(url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    static func copyPath(url: URL) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.path, forType: .string)
    }

    static func copyAsMarkdownLink(url: URL) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("[\(url.lastPathComponent)](\(url.path))", forType: .string)
    }
}

struct DocumentSessionEntry: Codable, Equatable {
    let windowID: String
    let path: String
}

enum DocumentSessionStore {
    static let userDefaultsKey = "openDocumentSession"

    static func entries(defaults: UserDefaults = .standard) -> [DocumentSessionEntry] {
        guard let data = defaults.data(forKey: userDefaultsKey),
              let entries = try? JSONDecoder().decode([DocumentSessionEntry].self, from: data) else {
            return []
        }
        return entries
    }

    static func updateWindow(
        id: String,
        fileURL: URL,
        defaults: UserDefaults = .standard
    ) {
        var entries = entries(defaults: defaults)
        entries.removeAll { $0.windowID == id }
        entries.append(DocumentSessionEntry(windowID: id, path: fileURL.path))
        save(entries, defaults: defaults)
    }

    static func removeWindow(id: String, defaults: UserDefaults = .standard) {
        var entries = entries(defaults: defaults)
        entries.removeAll { $0.windowID == id }
        save(entries, defaults: defaults)
    }

    static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: userDefaultsKey)
        defaults.removeObject(forKey: "lastOpenedFilePath")
    }

    static func restorableFileURLs(
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default
    ) -> [URL] {
        entries(defaults: defaults)
            .map { URL(fileURLWithPath: $0.path) }
            .filter { fileManager.fileExists(atPath: $0.path) }
    }

    private static func save(_ entries: [DocumentSessionEntry], defaults: UserDefaults) {
        guard !entries.isEmpty else {
            defaults.removeObject(forKey: userDefaultsKey)
            return
        }
        if let data = try? JSONEncoder().encode(entries) {
            defaults.set(data, forKey: userDefaultsKey)
        }
    }
}

// MARK: - PDF Export Delegate

class PDFExportDelegate: NSObject, WKNavigationDelegate {
    let saveURL: URL
    let webView: WKWebView

    init(saveURL: URL, webView: WKWebView) {
        self.saveURL = saveURL
        self.webView = webView
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.createPDF { [weak self] result in
            guard let self else { return }
            if case .success(let data) = result {
                try? data.write(to: self.saveURL)
            }
            // Clean up
            objc_setAssociatedObject(webView, "pdfDelegate", nil, .OBJC_ASSOCIATION_RETAIN)
        }
    }
}
