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
                .background(WindowConfigurator())
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
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configure(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        configure(nsView.window)
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
}
