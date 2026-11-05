import AppKit
import SwiftUI

struct PickerWindowLayout: Equatable {
    let miniMode: Bool
    let settingsOpen: Bool
    let workArea: CGRect

    // Settings temporarily use the full window; the saved mini preference stays intact.
    var isMini: Bool { miniMode && !settingsOpen }
    var contentSize: CGSize {
        CGSize(width: isMini ? 320 : 410, height: isMini ? 132 : min(720, max(320, workArea.height - 80)))
    }

    func windowFrame(from current: CGRect, chromeHeight: CGFloat) -> CGRect {
        let size = CGSize(width: contentSize.width, height: contentSize.height + chromeHeight)
        return CGRect(x: min(max(current.minX, workArea.minX), max(workArea.minX, workArea.maxX - size.width)),
                      y: min(max(current.maxY - size.height, workArea.minY), max(workArea.minY, workArea.maxY - size.height)),
                      width: size.width, height: size.height)
    }
}

struct PickerWindowLayoutConfigurator: NSViewRepresentable {
    let layout: PickerWindowLayout

    func makeNSView(context: Context) -> LayoutView {
        let view = LayoutView()
        view.configure(layout)
        return view
    }

    func updateNSView(_ view: LayoutView, context: Context) { view.configure(layout) }

    final class LayoutView: NSView {
        private var layout: PickerWindowLayout?
        private var appliedLayout: PickerWindowLayout?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            appliedLayout = nil
            apply()
        }

        func configure(_ value: PickerWindowLayout) {
            layout = value
            apply()
        }

        private func apply() {
            guard let layout, layout != appliedLayout, let window else { return }
            let previousFrame = window.frame
            appliedLayout = layout
            // Let SwiftUI update the content-size constraints before changing the native frame.
            DispatchQueue.main.async { [weak self, weak window] in
                guard let self, let window, self.layout == layout, self.window === window else { return }
                let chromeHeight = max(0, window.frame.height - window.contentLayoutRect.height)
                window.setFrame(layout.windowFrame(from: previousFrame, chromeHeight: chromeHeight), display: true)
            }
        }
    }
}
