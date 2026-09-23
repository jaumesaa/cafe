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

    let engine = CaffeinateEngine()
    private let statusItem = StatusItemController()
    private var tickTimer: AnyCancellable?
    private var endDate: Date?
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
        engine.onProcessEnded = { [weak self] in
            Task { @MainActor in
                self?.handleEngineEnded()
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
        startTicking()
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

    private func startTicking() {
        tickTimer?.cancel()
        tickTimer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
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
        tickTimer?.cancel()
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
