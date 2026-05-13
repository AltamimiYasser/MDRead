//
//  MarkdownSourceEditor.swift
//  MDRead
//
//  Created by Codex on 12/05/2026.
//

import AppKit
import SwiftUI

struct MarkdownSourceEditor: NSViewRepresentable {
    @Binding var text: String
    var fontSize: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false

        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        Self.configure(textView, fontSize: fontSize)
        textView.delegate = context.coordinator
        textView.string = text
        textView.undoManager?.removeAllActions()

        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.text = $text
        guard let textView = scrollView.documentView as? NSTextView else { return }

        Self.configure(textView, fontSize: fontSize)
        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges.filter { rangeValue in
                NSMaxRange(rangeValue.rangeValue) <= text.utf16.count
            }
            textView.undoManager?.removeAllActions()
        }
    }

    static func configure(_ textView: NSTextView, fontSize: CGFloat) {
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.usesFindBar = true
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.textColor = .labelColor
        textView.textContainerInset = NSSize(width: 18, height: 18)
        textView.textContainer?.widthTracksTextView = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        nonisolated func textDidChange(_ notification: Notification) {
            MainActor.assumeIsolated {
                guard let textView = notification.object as? NSTextView else { return }
                if text.wrappedValue != textView.string {
                    text.wrappedValue = textView.string
                }
            }
        }
    }
}
