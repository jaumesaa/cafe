import AppKit

/// Native menu-bar status item shown only while caffeinate is active.
@MainActor
final class StatusItemController: NSObject {
    var onStop: (() -> Void)?

    private var statusItem: NSStatusItem?
    private let renderer = CupStatusIconRenderer()
    private var menu: NSMenu?
    private var remainingItem: NSMenuItem?
    private var animationTimer: Timer?
    private var phase: CGFloat = 0
    private var currentFill: Double = 1
    private var showSmoke: Bool = true

    /// Smoothly interpolated 0…1 value that drives both the smoke fade and the cup scale.
    private var smokeProgress: CGFloat = 0

    func show(fillLevel: Double, showSmoke: Bool, remainingText: String, isUnlimited: Bool) {
        if statusItem == nil {
            let item = NSStatusBar.system.statusItem(withLength: 24)
            item.button?.imagePosition = .imageOnly
            item.button?.toolTip = "cafe — keep awake"
            statusItem = item
            buildMenu()
            item.menu = menu
            startAnimation()
        }
        // Appear already settled in the correct state; only later changes animate.
        self.showSmoke = showSmoke
        smokeProgress = showSmoke ? 1 : 0
        update(fillLevel: fillLevel, showSmoke: showSmoke, remainingText: remainingText, isUnlimited: isUnlimited)
    }

    func update(fillLevel: Double, showSmoke: Bool, remainingText: String, isUnlimited: Bool) {
        currentFill = fillLevel
        self.showSmoke = showSmoke
        remainingItem?.title = isUnlimited ? "Remaining: Unlimited" : "Remaining: \(remainingText)"
        redraw()
    }

    func hide() {
        animationTimer?.invalidate()
        animationTimer = nil
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
        menu = nil
        remainingItem = nil
        smokeProgress = 0
    }

    private func startAnimation() {
        animationTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.phase += 0.08
                self.advanceSmoke()
                self.redraw()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        animationTimer = timer
    }

    /// Eases `smokeProgress` toward its target each frame — snappy but fluid.
    private func advanceSmoke() {
        let target: CGFloat = showSmoke ? 1 : 0
        let delta = target - smokeProgress
        if abs(delta) < 0.002 {
            smokeProgress = target
        } else {
            smokeProgress += delta * 0.14
        }
    }

    private func redraw() {
        guard let button = statusItem?.button else { return }
        let image = renderer.image(
            size: NSSize(width: 22, height: 22),
            fillLevel: currentFill,
            smokeProgress: smokeProgress,
            phase: phase
        )
        button.image = image
    }

    private func buildMenu() {
        let menu = NSMenu()
        let remaining = NSMenuItem(title: "Remaining: —", action: nil, keyEquivalent: "")
        remaining.isEnabled = false
        remainingItem = remaining
        menu.addItem(remaining)
        menu.addItem(.separator())

        // Spotlight is the reopen path — menu is for remaining time + Stop only.
        let stop = NSMenuItem(title: "Stop", action: #selector(stopAction), keyEquivalent: ".")
        stop.target = self
        menu.addItem(stop)

        self.menu = menu
    }

    @objc private func stopAction() {
        onStop?()
    }
}
