//
//  MDReadTests.swift
//  MDReadTests
//
//  Created by Yasser Tamimi on 03/04/2026.
//

import Testing
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

    private func temporaryMarkdownFile(named name: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent(name)
        try "# Test\n".write(to: file, atomically: true, encoding: .utf8)
        return file
    }
}
