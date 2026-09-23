import SwiftUI

struct ActivateButton: View {
    var isActive: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: isActive ? "stop.fill" : "play.fill")
                    .font(.system(size: 12, weight: .semibold))
                Text(isActive ? "Stop" : "Keep Awake")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .tracking(0.2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.glassProminent)
        .tint(isActive ? CafeTheme.stop : CafeTheme.coffeeHighlight)
        .controlSize(.large)
        .animation(.spring(duration: 0.45, bounce: 0.18), value: isActive)
        .accessibilityLabel(isActive ? "Stop keep awake" : "Keep Awake")
    }
}
