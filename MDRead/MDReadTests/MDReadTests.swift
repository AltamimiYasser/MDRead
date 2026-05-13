//
//  MDReadTests.swift
//  MDReadTests
//
//  Created by Yasser Tamimi on 03/04/2026.
//

import Testing
import AppKit
import Foundation
@testable import MDRead

@MainActor
struct MDReadTests {

    @Test func sessionStoreUpdatesWindowEntry() throws {
        let suiteName = "MDReadTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let first = try temporaryMarkdownFile(named: "first.md")
        let second = try temporaryMarkdownFile(named: "second.md")
        defer {
            try? FileManager.default.removeItem(at: first)
            try? FileManager.default.removeItem(at: second)
        }

        DocumentSessionStore.updateWindow(id: "window-a", fileURL: first, defaults: defaults)
        DocumentSessionStore.updateWindow(id: "window-b", fileURL: second, defaults: defaults)

        #expect(DocumentSessionStore.entries(defaults: defaults) == [
            DocumentSessionEntry(windowID: "window-a", path: first.path),
            DocumentSessionEntry(windowID: "window-b", path: second.path),
        ])

        DocumentSessionStore.updateWindow(id: "window-a", fileURL: second, defaults: defaults)

        #expect(DocumentSessionStore.entries(defaults: defaults) == [
            DocumentSessionEntry(windowID: "window-b", path: second.path),
            DocumentSessionEntry(windowID: "window-a", path: second.path),
        ])
    }

    @Test func sessionStoreRemovesClosedWindowOnly() throws {
        let suiteName = "MDReadTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let first = try temporaryMarkdownFile(named: "first.md")
        let second = try temporaryMarkdownFile(named: "second.md")
        defer {
            try? FileManager.default.removeItem(at: first)
            try? FileManager.default.removeItem(at: second)
        }

        DocumentSessionStore.updateWindow(id: "window-a", fileURL: first, defaults: defaults)
        DocumentSessionStore.updateWindow(id: "window-b", fileURL: second, defaults: defaults)
        DocumentSessionStore.removeWindow(id: "window-a", defaults: defaults)

        #expect(DocumentSessionStore.entries(defaults: defaults) == [
            DocumentSessionEntry(windowID: "window-b", path: second.path),
        ])
    }

    @Test func sessionStoreClearRemovesLegacyLastOpenedFile() throws {
        let suiteName = "MDReadTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let file = try temporaryMarkdownFile(named: "open.md")
        defer { try? FileManager.default.removeItem(at: file) }

        defaults.set(file.path, forKey: "lastOpenedFilePath")
        DocumentSessionStore.updateWindow(id: "window-a", fileURL: file, defaults: defaults)
        DocumentSessionStore.clear(defaults: defaults)

        #expect(DocumentSessionStore.entries(defaults: defaults).isEmpty)
        #expect(defaults.string(forKey: "lastOpenedFilePath") == nil)
    }

    @Test func restorableFilesIgnoreMissingPaths() throws {
        let suiteName = "MDReadTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let existing = try temporaryMarkdownFile(named: "existing.md")
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("md")
        defer { try? FileManager.default.removeItem(at: existing) }

        DocumentSessionStore.updateWindow(id: "window-a", fileURL: missing, defaults: defaults)
        DocumentSessionStore.updateWindow(id: "window-b", fileURL: existing, defaults: defaults)

        #expect(DocumentSessionStore.restorableFileURLs(defaults: defaults) == [existing])
    }

    @Test func terminatingAppDoesNotRemoveOpenWindowSession() throws {
        let file = try temporaryMarkdownFile(named: "quit-open.md")
        let manager = DocumentManager()
        defer {
            DocumentManager.isAppTerminating = false
            DocumentSessionStore.removeWindow(id: manager.windowSessionID)
            try? FileManager.default.removeItem(at: file)
        }

        DocumentSessionStore.updateWindow(id: manager.windowSessionID, fileURL: file)
        DocumentManager.isAppTerminating = true
        manager.windowDidClose()

        #expect(DocumentSessionStore.entries().contains(
            DocumentSessionEntry(windowID: manager.windowSessionID, path: file.path)
        ))
    }

    @Test func editingDraftSavesToCurrentFile() throws {
        let file = try temporaryMarkdownFile(named: "editable.md")
        let manager = DocumentManager()
        defer {
            DocumentSessionStore.removeWindow(id: manager.windowSessionID)
            try? FileManager.default.removeItem(at: file.deletingLastPathComponent())
        }

        manager.openFile(url: file)
        manager.beginEditing()
        manager.draftText = "# Updated\n\n**Bold** text\n"

        #expect(manager.hasUnsavedChanges)
        #expect(manager.saveDraft())
        #expect(!manager.hasUnsavedChanges)
        #expect(manager.documentText == "# Updated\n\n**Bold** text\n")
        #expect(try String(contentsOf: file, encoding: .utf8) == "# Updated\n\n**Bold** text\n")
    }

    @Test func leavingEditModeCanDiscardUnsavedDraft() throws {
        let file = try temporaryMarkdownFile(named: "discard.md")
        let manager = DocumentManager()
        defer {
            DocumentSessionStore.removeWindow(id: manager.windowSessionID)
            try? FileManager.default.removeItem(at: file.deletingLastPathComponent())
        }

        manager.openFile(url: file)
        manager.beginEditing()
        manager.draftText = "# Draft\n"
        manager.unsavedChangeResolver = { _ in .discard }

        #expect(manager.requestEndEditing())
        #expect(!manager.isEditing)
        #expect(!manager.hasUnsavedChanges)
        #expect(manager.documentText == "# Test\n")
        #expect(try String(contentsOf: file, encoding: .utf8) == "# Test\n")
    }

    @Test func openingAnotherFileCanCancelWhenDraftIsDirty() throws {
        let first = try temporaryMarkdownFile(named: "first.md")
        let second = try temporaryMarkdownFile(named: "second.md")
        try "# Second\n".write(to: second, atomically: true, encoding: .utf8)
        let manager = DocumentManager()
        defer {
            DocumentSessionStore.removeWindow(id: manager.windowSessionID)
            try? FileManager.default.removeItem(at: first.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: second.deletingLastPathComponent())
        }

        manager.openFile(url: first)
        manager.beginEditing()
        manager.draftText = "# Dirty\n"
        manager.unsavedChangeResolver = { _ in .cancel }

        manager.openFile(url: second)

        #expect(manager.currentFileURL == first)
        #expect(manager.isEditing)
        #expect(manager.draftText == "# Dirty\n")
        #expect(manager.documentText == "# Test\n")
    }

    @Test func openingAnotherFileCanSaveDirtyDraftBeforeSwitching() throws {
        let first = try temporaryMarkdownFile(named: "first.md")
        let second = try temporaryMarkdownFile(named: "second.md")
        try "# Second\n".write(to: second, atomically: true, encoding: .utf8)
        let manager = DocumentManager()
        defer {
            DocumentSessionStore.removeWindow(id: manager.windowSessionID)
            try? FileManager.default.removeItem(at: first.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: second.deletingLastPathComponent())
        }

        manager.openFile(url: first)
        manager.beginEditing()
        manager.draftText = "# Saved Before Switch\n"
        manager.unsavedChangeResolver = { _ in .save }

        manager.openFile(url: second)

        #expect(manager.currentFileURL == second)
        #expect(!manager.isEditing)
        #expect(manager.documentText == "# Second\n")
        #expect(try String(contentsOf: first, encoding: .utf8) == "# Saved Before Switch\n")
    }

    @Test func sourceEditorUsesPlainTextUndoEnabledTextView() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 400),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        let scrollView = NSTextView.scrollableTextView()
        window.contentView = scrollView
        let textView = try! #require(scrollView.documentView as? NSTextView)

        MarkdownSourceEditor.configure(textView, fontSize: 14)
        textView.string = ""
        textView.undoManager?.removeAllActions()
        window.makeFirstResponder(textView)
        textView.insertText("abc", replacementRange: NSRange(location: 0, length: 0))

        #expect(textView.allowsUndo)
        #expect(textView.undoManager?.canUndo == true)
        textView.undoManager?.undo()
        #expect(textView.string == "")
        #expect(textView.undoManager?.canRedo == true)
        textView.undoManager?.redo()
        #expect(textView.string == "abc")
        #expect(textView.isRichText == false)
        #expect(textView.importsGraphics == false)
        #expect(textView.isAutomaticQuoteSubstitutionEnabled == false)
        #expect(textView.isAutomaticDashSubstitutionEnabled == false)
        #expect(textView.isAutomaticTextReplacementEnabled == false)
    }

    private func temporaryMarkdownFile(named name: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent(name)
        try "# Test\n".write(to: file, atomically: true, encoding: .utf8)
        return file
    }
}
