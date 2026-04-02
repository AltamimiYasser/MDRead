//
//  WindowAccessor.swift
//  MDRead
//
//  Created by Yasser Tamimi on 03/04/2026.
//

import SwiftUI

struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            view.window?.setFrameAutosaveName("MDReadWindow")
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
