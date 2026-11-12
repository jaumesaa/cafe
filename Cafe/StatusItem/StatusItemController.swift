import AppKit
import QuartzCore

/// Native menu-bar status item shown only while caffeinate is active.
///
/// Redrawing a status item is expensive: every new image is laid out, rasterised and
/// shipped to the process that hosts the menu bar. So the icon is only redrawn when
/// what it shows actually changes, and the idle steam/liquid motion runs at a low
/// frame rate from a single timer that stops whenever the menu bar is not on screen.
@MainActor
final class StatusItemController: NSObject {
    var onStop: (() -> Void)?

    /// Frame rate of the ambient steam/liquid motion. 0 keeps the icon fully static
    /// between state changes (smoke fades still animate).
    private static let ambientFramesPerSecond: Double = 10
    /// Frame rate while the smoke is fading in or out — short-lived, so it can be smooth.
    private static let transitionFramesPerSecond: Double = 30
    /// Phase advance per second (matches the original 0.08 per frame at 30 fps).
    private static let phaseSpeed: CGFloat = 2.4
    /// The cup interior is ~13 pt tall; finer fill steps than this are sub-pixel.
    private static let fillSteps: Double = 64

    private var statusItem: NSStatusItem?
    private let renderer = CupStatusIconRenderer()
    private var menu: NSMenu?
    private var remainingItem: NSMenuItem?
    private var animationTimer: Timer?
    private var animationInterval: TimeInterval?
    private var lastFrameTime: CFTimeInterval = 0
    private var occlusionObserver: NSObjectProtocol?
    private var phase: CGFloat = 0
    private var currentFill: Double = 1
    private var drawnFillStep: Int = -1
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
            observeVisibility(of: item)
        }
        // Appear already settled in the correct state; only later changes animate.
        self.showSmoke = showSmoke
        smokeProgress = showSmoke ? 1 : 0
        currentFill = fillLevel
        setRemaining(remainingText, isUnlimited: isUnlimited)
        redraw()
        updateAnimationTimer()
    }

    func update(fillLevel: Double, showSmoke: Bool, remainingText: String, isUnlimited: Bool) {
        currentFill = fillLevel
        self.showSmoke = showSmoke
        setRemaining(remainingText, isUnlimited: isUnlimited)

        if !isMenuBarVisible {
            // Nobody can see a fade right now; land on the final state directly.
            smokeProgress = showSmoke ? 1 : 0
        }
        updateAnimationTimer()
        // While a timer is running the next frame picks the new values up.
        if animationTimer == nil, fillStep != drawnFillStep {
            redraw()
        }
    }

    func hide() {
        stopAnimationTimer()
        if let occlusionObserver {
            NotificationCenter.default.removeObserver(occlusionObserver)
        }
        occlusionObserver = nil
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
        menu = nil
        remainingItem = nil
        smokeProgress = 0
        drawnFillStep = -1
    }

    // MARK: - Animation

    private var isTransitioning: Bool {
        smokeProgress != (showSmoke ? 1 : 0)
    }

    private var fillStep: Int {
        Int((max(0, min(1, currentFill)) * Self.fillSteps).rounded())
    }

    /// The status item's window stops being visible when the menu bar is hidden
    /// (full-screen apps, locked screen, display off).
    private var isMenuBarVisible: Bool {
        guard let window = statusItem?.button?.window else { return true }
        return window.occlusionState.contains(.visible)
    }

    private func observeVisibility(of item: NSStatusItem) {
        guard let window = item.button?.window else { return }
        occlusionObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if self.isMenuBarVisible {
                    self.redraw()
                }
                self.updateAnimationTimer()
            }
        }
    }

    /// Runs exactly one timer, at the slowest rate that the current state needs — or none.
    private func updateAnimationTimer() {
        var interval: TimeInterval?
        if statusItem != nil, isMenuBarVisible {
            if isTransitioning {
                interval = 1.0 / Self.transitionFramesPerSecond
            } else if Self.ambientFramesPerSecond > 0 {
                interval = 1.0 / Self.ambientFramesPerSecond
            }
        }
        guard interval != animationInterval else { return }

        stopAnimationTimer()
        guard let interval else { return }

        lastFrameTime = CACurrentMediaTime()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.advanceFrame()
            }
        }
        timer.tolerance = interval * 0.2
        RunLoop.main.add(timer, forMode: .common)
        animationTimer = timer
        animationInterval = interval
    }

    private func stopAnimationTimer() {
        animationTimer?.invalidate()
        animationTimer = nil
        animationInterval = nil
    }

    private func advanceFrame() {
        let now = CACurrentMediaTime()
        // Clamp so a stalled run loop (sleep, debugger) never produces a visible jump.
        let dt = CGFloat(max(0, min(0.25, now - lastFrameTime)))
        lastFrameTime = now

        phase = (phase + Self.phaseSpeed * dt).truncatingRemainder(dividingBy: 2 * .pi)
        let wasTransitioning = isTransitioning
        advanceSmoke(dt: dt)
        redraw()
        if wasTransitioning != isTransitioning {
            updateAnimationTimer()
        }
    }

    /// Eases `smokeProgress` toward its target — snappy but fluid, independent of frame rate.
    private func advanceSmoke(dt: CGFloat) {
        let target: CGFloat = showSmoke ? 1 : 0
        let delta = target - smokeProgress
        if abs(delta) < 0.002 {
            smokeProgress = target
        } else {
            // Same curve as easing 14% of the remaining distance per frame at 30 fps.
            smokeProgress += delta * (1 - pow(0.86, dt * 30))
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
        drawnFillStep = fillStep
    }

    private func setRemaining(_ remainingText: String, isUnlimited: Bool) {
        let title = isUnlimited ? "Remaining: Unlimited" : "Remaining: \(remainingText)"
        if remainingItem?.title != title {
            remainingItem?.title = title
        }
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
