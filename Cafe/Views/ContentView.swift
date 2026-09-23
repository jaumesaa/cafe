import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openWindow) private var openWindow

    @State private var showAbout = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            AtmosphereBackground()
            if appState.isActive {
                ActiveSessionView()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                SetupSessionView()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }

            Button {
                showAbout = true
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(CafeTheme.inkMuted)
                    .padding(8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 10)
            .padding(.trailing, 12)
            .help("About Cafe & mainlab.es")
        }
        .frame(width: 380, height: 640)
        .sheet(isPresented: $showAbout) {
            AboutSheetView()
        }
        .animation(.spring(duration: 0.42, bounce: 0.12), value: appState.isActive)
        .onReceive(NotificationCenter.default.publisher(for: .cafeOpenMainWindow)) { _ in
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

// MARK: - Idle setup

private struct SetupSessionView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            CoffeeCupView(
                fill: CGFloat(appState.fillLevel),
                smoke: appState.shouldShowSmoke,
                active: false
            )
            .frame(height: 268)
            .padding(.top, 12)

            DurationReadout(text: appState.remainingDisplay, isActive: false)
                .foregroundStyle(CafeTheme.ink)
                .padding(.bottom, 10)

            Text(subtitle.uppercased())
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .tracking(1.6)
                .foregroundStyle(CafeTheme.inkMuted)
                .padding(.bottom, 22)

            GlassDurationControls()
                .padding(.horizontal, 22)

            ActivateButton(isActive: false) {
                appState.toggle()
            }
            .padding(.horizontal, 22)
            .padding(.top, 12)

            Spacer(minLength: 16)

            CreditsFooter()
                .padding(.bottom, 16)
        }
    }

    private var subtitle: String {
        appState.isInfiniteSelection ? "Until you stop" : "Duration"
    }
}

// MARK: - Already-active / running session

private struct ActiveSessionView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 28)

            CoffeeCupView(
                fill: CGFloat(appState.fillLevel),
                smoke: appState.shouldShowSmoke,
                active: true
            )
            .frame(height: 300)
            .animation(.easeInOut(duration: 0.8), value: appState.shouldShowSmoke)
            .animation(.easeInOut(duration: 0.35), value: appState.fillLevel)

            VStack(spacing: 10) {
                Text("AWAKE")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .tracking(2.4)
                    .foregroundStyle(CafeTheme.glow.opacity(0.85))

                DurationReadout(text: appState.remainingDisplay, isActive: true)
                    .foregroundStyle(CafeTheme.ink)

                Text(statusLine.uppercased())
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(CafeTheme.inkMuted)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity)
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(.horizontal, 28)
            .padding(.top, 8)

            ActivateButton(isActive: true) {
                appState.toggle()
            }
            .padding(.horizontal, 28)
            .padding(.top, 20)

            Spacer(minLength: 28)

            CreditsFooter()
                .padding(.bottom, 16)
        }
    }

    private var statusLine: String {
        appState.isUnlimited ? "Until you stop" : "Remaining"
    }
}

// MARK: - Credits & About

private struct CreditsFooter: View {
    var body: some View {
        HStack(spacing: 5) {
            Text("by")
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundStyle(CafeTheme.inkMuted)
            Link("mainlab.es", destination: URL(string: "https://mainlab.es")!)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(CafeTheme.glow)
        }
    }
}

private struct AboutSheetView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
                .padding(.top, 8)

            VStack(spacing: 4) {
                Text("Cafe")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(CafeTheme.ink)

                Text("Keep your Mac awake in style")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(CafeTheme.inkMuted)

                Text("v1.0.0")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(CafeTheme.inkMuted.opacity(0.8))
            }

            Divider()
                .padding(.horizontal, 16)

            VStack(spacing: 8) {
                Text("Crafted for MacBooks by")
                    .font(.system(size: 12))
                    .foregroundStyle(CafeTheme.inkMuted)

                Link(destination: URL(string: "https://mainlab.es")!) {
                    HStack(spacing: 4) {
                        Text("mainlab.es")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(CafeTheme.glow)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(CafeTheme.glow)
                    }
                }
                .buttonStyle(.plain)
            }

            Button("Done") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.glass)
            .controlSize(.regular)
            .padding(.top, 4)
            .padding(.bottom, 6)
        }
        .padding(24)
        .frame(width: 290)
        .background(AtmosphereBackground())
    }
}

// MARK: - Atmosphere

private struct AtmosphereBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [CafeTheme.atmosphereTop, CafeTheme.atmosphereBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [
                    CafeTheme.glow.opacity(0.34),
                    CafeTheme.glow.opacity(0.08),
                    .clear
                ],
                center: UnitPoint(x: 0.5, y: 0.18),
                startRadius: 10,
                endRadius: 280
            )
            RadialGradient(
                colors: [Color.black.opacity(0.0), Color.black.opacity(0.45)],
                center: .center,
                startRadius: 120,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
    }
}

#Preview("Setup") {
    ContentView()
        .environmentObject(AppState())
}
