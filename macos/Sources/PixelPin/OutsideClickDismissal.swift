import AppKit
import SwiftUI

struct OutsideClickDismissal: NSViewRepresentable {
    let dismiss: () -> Void

    func makeNSView(context: Context) -> DismissalView {
        let view = DismissalView()
        view.dismiss = dismiss
        return view
    }

    func updateNSView(_ view: DismissalView, context: Context) { view.dismiss = dismiss }
    static func dismantleNSView(_ view: DismissalView, coordinator: ()) { view.stopMonitoring() }

    final class DismissalView: NSView {
        var dismiss: (() -> Void)?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard window != nil, monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                guard let self else { return event }
                // Native picker menus belong to a separate menu window.
                guard let eventWindow = event.window,
                      eventWindow.level.rawValue < NSWindow.Level.popUpMenu.rawValue else { return event }
                if event.window !== self.window || !self.bounds.contains(self.convert(event.locationInWindow, from: nil)) {
                    // Defer until the clicked control finishes (including the toolbar gear).
                    DispatchQueue.main.async { [weak self] in self?.dismiss?() }
                }
                return event
            }
        }

        func stopMonitoring() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }

        deinit { if let monitor { NSEvent.removeMonitor(monitor) } }
    }
}
