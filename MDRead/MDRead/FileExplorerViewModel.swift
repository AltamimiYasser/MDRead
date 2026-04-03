//
//  FileExplorerViewModel.swift
//  MDRead
//
//  Created by Yasser Tamimi on 03/04/2026.
//

import AppKit
import SwiftUI

@Observable
class FileNode: Identifiable {
    let id: URL
    let name: String
    let isDirectory: Bool
    var children: [FileNode]?
    var isExpanded: Bool = false
    var isLoading: Bool = false
    var accessDenied: Bool = false

    init(url: URL, name: String, isDirectory: Bool) {
        self.id = url
        self.name = name
        self.isDirectory = isDirectory
    }
}

@Observable
class FileExplorerViewModel {
    var rootNodes: [FileNode] = []
    private var isBuilt = false

    private static let markdownExtensions: Set<String> = [
        "md", "markdown", "mdown", "mkdn", "mkd", "mdx"
    ]

    func buildRootNodes() {
        guard !isBuilt else { return }
        isBuilt = true

        let fm = FileManager.default
        let rootURL = URL(fileURLWithPath: "/")

        do {
            let contents = try fm.contentsOfDirectory(
                at: rootURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            rootNodes = contents
                .filter { isDirectoryOrMarkdown(url: $0) }
                .sorted { a, b in sortNodes(a: a, b: b) }
                .map { url in
                    let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                    return FileNode(url: url, name: url.lastPathComponent, isDirectory: isDir)
                }
        } catch {
            rootNodes = [FileNode(url: rootURL, name: "/", isDirectory: true)]
        }
    }

    func expandFolder(node: FileNode) {
        guard node.isDirectory, node.children == nil else { return }
        node.isLoading = true

        Task.detached { [weak self] in
            guard let self else { return }
            let children = self.scanDirectory(url: node.id)
            await MainActor.run {
                node.children = children ?? []
                node.isLoading = false
                node.accessDenied = children == nil
            }
        }
    }

    func toggleFolder(node: FileNode) {
        if node.isExpanded {
            node.isExpanded = false
        } else {
            node.isExpanded = true
            if node.children == nil {
                expandFolder(node: node)
            }
        }
    }

    func retryExpand(node: FileNode) {
        node.children = nil
        node.accessDenied = false
        node.isExpanded = true
        expandFolder(node: node)
    }

    func revealFile(url: URL) {
        let components = url.pathComponents
        guard components.count > 1 else { return }

        Task.detached { [weak self] in
            guard let self else { return }
            await self.revealFileAsync(components: components)
        }
    }

    private func revealFileAsync(components: [String]) async {
        var currentNodes = await MainActor.run { rootNodes }

        for i in 1..<components.count {
            let targetName = components[i]
            let isLast = i == components.count - 1

            guard let matchingNode = currentNodes.first(where: { $0.name == targetName }) else {
                return
            }

            if matchingNode.isDirectory && !isLast {
                if matchingNode.children == nil {
                    let children = scanDirectory(url: matchingNode.id) ?? []
                    await MainActor.run {
                        matchingNode.children = children
                        matchingNode.accessDenied = children.isEmpty && scanDirectory(url: matchingNode.id) == nil
                        matchingNode.isExpanded = true
                    }
                } else {
                    await MainActor.run {
                        matchingNode.isExpanded = true
                    }
                }
                currentNodes = await MainActor.run { matchingNode.children ?? [] }
            }
        }
    }

    func refresh() {
        isBuilt = false
        buildRootNodes()
    }

    // MARK: - Private

    private func scanDirectory(url: URL) -> [FileNode]? {
        let fm = FileManager.default
        do {
            let contents = try fm.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )

            return contents
                .filter { isDirectoryOrMarkdown(url: $0) }
                .sorted { a, b in sortNodes(a: a, b: b) }
                .map { childURL in
                    let isDir = (try? childURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                    return FileNode(url: childURL, name: childURL.lastPathComponent, isDirectory: isDir)
                }
        } catch {
            return nil
        }
    }

    private func isDirectoryOrMarkdown(url: URL) -> Bool {
        let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        if isDir { return true }
        return Self.markdownExtensions.contains(url.pathExtension.lowercased())
    }

    private func sortNodes(a: URL, b: URL) -> Bool {
        let aIsDir = (try? a.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        let bIsDir = (try? b.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        if aIsDir != bIsDir { return aIsDir }
        return a.lastPathComponent.localizedStandardCompare(b.lastPathComponent) == .orderedAscending
    }
}
