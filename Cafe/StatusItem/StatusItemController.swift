import AppKit
import QuartzCore

/// Native menu-bar status item shown only while caffeinate is active.
///
/// Redrawing a status item is expensive: every new image is laid out, rasterised and
/// composited by the window server. So the icon is redrawn only when what it shows
/// changes:
/// - the cup itself changes only when the fill level moves by one visible step;
/// - the steam is the only ambient motion. It runs at a modest frame rate, only while
///   steam is showing and someone can see it (menu bar on screen, displays awake, the
///   session unlocked), and its frames repeat every cycle, so each one is drawn once
///   and then reused from a cache.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    var onStop: (() -> Void)?
    /// Told when the menu opens or closes, so the countdown only ticks while it is read.
    var onMenuVisibilityChanged: ((Bool) -> Void)?

    /// Phase advance per second (matches the original 0.08 per frame at 30 fps).
    private static let phaseSpeed: CGFloat = 2.4
    /// The steam repeats every 2π of phase (≈2.6 s), drawn as this many cached frames per
    /// cycle: ≈6 fps. Every frame costs ≈9 ms of main-thread time inside AppKit (the
    /// status item re-renders the button and snapshots it for the menu bar), so this
    /// count is what the steam costs; the wisps move < 1.5 pt per frame at this pace.
    private static let steamFramesPerCycle = 16
    private static let steamFrameInterval: TimeInterval =
        Double(2 * CGFloat.pi / phaseSpeed) / Double(steamFramesPerCycle)
    /// Frame rate while the smoke fades in or out — short-lived, so it can be smooth.
    private static let transitionFramesPerSecond: Double = 30
    /// The cup interior is ~13 pt tall; finer fill steps than this are sub-pixel.
    static let fillSteps: Double = 64
    private static let iconSize = NSSize(width: 22, height: 22)

    private var statusItem: NSStatusItem?
    private let renderer = CupStatusIconRenderer()
    private var menu: NSMenu?
    private var remainingItem: NSMenuItem?
    private var remainingTitle = "Remaining: —"
    private var animationTimer: Timer?
    private var animationInterval: TimeInterval?
    private var lastFrameTime: CFTimeInterval = 0
    private var occlusionObserver: NSObjectProtocol?

    private var steamFrame = 0
    private var phase: CGFloat = 0
    private var currentFill: Double = 1
    private var showSmoke: Bool = true
    /// Smoothly interpolated 0…1 value that drives both the smoke fade and the cup scale.
    private var smokeProgress: CGFloat = 0

    /// What the button currently shows; a redraw with the same key is skipped.
    private var drawnKey: FrameKey?
    /// Settled frames for the current fill step (the steam-less cup, or one per steam frame).
    private var frameCache: [FrameKey: NSImage] = [:]

    /// False while every display is asleep, the screen is locked or the user session is
    /// switched out — nobody can see the menu bar then.
    private var isScreenAvailable = true
    private(set) var isMenuOpen = false

    private struct FrameKey: Hashable {
        var fillStep: Int
        /// -1 for the steam-less cup.
        var steamFrame: Int
    }

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

        if !canAnimate {
            // Nobody can see a fade right now; land on the final state directly.
            smokeProgress = showSmoke ? 1 : 0
        }
        updateAnimationTimer()
        // While a timer is running the next frame picks the new values up.
        if animationTimer == nil {
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
        isMenuOpen = false
        smokeProgress = 0
        drawnKey = nil
        frameCache.removeAll()
    }

    /// Displays asleep, screen locked, session switched out: stop all motion. Resume,
    /// with a fresh frame, once the screen is back.
    func setScreenAvailable(_ available: Bool) {
        guard available != isScreenAvailable else { return }
        isScreenAvailable = available
        if !available {
            smokeProgress = showSmoke ? 1 : 0
        } else {
            redraw()
        }
        updateAnimationTimer()
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

    private var canAnimate: Bool {
        statusItem != nil && isScreenAvailable && isMenuBarVisible
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
                if !self.canAnimate {
                    self.smokeProgress = self.showSmoke ? 1 : 0
                }
                if self.isMenuBarVisible {
                    self.redraw()
                }
                self.updateAnimationTimer()
            }
        }
    }

    /// Runs exactly one timer, at the slowest rate the current state needs — or none.
    /// A settled cup without steam needs none: it only changes with the fill level,
    /// which `update` redraws.
    private func updateAnimationTimer() {
        var interval: TimeInterval?
        if canAnimate {
            if isTransitioning {
                interval = 1.0 / Self.transitionFramesPerSecond
            } else if showSmoke {
                interval = Self.steamFrameInterval
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

        let wasTransitioning = isTransitioning
        if wasTransitioning {
            phase = (phase + Self.phaseSpeed * dt).truncatingRemainder(dividingBy: 2 * .pi)
            advanceSmoke(dt: dt)
            if !isTransitioning {
                snapPhaseToSteamFrame()
            }
        } else {
            // Settled steam: step through the fixed cycle, so every frame is a cache hit
            // after the first lap.
            steamFrame = (steamFrame + 1) % Self.steamFramesPerCycle
            phase = steamPhase(steamFrame)
        }
        redraw()
        if wasTransitioning != isTransitioning {
            updateAnimationTimer()
        }
    }

    private func steamPhase(_ frame: Int) -> CGFloat {
        CGFloat(frame) * 2 * .pi / CGFloat(Self.steamFramesPerCycle)
    }

    private func snapPhaseToSteamFrame() {
        let step = 2 * CGFloat.pi / CGFloat(Self.steamFramesPerCycle)
        steamFrame = Int((phase / step).rounded()) % Self.steamFramesPerCycle
        phase = steamPhase(steamFrame)
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
        let step = fillStep

        // Mid-fade frames are one-offs; draw them directly.
        guard !isTransitioning else {
            button.image = makeImage(fillStep: step)
            drawnKey = nil
            return
        }

        let key = FrameKey(fillStep: step, steamFrame: smokeProgress > 0 ? steamFrame : -1)
        guard key != drawnKey else { return }
        if let drawn = drawnKey, drawn.fillStep != step {
            // The fill only moves one way; frames for an old level are never shown again.
            frameCache.removeAll(keepingCapacity: true)
        }
        let image: NSImage
        if let cached = frameCache[key] {
            image = cached
        } else {
            image = makeImage(fillStep: step)
            frameCache[key] = image
        }
        button.image = image
        drawnKey = key
    }

    /// The image keeps its drawing handler, so AppKit still renders it for the menu
    /// bar's current appearance and scale; reusing the instance reuses that rendering.
    private func makeImage(fillStep: Int) -> NSImage {
        renderer.image(
            size: Self.iconSize,
            fillLevel: Double(fillStep) / Self.fillSteps,
            smokeProgress: smokeProgress,
            phase: phase
        )
    }

    // MARK: - Menu

    private func setRemaining(_ remainingText: String, isUnlimited: Bool) {
        remainingTitle = isUnlimited ? "Remaining: Unlimited" : "Remaining: \(remainingText)"
        // The title only matters while the menu is open; it is refreshed when it opens.
        if isMenuOpen, remainingItem?.title != remainingTitle {
            remainingItem?.title = remainingTitle
        }
    }

    private func buildMenu() {
        let menu = NSMenu()
        menu.delegate = self
        let remaining = NSMenuItem(title: remainingTitle, action: nil, keyEquivalent: "")
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

    func menuWillOpen(_ menu: NSMenu) {
        isMenuOpen = true
        // Lets the owner refresh the countdown right away and tick every second.
        onMenuVisibilityChanged?(true)
        if remainingItem?.title != remainingTitle {
            remainingItem?.title = remainingTitle
        }
    }

    func menuDidClose(_ menu: NSMenu) {
        guard isMenuOpen else { return }
        isMenuOpen = false
        onMenuVisibilityChanged?(false)
    }

    @objc private func stopAction() {
        onStop?()
    }
}
