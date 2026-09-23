import SwiftUI

struct DurationReadout: View {
    let text: String
    let isActive: Bool

    var body: some View {
        Text(text)
            .font(.system(size: isActive ? 52 : 44, weight: .light, design: .rounded))
            .monospacedDigit()
            .tracking(isActive ? 1.4 : 1)
            .foregroundStyle(CafeTheme.ink)
            .contentTransition(.numericText())
            .animation(.snappy(duration: 0.25), value: text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, isActive ? 2 : 6)
            .accessibilityLabel(isActive ? "Remaining \(text)" : "Duration \(text)")
    }
}

struct GlassDurationControls: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        GlassEffectContainer(spacing: 16) {
            VStack(spacing: 16) {
                GlassTimeSlider(
                    title: "Hours",
                    value: Binding(
                        get: { Double(appState.hours) },
                        set: { appState.hours = Int($0.rounded()) }
                    ),
                    range: 0...12,
                    step: 1
                )

                GlassTimeSlider(
                    title: "Minutes",
                    value: Binding(
                        get: { Double(appState.minutes) },
                        set: { appState.minutes = Int($0.rounded()) }
                    ),
                    range: 0...59,
                    step: 1
                )

                HStack {
                    Text(appState.isInfiniteSelection ? "Unlimited keep-awake" : "Timed session")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Clear") {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            appState.hours = 0
                            appState.minutes = 0
                        }
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                    .opacity(appState.isInfiniteSelection ? 0.4 : 1)
                    .disabled(appState.isInfiniteSelection)
                }
            }
            .padding(16)
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }
}

/// Custom glass slider with a fluid physical thumb — not a plain system slider.
struct GlassTimeSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    @State private var isDragging = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.1)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(displayValue)
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }

            GeometryReader { geo in
                let width = geo.size.width
                let progress = range.upperBound > range.lowerBound
                    ? (value - range.lowerBound) / (range.upperBound - range.lowerBound)
                    : 0
                let x = CGFloat(progress) * width

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.08))
                        .frame(height: 7)
                        .overlay(
                            Capsule()
                                .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
                        )

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.accentColor.opacity(0.95),
                                    Color(red: 0.85, green: 0.55, blue: 0.28)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(7, x), height: 7)
                        .shadow(color: Color.accentColor.opacity(0.35), radius: isDragging ? 8 : 4, y: 0)

                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: isDragging ? 22 : 18, height: isDragging ? 22 : 18)
                        .overlay(
                            Circle()
                                .strokeBorder(.white.opacity(0.35), lineWidth: 0.8)
                        )
                        .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
                        .glassEffect(.clear.interactive(), in: Circle())
                        .offset(x: max(0, min(width - (isDragging ? 22 : 18), x - (isDragging ? 11 : 9))))
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { drag in
                                    isDragging = true
                                    let p = min(max(0, drag.location.x / width), 1)
                                    let raw = range.lowerBound + Double(p) * (range.upperBound - range.lowerBound)
                                    let stepped = (raw / step).rounded() * step
                                    value = min(max(range.lowerBound, stepped), range.upperBound)
                                }
                                .onEnded { _ in
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        isDragging = false
                                    }
                                }
                        )
                }
                .frame(maxHeight: .infinity)
                .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.82), value: value)
            }
            .frame(height: 28)
            .accessibilityElement()
            .accessibilityLabel(title)
            .accessibilityValue(displayValue)
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment:
                    value = min(range.upperBound, value + step)
                case .decrement:
                    value = max(range.lowerBound, value - step)
                @unknown default:
                    break
                }
            }
        }
    }

    private var displayValue: String {
        String(Int(value.rounded()))
    }
}
