import AppKit
import Combine
import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    static weak var shared: AppState?

    @Published var hours: Int = 0
    @Published var minutes: Int = 0
    @Published var isActive: Bool = false
    @Published var isUnlimited: Bool = false
    @Published var remainingSeconds: TimeInterval = 0
    @Published var totalSeconds: TimeInterval = 0
    @Published var showAdvancedShutdown: Bool = false
    @Published var shutdownWhenDone: Bool = false
    /// False while the main window is ordered out or fully covered — its animations pause.
    @Published var isWindowVisible: Bool = true {
        didSet {
            guard isWindowVisible != oldValue else { return }
            // Coming back on screen: show the current countdown right away.
            if isWindowVisible {
                tick()
            } else {
                scheduleTick()
            }
        }
    }
    /// False while the displays sleep, the screen is locked or the session is switched
    /// out — every animation pauses.
    @Published private(set) var isScreenAvailable: Bool = true

    let engine = CaffeinateEngine()
    private let statusItem = StatusItemController()
    private let screenActivity = ScreenActivityMonitor()
    private var tickTimer: Timer?
    private(set) var endDate: Date?
    private var isShuttingDown = false

    /// Fill level for cup visuals: 1.0 = full.
    var fillLevel: Double {
        guard isActive else { return 1.0 }
        if isUnlimited { return 1.0 }
        guard totalSeconds > 0 else { return 0 }
        return max(0, min(1, remainingSeconds / totalSeconds))
    }

    /// Smoke when unlimited, or when remaining > 75% of total.
    var shouldShowSmoke: Bool {
        guard isActive else { return false }
        if isUnlimited { return true }
        return fillLevel > 0.75
    }

    var durationSeconds: TimeInterval {
        TimeInterval(hours * 3600 + minutes * 60)
    }

    var isInfiniteSelection: Bool {
        hours == 0 && minutes == 0
    }

    var remainingDisplay: String {
        if !isActive { return formattedDuration(durationSeconds) }
        if isUnlimited { return "∞" }
        return formattedCountdown(remainingSeconds)
    }

    init() {
        AppState.shared = self
        statusItem.onStop = { [weak self] in
            self?.stop()
        }
        statusItem.onMenuVisibilityChanged = { [weak self] isOpen in
            guard let self else { return }
            // Opening the menu shows the countdown: refresh it now, then every second.
            if isOpen {
                self.tick()
            } else {
                self.scheduleTick()
            }
        }
        engine.onProcessEnded = { [weak self] in
            Task { @MainActor in
                self?.handleEngineEnded()
            }
        }
        screenActivity.onChange = { [weak self] available in
            guard let self else { return }
            self.isScreenAvailable = available
            self.statusItem.setScreenAvailable(available)
            if available {
                self.tick()
            } else {
                self.scheduleTick()
            }
        }
    }

    func toggle() {
        if isActive {
            stop()
        } else {
            start()
        }
    }

    func start() {
        let unlimited = isInfiniteSelection
        let seconds = durationSeconds
        let ok = engine.start(seconds: unlimited ? nil : seconds)
        guard ok else { return }

        isUnlimited = unlimited
        isActive = true
        totalSeconds = unlimited ? 0 : seconds
        remainingSeconds = unlimited ? 0 : seconds
        endDate = unlimited ? nil : Date().addingTimeInterval(seconds)

        statusItem.show(
            fillLevel: fillLevel,
            showSmoke: shouldShowSmoke,
            remainingText: statusRemainingText(),
            isUnlimited: isUnlimited
        )
        scheduleTick()
        dismissMainWindowToAccessory()
    }

    func stop() {
        engine.stop()
        clearSession()
        finishAfterSessionEnded()
    }

    /// Tear down without quitting — used from `applicationWillTerminate`.
    func prepareForTermination() {
        isShuttingDown = true
        engine.stop()
        clearSession()
    }

    func showMainWindow() {
        // Spotlight / reopen while a session is running: become a normal app again,
        // show the window, keep `isActive` so the already-active UI can render.
        NSApp.setActivationPolicy(.regular)
        NotificationCenter.default.post(name: .cafeOpenMainWindow, object: nil)
        NSApp.activate(ignoringOtherApps: true)
        for window in mainWindows() {
            window.makeKeyAndOrderFront(nil)
        }
    }

    /// Red-close while still caffeinating: menu bar only, stay alive.
    func becomeAccessoryAfterWindowClose() {
        guard isActive else { return }
        NSApp.setActivationPolicy(.accessory)
    }

    private func dismissMainWindowToAccessory() {
        guard let window = mainWindows().first(where: { $0.isVisible }) ?? mainWindows().first else {
            NSApp.setActivationPolicy(.accessory)
            return
        }
        WindowDepartureAnimator.dismiss(window) {
            // Order out synchronously while the window is still invisible (alpha 0),
            // then switch to accessory — no restored frame is ever shown.
            window.orderOut(nil)
            NSApp.setActivationPolicy(.accessory)
        }
    }

    private func finishAfterSessionEnded() {
        guard !isShuttingDown else { return }
        if hasVisibleMainWindow {
            NSApp.setActivationPolicy(.regular)
        } else {
            isShuttingDown = true
            NSApp.terminate(nil)
        }
    }

    private var hasVisibleMainWindow: Bool {
        mainWindows().contains { $0.isVisible }
    }

    private func mainWindows() -> [NSWindow] {
        NSApp.windows.filter { window in
            window.title == "cafe" || window.identifier?.rawValue == "main"
        }
    }

    /// Someone can read the countdown: the window is on screen, or the menu is open.
    private var isCountdownOnScreen: Bool {
        (isWindowVisible && isScreenAvailable) || statusItem.isMenuOpen
    }

    /// One timer at a time, rescheduled after every tick. The countdown text changes
    /// once per second, so that is the pace while it is on screen. Otherwise only the
    /// menu-bar cup is visible, and it changes only when the fill drops by one step or
    /// the steam stops, so the next wake-up is at that moment (or the end).
    /// Anything that must look smooth (the cup in the window) derives its own value
    /// from `endDate` per frame instead of being pushed from here.
    private func scheduleTick() {
        tickTimer?.invalidate()
        tickTimer = nil
        // An unlimited session has nothing that changes over time.
        guard isActive, !isUnlimited, let endDate else { return }

        let remaining = endDate.timeIntervalSinceNow
        let delay: TimeInterval
        let tolerance: TimeInterval
        if isCountdownOnScreen {
            delay = 1
            tolerance = 0.1
        } else {
            // A hair past the boundary, so the new step is already reached when we wake.
            delay = max(0.5, min(remaining, secondsUntilIconChange(remaining: remaining)) + 0.05)
            tolerance = min(1, delay * 0.05)
        }
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.tick()
            }
        }
        timer.tolerance = tolerance
        RunLoop.main.add(timer, forMode: .common)
        tickTimer = timer
    }

    /// Time until the menu-bar cup looks different: the next fill step, or the steam
    /// stopping at 75%.
    private func secondsUntilIconChange(remaining: TimeInterval) -> TimeInterval {
        guard totalSeconds > 0 else { return remaining }
        let steps = StatusItemController.fillSteps
        let step = (max(0, min(1, remaining / totalSeconds)) * steps).rounded()
        var next = remaining - (step - 0.5) / steps * totalSeconds
        let smokeEnds = remaining - 0.75 * totalSeconds
        if smokeEnds > 0 {
            next = min(next, smokeEnds)
        }
        return max(0, next)
    }

    private func tick() {
        guard isActive else { return }

        if !isUnlimited, let endDate {
            remainingSeconds = max(0, endDate.timeIntervalSinceNow)
            if remainingSeconds <= 0 {
                handleTimedCompletion()
                return
            }
        }

        statusItem.update(
            fillLevel: fillLevel,
            showSmoke: shouldShowSmoke,
            remainingText: statusRemainingText(),
            isUnlimited: isUnlimited
        )
        scheduleTick()
    }

    private func handleTimedCompletion() {
        let shouldShutdown = shutdownWhenDone && showAdvancedShutdown
        engine.stop()
        clearSession()
        if shouldShutdown {
            // Optional hard-to-accident control: only when explicitly enabled in advanced panel.
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            task.arguments = ["-e", "tell application \"System Events\" to shut down"]
            try? task.run()
        }
        finishAfterSessionEnded()
    }

    private func handleEngineEnded() {
        guard isActive else { return }
        clearSession()
        finishAfterSessionEnded()
    }

    private func clearSession() {
        isActive = false
        isUnlimited = false
        remainingSeconds = 0
        totalSeconds = 0
        endDate = nil
        tickTimer?.invalidate()
        tickTimer = nil
        statusItem.hide()
    }

    private func statusRemainingText() -> String {
        if isUnlimited { return "Unlimited" }
        return formattedCountdown(remainingSeconds)
    }

    private func formattedDuration(_ seconds: TimeInterval) -> String {
        if seconds <= 0 { return "∞" }
        let total = Int(seconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 && m > 0 { return String(format: "%dh %02dm", h, m) }
        if h > 0 { return String(format: "%dh", h) }
        if m > 0 { return String(format: "%dm", m) }
        return "∞"
    }

    private func formattedCountdown(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }
}

