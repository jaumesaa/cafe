import AppKit
import QuartzCore

/// Premium window departure: the setup window shrinks and flies upward
/// toward the menu-bar cup, then hands off via `completion` for orderOut / accessory policy.
enum WindowDepartureAnimator {
    static func dismiss(_ window: NSWindow, completion: @escaping () -> Void) {
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            completion()
            return
        }

        guard window.isVisible else {
            completion()
            return
        }

        // Avoid re-entrant animation if Keep Awake is hit twice.
        if window.contentView?.layer?.animation(forKey: Self.animationKey) != nil {
            return
        }

        window.makeFirstResponder(nil)
        window.ignoresMouseEvents = true

        let startFrame = window.frame
        let screen = window.screen ?? NSScreen.main
        let menuBarY: CGFloat = {
            guard let screen else { return startFrame.maxY + 40 }
            return screen.frame.maxY - 2
        }()

        let targetSize = NSSize(width: 26, height: 20)
        let targetFrame = NSRect(
            x: startFrame.midX - targetSize.width * 0.5,
            y: menuBarY - targetSize.height,
            width: targetSize.width,
            height: targetSize.height
        )

        let duration: TimeInterval = 0.45
        let timing = CAMediaTimingFunction(controlPoints: 0.32, 0.00, 0.18, 1.00)

        prepareContentLayer(window: window, duration: duration, timing: timing)

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            context.timingFunction = timing
            context.allowsImplicitAnimation = true
            window.animator().alphaValue = 0.0
            window.animator().setFrame(targetFrame, display: true)
        }, completionHandler: {
            // Hand off FIRST, while the window is still invisible (alpha 0).
            // `completion` orders the window out synchronously, so no restored frame is ever shown.
            completion()

            // Only then restore reusable window state, safely off-screen.
            window.alphaValue = 1.0
            window.setFrame(startFrame, display: false)
            window.ignoresMouseEvents = false
            resetContentLayer(window: window)
        })
    }

    private static let animationKey = "cafe.windowDeparture"

    private static func prepareContentLayer(
        window: NSWindow,
        duration: TimeInterval,
        timing: CAMediaTimingFunction
    ) {
        guard let contentView = window.contentView else { return }
        contentView.wantsLayer = true
        guard let layer = contentView.layer else { return }

        let bounds = layer.bounds
        let previousAnchor = layer.anchorPoint
        layer.setValue(previousAnchor.x, forKey: "cafe.prevAnchorX")
        layer.setValue(previousAnchor.y, forKey: "cafe.prevAnchorY")
        layer.setValue(layer.position.x, forKey: "cafe.prevPosX")
        layer.setValue(layer.position.y, forKey: "cafe.prevPosY")

        // Top-center pivot so the shrink reads as collapsing into the status item.
        layer.anchorPoint = CGPoint(x: 0.5, y: 1.0)
        layer.position = CGPoint(
            x: layer.position.x + (0.5 - previousAnchor.x) * bounds.width,
            y: layer.position.y + (1.0 - previousAnchor.y) * bounds.height
        )

        let scale = CABasicAnimation(keyPath: "transform")
        scale.fromValue = NSValue(caTransform3D: CATransform3DIdentity)
        scale.toValue = NSValue(caTransform3D: CATransform3DConcat(
            CATransform3DMakeScale(0.10, 0.10, 1),
            CATransform3DMakeTranslation(0, 14, 0)
        ))

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1.0
        fade.toValue = 0.0
        fade.beginTime = 0.06
        fade.duration = max(0.01, duration - 0.06)
        fade.fillMode = .both

        let group = CAAnimationGroup()
        group.animations = [scale, fade]
        group.duration = duration
        group.timingFunction = timing
        group.fillMode = .forwards
        group.isRemovedOnCompletion = false

        layer.add(group, forKey: animationKey)
    }

    private static func resetContentLayer(window: NSWindow) {
        guard let layer = window.contentView?.layer else { return }
        layer.removeAnimation(forKey: animationKey)

        let ax = layer.value(forKey: "cafe.prevAnchorX") as? CGFloat ?? 0.5
        let ay = layer.value(forKey: "cafe.prevAnchorY") as? CGFloat ?? 0.5
        let px = layer.value(forKey: "cafe.prevPosX") as? CGFloat ?? layer.position.x
        let py = layer.value(forKey: "cafe.prevPosY") as? CGFloat ?? layer.position.y

        layer.anchorPoint = CGPoint(x: ax, y: ay)
        layer.position = CGPoint(x: px, y: py)
        layer.opacity = 1
        layer.transform = CATransform3DIdentity

        layer.setValue(nil, forKey: "cafe.prevAnchorX")
        layer.setValue(nil, forKey: "cafe.prevAnchorY")
        layer.setValue(nil, forKey: "cafe.prevPosX")
        layer.setValue(nil, forKey: "cafe.prevPosY")
    }
}
