import AppKit
import SwiftUI

enum WindowCloseBehavior: String, CaseIterable, Identifiable {
    case minimize, quit
    var id: String { rawValue }

    func text(_ language: AppLanguage) -> String {
        switch self {
        case .minimize: return language.text("Dock으로 최소화", "Minimize to Dock", "最小化到程序坞")
        case .quit: return language.text("앱 완전히 종료", "Quit Pixel Pin", "退出 Pixel Pin")
        }
    }
}

struct WindowCloseBehaviorHandler: NSViewRepresentable {
    let behavior: WindowCloseBehavior

    func makeNSView(context: Context) -> CloseBehaviorView {
        let view = CloseBehaviorView()
        view.behavior = behavior
        return view
    }

    func updateNSView(_ view: CloseBehaviorView, context: Context) { view.behavior = behavior }
    static func dismantleNSView(_ view: CloseBehaviorView, coordinator: ()) { view.detach() }

    final class CloseBehaviorView: NSView, NSWindowDelegate {
        var behavior: WindowCloseBehavior = .minimize
        private weak var attachedWindow: NSWindow?
        private var previousDelegate: NSWindowDelegate?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard attachedWindow !== window else { return }
            detach()
            guard let window else { return }
            attachedWindow = window
            previousDelegate = window.delegate
            window.delegate = self
        }

        func windowShouldClose(_ sender: NSWindow) -> Bool {
            switch behavior {
            case .minimize: sender.miniaturize(nil)
            case .quit: NSApp.terminate(nil)
            }
            return false
        }

        // Preserve SwiftUI's other window lifecycle and restoration callbacks.
        override func responds(to selector: Selector!) -> Bool {
            super.responds(to: selector) || previousDelegate?.responds(to: selector) == true
        }

        override func forwardingTarget(for selector: Selector!) -> Any? {
            if previousDelegate?.responds(to: selector) == true { return previousDelegate }
            return super.forwardingTarget(for: selector)
        }

        func detach() {
            if let attachedWindow, attachedWindow.delegate === self { attachedWindow.delegate = previousDelegate }
            attachedWindow = nil
            previousDelegate = nil
        }
    }
}