/// Tells whether anyone can see the screen: every display asleep, the screen locked or
/// the user session switched out all mean no animation needs to run.
@MainActor
final class ScreenActivityMonitor {
    var onChange: ((Bool) -> Void)?

    private var displaysAsleep = false
    private var screenLocked = false
    private var sessionInactive = false
    private var observers: [(center: NotificationCenter, token: NSObjectProtocol)] = []

    var isAvailable: Bool {
        !displaysAsleep && !screenLocked && !sessionInactive
    }

    init() {
        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.screensDidSleepNotification) { $0.displaysAsleep = true }
        observe(workspace, NSWorkspace.screensDidWakeNotification) { $0.displaysAsleep = false }
        observe(workspace, NSWorkspace.sessionDidResignActiveNotification) { $0.sessionInactive = true }
        observe(workspace, NSWorkspace.sessionDidBecomeActiveNotification) { $0.sessionInactive = false }
        let distributed = DistributedNotificationCenter.default()
        observe(distributed, Notification.Name("com.apple.screenIsLocked")) { $0.screenLocked = true }
        observe(distributed, Notification.Name("com.apple.screenIsUnlocked")) { $0.screenLocked = false }
    }

    private func observe(
        _ center: NotificationCenter,
        _ name: Notification.Name,
        _ apply: @escaping @MainActor @Sendable (ScreenActivityMonitor) -> Void
    ) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let wasAvailable = self.isAvailable
                apply(self)
                if self.isAvailable != wasAvailable {
                    self.onChange?(self.isAvailable)
                }
            }
        }
        observers.append((center, token))
    }
}
