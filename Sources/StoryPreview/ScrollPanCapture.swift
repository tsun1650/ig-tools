import SwiftUI
import AppKit

/// Observes scroll events only over the editor canvas, leaving SwiftUI's drag
/// and magnification gestures, and the inspector's scrolling, untouched.
struct ScrollPanCapture: NSViewRepresentable {
    var onPan: (CGSize) -> Void

    func makeNSView(context: Context) -> ScrollPanView {
        let view = ScrollPanView()
        view.onPan = onPan
        return view
    }

    func updateNSView(_ view: ScrollPanView, context: Context) {
        view.onPan = onPan
    }

    static func dismantleNSView(_ view: ScrollPanView, coordinator: ()) {
        view.stopMonitoring()
    }
}

final class ScrollPanView: NSView {
    var onPan: ((CGSize) -> Void)?
    private var monitor: Any?

    // This background view must not intercept clicks, dragging, or pinching.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        stopMonitoring()
        guard window != nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self, let window = self.window,
                  event.window === window, !self.isHiddenOrHasHiddenAncestor,
                  self.visibleRect.contains(self.convert(event.locationInWindow, from: nil)),
                  !event.modifierFlags.contains(.control),
                  !event.modifierFlags.contains(.command) else { return event }
            // AppKit already applies the user's natural-scrolling preference.
            // Precise deltas are points; traditional wheel ticks need scaling.
            let scale: CGFloat = event.hasPreciseScrollingDeltas ? 1 : 10
            self.onPan?(CGSize(width: event.scrollingDeltaX * scale,
                               height: event.scrollingDeltaY * scale))
            return nil
        }
    }

    func stopMonitoring() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}
