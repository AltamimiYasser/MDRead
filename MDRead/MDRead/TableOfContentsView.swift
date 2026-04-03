//
//  TableOfContentsView.swift
//  MDRead
//
//  Created by Yasser Tamimi on 03/04/2026.
//

import SwiftUI

struct TableOfContentsView: View {
    let items: [TOCItem]
    var activeHeadingId: String?
    var onSelect: (TOCItem) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(items) { item in
                        TOCRow(
                            item: item,
                            isActive: item.id == activeHeadingId,
                            indentation: indentation(for: item.level),
                            font: fontForLevel(item.level),
                            onSelect: { onSelect(item) }
                        )
                        .id(item.id)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
            }
            .onChange(of: activeHeadingId) { _, newId in
                if let newId {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(newId, anchor: .center)
                    }
                }
            }
        }
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

struct TOCRow: View {
    let item: TOCItem
    let isActive: Bool
    let indentation: CGFloat
    let font: Font
    let onSelect: () -> Void

    @State private var isHovered = false
    @State private var flashActive = false

    var body: some View {
        Button {
            flashActive = true
            onSelect()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                flashActive = false
            }
        } label: {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(isActive ? Color.accentColor : .clear)
                    .frame(width: 3, height: 20)
                    .animation(.easeInOut(duration: 0.2), value: isActive)

                Text(item.text)
                    .lineLimit(2)
                    .font(font)
                    .foregroundStyle(isActive ? Color.accentColor : (item.level <= 2 ? .primary : .secondary))
                    .fontWeight(isActive ? .semibold : .regular)

                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(backgroundColor)
                    .animation(.easeInOut(duration: 0.15), value: isHovered)
                    .animation(.easeInOut(duration: 0.15), value: isActive)
                    .animation(.easeInOut(duration: 0.1), value: flashActive)
            )
            .scaleEffect(flashActive ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.1), value: flashActive)
        }
        .buttonStyle(.plain)
        .padding(.leading, indentation)
        .onHover { hovering in
            isHovered = hovering
        }
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private var backgroundColor: Color {
        if flashActive {
            return Color.accentColor.opacity(0.2)
        } else if isActive {
            return Color.accentColor.opacity(0.1)
        } else if isHovered {
            return Color.primary.opacity(0.06)
        }
        return .clear
    }
}
