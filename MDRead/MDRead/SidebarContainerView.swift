//
//  SidebarContainerView.swift
//  MDRead
//
//  Created by Yasser Tamimi on 03/04/2026.
//

import SwiftUI

enum SidebarTab: String, CaseIterable {
    case tableOfContents
    case files

    var label: String {
        switch self {
        case .tableOfContents: "Headings"
        case .files: "Files"
        }
    }

    var icon: String {
        switch self {
        case .tableOfContents: "list.bullet"
        case .files: "folder"
        }
    }
}

struct SidebarContainerView: View {
    @State private var selectedTab: SidebarTab = {
        let saved = UserDefaults.standard.string(forKey: "sidebarTab")
        return SidebarTab(rawValue: saved ?? "") ?? .tableOfContents
    }()

    let tocItems: [TOCItem]
    var activeHeadingId: String?
    var currentFileURL: URL?
    var onSelectHeading: (TOCItem) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Picker(selection: $selectedTab) {
                ForEach(SidebarTab.allCases, id: \.self) { tab in
                    Text(tab.label).tag(tab)
                }
            } label: {
                EmptyView()
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            switch selectedTab {
            case .tableOfContents:
                if tocItems.isEmpty {
                    ContentUnavailableView(
                        "No Headings",
                        systemImage: "list.bullet",
                        description: Text("This document has no headings.")
                    )
                } else {
                    TableOfContentsView(
                        items: tocItems,
                        activeHeadingId: activeHeadingId,
                        onSelect: onSelectHeading
                    )
                }

            case .files:
                FileExplorerView(currentFileURL: currentFileURL)
            }
        }
        .onChange(of: selectedTab) { _, newValue in
            UserDefaults.standard.set(newValue.rawValue, forKey: "sidebarTab")
        }
    }
}
