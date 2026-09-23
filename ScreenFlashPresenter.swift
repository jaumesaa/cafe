import AppKit
import QuartzCore

/// Brief, warm full-screen bloom anchored at the menu bar.
/// Masks the window → menu-bar handoff so the departure never shows a restored frame.
@MainActor
enum ScreenFlashPresenter {
    private static var flashWindow: NSWindow?

    static func flash(on screen: NSScreen? = nil) {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        guard let screen = screen ?? NSScreen.main else { return }

        // Never stack blooms if the button is tapped twice in quick succession.
        flashWindow?.orderOut(nil)
        flashWindow = nil

        let frame = screen.frame
        let overlay = ScreenFlashView(frame: NSRect(origin: .zero, size: frame.size))
        overlay.autoresizingMask = [.width, .height]

        let window = NSWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isMovable = false
        window.level = .statusBar
        window.animationBehavior = .none
        // NOTE: no `.transient` here. A transient window is removed when the app
        // deactivates — and we switch to `.accessory` right as the departure ends,
        // which made the flash vanish before it could be seen. Joining all spaces
        // keeps it on screen regardless of activation state.
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        window.contentView = overlay

        flashWindow = window
        window.orderFrontRegardless()

        overlay.play { [weak window] in
            window?.orderOut(nil)
            if flashWindow === window { flashWindow = nil }
        }
    }
}

/// Full-screen layer-backed view holding a single radial amber bloom.
private final class ScreenFlashView: NSView {
    private let bloom = CAGradientLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        guard let host = layer else { return }

        host.masksToBounds = false

        bloom.type = .radial
        bloom.colors = [
            Self.glow(alpha: 0.75),
            Self.glow(alpha: 0.32),
            Self.glow(alpha: 0.0)
        ]
        bloom.locations = [0, 0.35, 1]
        bloom.startPoint = CGPoint(x: 0.5, y: 1.0)   // menu-bar anchor
        bloom.endPoint = CGPoint(x: 0.5, y: 0.0)     // reaches across the height
        bloom.anchorPoint = CGPoint(x: 0.5, y: 1.0)  // scale from the top-center
        bloom.opacity = 0

        host.addSublayer(bloom)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        // Keep the bloom pinned to the top-center of the screen while it scales.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        bloom.bounds = CGRect(origin: .zero, size: bounds.size)
        bloom.position = CGPoint(x: bounds.midX, y: bounds.maxY)
        CATransaction.commit()
    }

    func play(completion: @escaping () -> Void) {
        layoutSubtreeIfNeeded()

        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.values = [0, 1, 1, 0]
        fade.keyTimes = [0, 0.10, 0.32, 1.0]
        fade.timingFunctions = [
            CAMediaTimingFunction(name: .easeIn),
            CAMediaTimingFunction(name: .easeOut),
            CAMediaTimingFunction(name: .easeInEaseOut)
        ]

        let grow = CABasicAnimation(keyPath: "transform.scale")
        grow.fromValue = 0.55
        grow.toValue = 1.2
        grow.timingFunction = CAMediaTimingFunction(name: .easeOut)

        let group = CAAnimationGroup()
        group.animations = [fade, grow]
        group.duration = 0.72
        group.fillMode = .forwards
        group.isRemovedOnCompletion = false

        CATransaction.begin()
        CATransaction.setCompletionBlock(completion)
        bloom.add(group, forKey: "cafe.screenFlash")
        CATransaction.commit()
    }

    private static func glow(alpha: CGFloat) -> CGColor {
        // Matches CafeTheme.glow (0.78, 0.52, 0.24) for a warm, coffee-toned bloom.
        NSColor(srgbRed: 0.78, green: 0.52, blue: 0.24, alpha: alpha).cgColor
    }
}
