//
//  MDReadApp.swift
//  MDRead
//
//  Created by Yasser Tamimi on 03/04/2026.
//

import SwiftUI

@main
struct MDReadApp: App {
    @State private var appearanceManager = AppearanceManager()
    @FocusedBinding(\.fontSize) private var fontSize: Double?
    @FocusedValue(\.printAction) private var printAction
    @FocusedValue(\.exportPDFAction) private var exportPDFAction
    @FocusedValue(\.searchAction) private var searchAction

    var body: some Scene {
        DocumentGroup(viewing: MDReadDocument.self) { file in
            ContentView(document: file.document)
                .environment(appearanceManager)
        }
        .commands {
            // Font size commands
            CommandGroup(after: .toolbar) {
                Button("Zoom In") {
                    if let fontSize, fontSize < 30 {
                        self.fontSize = fontSize + 1
                    }
                }
                .keyboardShortcut("+", modifiers: .command)

                Button("Zoom Out") {
                    if let fontSize, fontSize > 10 {
                        self.fontSize = fontSize - 1
                    }
                }
                .keyboardShortcut("-", modifiers: .command)

                Button("Reset Zoom") {
                    fontSize = 14
                }
                .keyboardShortcut("0", modifiers: .command)
            }

            // Find
            CommandGroup(replacing: .textEditing) {
                Button("Find...") {
                    searchAction?()
                }
                .keyboardShortcut("f", modifiers: .command)
                .disabled(searchAction == nil)
            }

            // Print / Export
            CommandGroup(replacing: .printItem) {
                Button("Print...") {
                    printAction?()
                }
                .keyboardShortcut("p", modifiers: .command)
                .disabled(printAction == nil)

                Button("Export as PDF...") {
                    exportPDFAction?()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(exportPDFAction == nil)
            }
        }
    }
}
