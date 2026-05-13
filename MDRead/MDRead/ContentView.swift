//
//  ContentView.swift
//  MDRead
//
//  Created by Yasser Tamimi on 03/04/2026.
//

import SwiftUI
import UniformTypeIdentifiers
import WebKit

struct ContentView: View {
    @Environment(AppearanceManager.self) private var appearance
    @State private var documentManager = DocumentManager()
    @State private var fontSize: Double = {
        let saved = UserDefaults.standard.double(forKey: "fontSize")
        return saved > 0 ? saved : 14
    }()
    @State private var tocItems: [TOCItem] = []
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var activeHeadingId: String?
    @State private var webView: WKWebView?
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        NavigationSplitView {
            SidebarContainerView(
                tocItems: tocItems,
                activeHeadingId: activeHeadingId,
                currentFileURL: documentManager.currentFileURL,
                onSelectHeading: { scrollToHeading($0) }
            )
            .navigationSplitViewColumnWidth(min: 250, ideal: 300, max: 450)
        } detail: {
            ZStack {
                if documentManager.currentFileURL != nil {
                    if documentManager.isEditing {
                        MarkdownSourceEditor(
                            text: Bindable(documentManager).draftText,
                            fontSize: CGFloat(fontSize)
                        )
                        .frame(minWidth: 500, minHeight: 400)
                    } else {
                        MarkdownWebView(
                            markdown: documentManager.documentText,
                            theme: appearance.mode.cssValue,
                            fontSize: CGFloat(fontSize),
                            searchText: searchText,
                            onTOCUpdate: { items in
                                tocItems = items
                            },
                            onActiveHeadingChange: { headingId in
                                activeHeadingId = headingId
                            },
                            onLoadComplete: {
                                isLoading = false
                            },
                            onWebViewReady: { wv in
                                webView = wv
                                documentManager.webView = wv
                            }
                        )
                        .frame(minWidth: 500, minHeight: 400)
                    }

                    if isLoading && !documentManager.isEditing {
                        ProgressView()
                            .controlSize(.large)
                    }
                } else {
                    ContentUnavailableView(
                        "No Document Open",
                        systemImage: "doc.text",
                        description: Text("Open a Markdown file from the sidebar or use File > Open.")
                    )
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search in document")
        .searchFocused($isSearchFocused)
        .navigationTitle(windowTitle)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Toggle(isOn: Binding(
                    get: { documentManager.isEditing },
                    set: { newValue in
                        if newValue {
                            documentManager.beginEditing()
                        } else {
                            _ = documentManager.requestEndEditing()
                        }
                    }
                )) {
                    Label("Edit", systemImage: "square.and.pencil")
                }
                .toggleStyle(.button)
                .disabled(documentManager.currentFileURL == nil)
                .help("Edit Markdown source")

                if documentManager.isEditing {
                    Button {
                        _ = documentManager.saveDraft()
                    } label: {
                        Label("Save", systemImage: "square.and.arrow.down")
                    }
                    .disabled(!documentManager.hasUnsavedChanges)
                    .help("Save Markdown file")
                }

                Picker("Appearance", selection: Bindable(appearance).mode) {
                    ForEach(AppearanceManager.Mode.allCases, id: \.self) { mode in
                        Label(mode.label, systemImage: mode.icon)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
            }
        }
        .preferredColorScheme(appearance.mode.colorScheme)
        .background(WindowAccessor(onWindowClose: {
            documentManager.windowDidClose()
        }))
        .focusedValue(\.fontSize, $fontSize)
        .focusedValue(\.printAction, { documentManager.printDocument(webView: webView) })
        .focusedValue(\.exportPDFAction, { documentManager.exportPDF(webView: webView) })
        .focusedValue(\.searchAction, { isSearchFocused = true })
        .focusedValue(\.saveAction, { documentManager.saveDraft() })
        .focusedValue(\.canSaveDocument, documentManager.hasUnsavedChanges)
        .onChange(of: fontSize) { _, newValue in
            UserDefaults.standard.set(newValue, forKey: "fontSize")
        }
        .onChange(of: documentManager.documentText) {
            isLoading = true
            tocItems = []
            activeHeadingId = nil
        }
        .onAppear {
            documentManager.loadInitialState()
        }
        .onReceive(NotificationCenter.default.publisher(for: .loadInitialStateRequest)) { _ in
            documentManager.loadInitialState()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openFileRequest)) { notification in
            if let url = notification.object as? URL {
                documentManager.openFile(url: url)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showOpenPanel)) { _ in
            documentManager.showOpenPanel()
        }
        .environment(documentManager)
    }

    private var windowTitle: String {
        let title = documentManager.currentFileURL?.lastPathComponent ?? "MDRead"
        return documentManager.hasUnsavedChanges ? "\(title) *" : title
    }

    private func scrollToHeading(_ item: TOCItem) {
        webView?.evaluateJavaScript(
            "document.getElementById('\(item.id)').scrollIntoView({behavior: 'smooth', block: 'start'})"
        )
    }
}

#Preview {
    ContentView()
        .environment(AppearanceManager())
        .environment(FileExplorerViewModel())
        .environment(SandboxBookmarkManager())
}
