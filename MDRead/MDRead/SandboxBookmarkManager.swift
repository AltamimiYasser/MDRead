//
//  SandboxBookmarkManager.swift
//  MDRead
//
//  Created by Yasser Tamimi on 03/04/2026.
//

import AppKit
import SwiftUI

@Observable
class SandboxBookmarkManager {
    private(set) var grantedURLs: [URL] = []
    private let bookmarksKey = "grantedFolderBookmarks"

    init() {
        restoreBookmarks()
    }

    func grantAccess() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/")
        panel.message = "Select a folder to grant MDRead read access"
        panel.prompt = "Grant Access"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        // Check if already granted
        if grantedURLs.contains(where: { $0.path == url.path }) { return }

        // Create security-scoped bookmark
        do {
            let bookmarkData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            var bookmarks = loadBookmarkData()
            bookmarks.append(bookmarkData)
            UserDefaults.standard.set(bookmarks, forKey: bookmarksKey)

            _ = url.startAccessingSecurityScopedResource()
            grantedURLs.append(url)
        } catch {
            // Silently fail — user can try again
        }
    }

    func grantAccessTo(url: URL) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = url
        panel.message = "Select this folder to grant MDRead read access"
        panel.prompt = "Grant Access"

        guard panel.runModal() == .OK, let selectedURL = panel.url else { return }

        if grantedURLs.contains(where: { $0.path == selectedURL.path }) { return }

        do {
            let bookmarkData = try selectedURL.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            var bookmarks = loadBookmarkData()
            bookmarks.append(bookmarkData)
            UserDefaults.standard.set(bookmarks, forKey: bookmarksKey)

            _ = selectedURL.startAccessingSecurityScopedResource()
            grantedURLs.append(selectedURL)
        } catch {}
    }

    func revokeAccess(url: URL) {
        url.stopAccessingSecurityScopedResource()
        grantedURLs.removeAll { $0.path == url.path }

        // Remove from stored bookmarks by re-resolving all and keeping the rest
        var bookmarks = loadBookmarkData()
        bookmarks.removeAll { data in
            var isStale = false
            guard let resolved = try? URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) else { return false }
            return resolved.path == url.path
        }
        UserDefaults.standard.set(bookmarks, forKey: bookmarksKey)
    }

    private func restoreBookmarks() {
        let bookmarks = loadBookmarkData()
        var validBookmarks: [Data] = []

        for data in bookmarks {
            var isStale = false
            guard let url = try? URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) else { continue }

            if isStale {
                // Try to recreate the bookmark
                if let newData = try? url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                ) {
                    validBookmarks.append(newData)
                }
            } else {
                validBookmarks.append(data)
            }

            _ = url.startAccessingSecurityScopedResource()
            grantedURLs.append(url)
        }

        UserDefaults.standard.set(validBookmarks, forKey: bookmarksKey)
    }

    private func loadBookmarkData() -> [Data] {
        UserDefaults.standard.array(forKey: bookmarksKey) as? [Data] ?? []
    }
}
