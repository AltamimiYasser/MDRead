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
    let document: MDReadDocument
    @Environment(AppearanceManager.self) private var appearance
    @State private var fontSize: Double = {
        let saved = UserDefaults.standard.double(forKey: "fontSize")
        return saved > 0 ? saved : 14
    }()
    @State private var tocItems: [TOCItem] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var webView: WKWebView?
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        NavigationSplitView {
            if tocItems.isEmpty {
                ContentUnavailableView("No Headings", systemImage: "list.bullet", description: Text("This document has no headings."))
            } else {
                TableOfContentsView(items: tocItems) { item in
                    scrollToHeading(item)
                }
            }
        } detail: {
            ZStack {
                MarkdownWebView(
                    markdown: document.text,
                    theme: appearance.mode.cssValue,
                    fontSize: CGFloat(fontSize),
                    searchText: searchText,
                    onTOCUpdate: { items in
                        tocItems = items
                    },
                    onLoadComplete: {
                        isLoading = false
                    },
                    onWebViewReady: { wv in
                        webView = wv
                    }
                )
                .frame(minWidth: 500, minHeight: 400)

                if isLoading {
                    ProgressView()
                        .controlSize(.large)
                }
            }
        }
        .navigationSplitViewColumnWidth(min: 220, ideal: 280, max: 400)
        .searchable(text: $searchText, prompt: "Search in document")
        .searchFocused($isSearchFocused)
        .navigationTitle("")
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
        .focusedValue(\.printAction, printDocument)
        .focusedValue(\.exportPDFAction, exportPDF)
        .focusedValue(\.searchAction, { isSearchFocused = true })
        .onChange(of: fontSize) { _, newValue in
            UserDefaults.standard.set(newValue, forKey: "fontSize")
        }
        .onChange(of: document.text) {
            isLoading = true
        }
    }

    private func scrollToHeading(_ item: TOCItem) {
        webView?.evaluateJavaScript(
            "document.getElementById('\(item.id)').scrollIntoView({behavior: 'smooth', block: 'start'})"
        )
    }

    private func printDocument() {
        guard let webView else { return }
        let printInfo = NSPrintInfo.shared
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        let printOp = webView.printOperation(with: printInfo)
        printOp.showsPrintPanel = true
        printOp.showsProgressPanel = true
        printOp.run()
    }

    private func exportPDF() {
        guard let webView else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "document.pdf"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            webView.createPDF { result in
                if case .success(let data) = result {
                    try? data.write(to: url)
                }
            }
        }
    }
}

#Preview {
    ContentView(document: MDReadDocument(text: """
    # Hello MDRead

    This is a **Markdown** reader app.

    ## Code Example

    ```swift
    let greeting = "Hello, World!"
    print(greeting)
    ```

    ## Features

    - Item one
    - Item two
    - Item three

    > A blockquote for testing

    [Link example](https://example.com)
    """))
    .environment(AppearanceManager())
}
