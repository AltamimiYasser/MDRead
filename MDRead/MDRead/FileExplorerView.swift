//
//  FileExplorerView.swift
//  MDRead
//
//  Created by Yasser Tamimi on 03/04/2026.
//

import SwiftUI

struct FileExplorerView: View {
    @Environment(FileExplorerViewModel.self) private var viewModel
    @Environment(SandboxBookmarkManager.self) private var bookmarkManager
    @Environment(DocumentManager.self) private var documentManager
    var currentFileURL: URL?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(viewModel.rootNodes) { node in
                        FileNodeRow(node: node, depth: 0, currentFileURL: currentFileURL)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 8)
            }
            .onChange(of: currentFileURL) { _, newURL in
                if let newURL {
                    viewModel.revealFile(url: newURL)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation {
                            proxy.scrollTo(newURL, anchor: .center)
                        }
                    }
                }
            }
        }
        .frame(minWidth: 250, idealWidth: 280)
        .onAppear {
            viewModel.buildRootNodes()
            if let currentFileURL {
                viewModel.revealFile(url: currentFileURL)
            }
        }
    }
}

struct FileNodeRow: View {
    @Bindable var node: FileNode
    let depth: Int
    var currentFileURL: URL?
    @Environment(FileExplorerViewModel.self) private var viewModel
    @Environment(SandboxBookmarkManager.self) private var bookmarkManager
    @Environment(DocumentManager.self) private var documentManager
    @State private var isHovered = false
    @State private var flashActive = false

    private var isCurrentFile: Bool {
        !node.isDirectory && node.id == currentFileURL
    }

    /// True when this is a collapsed folder that contains the current file somewhere inside
    private var containsCurrentFile: Bool {
        guard node.isDirectory, !node.isExpanded, let currentFileURL else { return false }
        return currentFileURL.path.hasPrefix(node.id.path + "/")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                if node.isDirectory {
                    viewModel.toggleFolder(node: node)
                } else {
                    // Check for Option key
                    if NSEvent.modifierFlags.contains(.option) {
                        documentManager.handleOptionClick(url: node.id)
                    } else {
                        flashActive = true
                        documentManager.openFile(url: node.id)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            flashActive = false
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    if node.isDirectory {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .rotationEffect(.degrees(node.isExpanded ? 90 : 0))
                            .animation(.easeInOut(duration: 0.15), value: node.isExpanded)
                            .frame(width: 14)
                    } else {
                        Spacer().frame(width: 14)
                    }

                    Image(systemName: node.isDirectory
                          ? (node.isExpanded ? "folder.fill" : "folder")
                          : "doc.text")
                        .foregroundStyle(node.isDirectory
                                         ? (node.accessDenied ? .gray : (containsCurrentFile ? Color.accentColor : .blue))
                                         : (isCurrentFile ? Color.accentColor : .secondary))
                        .font(.system(size: 13))
                        .frame(width: 18)

                    Text(node.name)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .font(.system(size: 13))
                        .foregroundColor(node.accessDenied ? .gray : ((isCurrentFile || containsCurrentFile) ? .accentColor : .primary))
                        .opacity(node.accessDenied ? 0.4 : 1.0)
                        .fontWeight((isCurrentFile || containsCurrentFile) ? .semibold : .regular)

                    Spacer()

                    // Dot indicator for collapsed folder containing current file
                    if containsCurrentFile {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 6, height: 6)
                    }

                    if node.isLoading {
                        ProgressView()
                            .controlSize(.mini)
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                .padding(.leading, CGFloat(depth) * 16)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(backgroundColor)
                )
                .scaleEffect(flashActive ? 0.98 : 1.0)
                .animation(.easeOut(duration: 0.1), value: flashActive)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isHovered = hovering
            }
            .id(node.id)
            .contextMenu {
                if node.isDirectory {
                    folderContextMenu
                } else {
                    fileContextMenu
                }
            }

            // Children
            if node.isExpanded {
                if let children = node.children {
                    if children.isEmpty {
                        if node.accessDenied {
                            Button {
                                bookmarkManager.grantAccessTo(url: node.id)
                                viewModel.retryExpand(node: node)
                            } label: {
                                Label("Grant Access", systemImage: "lock.open")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, CGFloat(depth + 1) * 16 + 24)
                            .padding(.vertical, 4)
                        } else {
                            Text("Empty")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                                .padding(.leading, CGFloat(depth + 1) * 16 + 24)
                                .padding(.vertical, 2)
                        }
                    } else {
                        ForEach(children) { child in
                            FileNodeRow(node: child, depth: depth + 1, currentFileURL: currentFileURL)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Context Menus

    @ViewBuilder
    private var fileContextMenu: some View {
        Button("Open") {
            documentManager.openFile(url: node.id)
        }
        Button("Open in New Tab") {
            documentManager.openFileInNewTab(url: node.id)
        }
        Button("Open in New Window") {
            documentManager.openFileInNewWindow(url: node.id)
        }

        Divider()

        Button("Reveal in Finder") {
            DocumentManager.revealInFinder(url: node.id)
        }
        Button("Export to PDF...") {
            DocumentManager.exportFileToPDF(fileURL: node.id)
        }

        Divider()

        Button("Copy Path") {
            DocumentManager.copyPath(url: node.id)
        }
        Button("Copy as Markdown Link") {
            DocumentManager.copyAsMarkdownLink(url: node.id)
        }
    }

    @ViewBuilder
    private var folderContextMenu: some View {
        Button("Reveal in Finder") {
            DocumentManager.revealInFinder(url: node.id)
        }

        Divider()

        Button("Copy Path") {
            DocumentManager.copyPath(url: node.id)
        }

        if node.isExpanded {
            Divider()
            Button("Collapse") {
                node.isExpanded = false
            }
        }
    }

    private var backgroundColor: Color {
        if flashActive {
            return Color.accentColor.opacity(0.15)
        } else if isCurrentFile {
            return Color.accentColor.opacity(0.1)
        } else if isHovered {
            return Color.primary.opacity(0.06)
        }
        return .clear
    }
}
