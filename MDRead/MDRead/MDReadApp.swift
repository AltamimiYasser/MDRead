//
//  MDReadApp.swift
//  MDRead
//
//  Created by Yasser Tamimi on 03/04/2026.
//

import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        // Post a notification so the active ContentView picks it up
        NotificationCenter.default.post(name: .openFileRequest, object: url)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Prevent the default "Open" dialog from appearing
        UserDefaults.standard.set(true, forKey: "NSQuitAlwaysKeepsWindows")
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        return true
    }
}

@main
struct MDReadApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appearanceManager = AppearanceManager()
    @State private var fileExplorerVM = FileExplorerViewModel()
    @State private var bookmarkManager = SandboxBookmarkManager()
    @FocusedBinding(\.fontSize) private var fontSize: Double?
    @FocusedValue(\.printAction) private var printAction
    @FocusedValue(\.exportPDFAction) private var exportPDFAction
    @FocusedValue(\.searchAction) private var searchAction

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appearanceManager)
                .environment(fileExplorerVM)
                .environment(bookmarkManager)
        }
        .commands {
            // File > Open
            CommandGroup(replacing: .newItem) {
                Button("Open...") {
                    // Each ContentView has its own DocumentManager
                    // Use notification to trigger open panel in the active window
                    NotificationCenter.default.post(name: .showOpenPanel, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)
            }

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

            // Window > Close Tabs to the Right
            CommandGroup(after: .windowArrangement) {
                Button("Close Tabs to the Right") {
                    guard let window = NSApp.keyWindow,
                          let tabGroup = window.tabGroup else { return }
                    let allWindows = tabGroup.windows
                    guard let currentIndex = allWindows.firstIndex(of: window) else { return }
                    let tabsToClose = allWindows.suffix(from: allWindows.index(after: currentIndex))
                    for tab in tabsToClose {
                        tab.close()
                    }
                }
                .keyboardShortcut("w", modifiers: [.command, .option, .shift])
            }
        }

        Settings {
            SettingsView()
        }
    }
}

struct SettingsView: View {
    @State private var optionClickBehavior: OptionClickBehavior = {
        let raw = UserDefaults.standard.string(forKey: "optionClickBehavior") ?? "newTab"
        return OptionClickBehavior(rawValue: raw) ?? .newTab
    }()

    var body: some View {
        Form {
            Picker("Option + Click opens file in:", selection: $optionClickBehavior) {
                ForEach(OptionClickBehavior.allCases, id: \.self) { behavior in
                    Text(behavior.label).tag(behavior)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 300)
        }
        .padding(20)
        .frame(width: 400)
        .onChange(of: optionClickBehavior) { _, newValue in
            UserDefaults.standard.set(newValue.rawValue, forKey: "optionClickBehavior")
        }
    }
}
