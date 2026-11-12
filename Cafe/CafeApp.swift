import AppKit
import SwiftUI

@main
struct CafeApp: App {
    @NSApplicationDelegateAdaptor(CafeAppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        Window("cafe", id: "main") {
            ContentView()
                .environmentObject(appState)
                .background(WindowConfigurator(appState: appState))
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .defaultSize(width: 380, height: 640)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .appInfo) {
                Button("About Cafe") {
                    NSApp.orderFrontStandardAboutPanel(
                        options: [
                            .credits: NSAttributedString(
                                string: "Keep your Mac awake with elegance.\n\nCrafted by mainlab.es\nhttps://mainlab.es",
                                attributes: [
                                    .font: NSFont.systemFont(ofSize: 11),
                                    .foregroundColor: NSColor.secondaryLabelColor
                                ]
                            ),
                            .applicationVersion: "1.0",
                            .version: "1.0.0"
                        ]
                    )
                }
            }
        }
    }
}

final class CafeAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Spotlight-launchable: never LSUIElement. Start as a normal app;
        // switch to `.accessory` at runtime after Keep Awake dismisses the window.
        NSApp.setActivationPolicy(.regular)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        let active = AppState.shared?.isActive ?? false
        if active {
            // Close while caffeinating → menu bar only; do not quit.
            AppState.shared?.becomeAccessoryAfterWindowClose()
            return false
        }
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppState.shared?.prepareForTermination()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Spotlight / Dock reopen while a session may already be running.
        AppState.shared?.showMainWindow()
        return true
    }
}

private struct WindowConfigurator: NSViewRepresentable {
    let appState: AppState

    func makeCoordinator() -> Coordinator {
        Coordinator(appState: appState)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let coordinator = context.coordinator
        DispatchQueue.main.async {
            configure(view.window)
            coordinator.track(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        configure(nsView.window)
        context.coordinator.track(nsView.window)
    }

    private func configure(_ window: NSWindow?) {
        guard let window else { return }
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.styleMask.insert(.fullSizeContentView)
        window.toolbarStyle = .unifiedCompact
    }

    /// Mirrors the window's on-screen visibility into `AppState.isWindowVisible`, so the
    /// cup stops rendering while the window is ordered out (menu-bar mode) or covered.
    @MainActor
    final class Coordinator {
        private let appState: AppState
        private weak var window: NSWindow?
        private var observer: NSObjectProtocol?

        init(appState: AppState) {
            self.appState = appState
        }

        func track(_ window: NSWindow?) {
            guard let window, window !== self.window else { return }
            if let observer {
                NotificationCenter.default.removeObserver(observer)
            }
            self.window = window
            observer = NotificationCenter.default.addObserver(
                forName: NSWindow.didChangeOcclusionStateNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.sync()
                }
            }
            // Never publish from inside a SwiftUI view update.
            DispatchQueue.main.async { [weak self] in
                self?.sync()
            }
        }

        private func sync() {
            guard let window else { return }
            let visible = window.occlusionState.contains(.visible)
            if appState.isWindowVisible != visible {
                appState.isWindowVisible = visible
            }
        }
    }
}
