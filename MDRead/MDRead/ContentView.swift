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

                    if isLoading {
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
        .navigationTitle(documentManager.currentFileURL?.lastPathComponent ?? "MDRead")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
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
        .background(WindowAccessor())
        .focusedValue(\.fontSize, $fontSize)
        .focusedValue(\.printAction, { documentManager.printDocument(webView: webView) })
        .focusedValue(\.exportPDFAction, { documentManager.exportPDF(webView: webView) })
        .focusedValue(\.searchAction, { isSearchFocused = true })
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
