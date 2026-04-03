//
//  TableOfContentsView.swift
//  MDRead
//
//  Created by Yasser Tamimi on 03/04/2026.
//

import SwiftUI

struct TableOfContentsView: View {
    let items: [TOCItem]
    var onSelect: (TOCItem) -> Void

    var body: some View {
        List {
            ForEach(items) { item in
                Button {
                    onSelect(item)
                } label: {
                    Text(item.text)
                        .lineLimit(2)
                        .font(fontForLevel(item.level))
                        .foregroundStyle(item.level <= 2 ? .primary : .secondary)
                }
                .buttonStyle(.plain)
                .padding(.leading, indentation(for: item.level))
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 250, idealWidth: 280)
    }

    private func indentation(for level: Int) -> CGFloat {
        CGFloat(max(0, level - 1)) * 12
    }

    private func fontForLevel(_ level: Int) -> Font {
        switch level {
        case 1: .headline
        case 2: .subheadline
        default: .body
        }
    }
}
