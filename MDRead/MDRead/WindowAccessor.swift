//
//  WindowAccessor.swift
//  MDRead
//
//  Created by Yasser Tamimi on 03/04/2026.
//

import SwiftUI

struct WindowAccessor: NSViewRepresentable {
    var onWindowClose: () -> Void = {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onWindowClose: onWindowClose)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            context.coordinator.attach(to: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onWindowClose = onWindowClose
        DispatchQueue.main.async {
            context.coordinator.attach(to: nsView.window)
        }
    }

    class Coordinator {
        var onWindowClose: () -> Void
        private weak var observedWindow: NSWindow?
        private var willCloseObserver: NSObjectProtocol?

        init(onWindowClose: @escaping () -> Void) {
            self.onWindowClose = onWindowClose
        }

        deinit {
            if let willCloseObserver {
                NotificationCenter.default.removeObserver(willCloseObserver)
            }
        }

        func attach(to window: NSWindow?) {
            guard let window, observedWindow !== window else { return }

            if let willCloseObserver {
                NotificationCenter.default.removeObserver(willCloseObserver)
            }

            observedWindow = window
            window.setFrameAutosaveName("MDReadWindow")
            willCloseObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                self?.onWindowClose()
            }
        }
    }
}
