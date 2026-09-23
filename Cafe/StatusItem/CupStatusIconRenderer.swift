import AppKit

/// Custom-drawn coffee cup for the menu bar — premium, non-emoji, non-SF-Symbol final look.
/// Drawn to fill a ~22×22 pt status item with minimal padding.
final class CupStatusIconRenderer {
    func image(
        size: NSSize,
        fillLevel: Double,
        smokeProgress: CGFloat,
        phase: CGFloat
    ) -> NSImage {
        let fill = CGFloat(max(0, min(1, fillLevel)))
        let image = NSImage(size: size, flipped: true) { [weak self] rect in
            guard let self, let ctx = NSGraphicsContext.current?.cgContext else { return false }
            self.draw(
                in: ctx,
                size: rect.size,
                fillLevel: fill,
                smokeProgress: smokeProgress,
                phase: phase
            )
            return true
        }
        image.isTemplate = false
        return image
    }

    private func draw(
        in ctx: CGContext,
        size: NSSize,
        fillLevel: CGFloat,
        smokeProgress: CGFloat,
        phase: CGFloat
    ) {
        let w = size.width
        let h = size.height

        let s = max(0, min(1, smokeProgress))

        // Full-size cup (no smoke) — the size that feels right.
        let fullTop: CGFloat = 0.24
        let fullBottom: CGFloat = 0.83
        let fullLeft: CGFloat = 0.155
        let fullRight: CGFloat = 0.67

        // Slightly smaller cup while smoke is present, nudged down to make room above.
        let smokeTop: CGFloat = 0.36
        let smokeBottom: CGFloat = 0.84
        let smokeLeft: CGFloat = 0.20
        let smokeRight: CGFloat = 0.625

        let cupTop = h * lerp(fullTop, smokeTop, s)
        let cupBottom = h * lerp(fullBottom, smokeBottom, s)
        let cupLeft = w * lerp(fullLeft, smokeLeft, s)
        let cupRight = w * lerp(fullRight, smokeRight, s)
        let cupMidTopWidth = cupRight - cupLeft
        let cupBottomInset = cupMidTopWidth * 0.107

        if s > 0.001 {
            drawSmoke(in: ctx, width: w, cupTop: cupTop, phase: phase, intensity: s)
        }

        let body = CGMutablePath()
        body.move(to: CGPoint(x: cupLeft, y: cupTop))
        body.addLine(to: CGPoint(x: cupRight, y: cupTop))
        body.addLine(to: CGPoint(x: cupRight - cupBottomInset, y: cupBottom))
        body.addQuadCurve(
            to: CGPoint(x: cupLeft + cupBottomInset, y: cupBottom),
            control: CGPoint(x: w * 0.42, y: cupBottom + h * 0.03)
        )
        body.closeSubpath()

        let fill = max(0.05, fillLevel)
        let liquidTop = cupBottom - (cupBottom - cupTop) * fill

        ctx.saveGState()
        ctx.addPath(body)
        ctx.clip()

        let liquidColors = [
            NSColor(calibratedRed: 0.42, green: 0.24, blue: 0.12, alpha: 0.95).cgColor,
            NSColor(calibratedRed: 0.22, green: 0.12, blue: 0.06, alpha: 0.98).cgColor
        ]
        if let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: liquidColors as CFArray,
            locations: [0, 1]
        ) {
            ctx.drawLinearGradient(
                gradient,
                start: CGPoint(x: w * 0.5, y: liquidTop),
                end: CGPoint(x: w * 0.5, y: cupBottom),
                options: []
            )
        }

        let wave = CGMutablePath()
        let amp: CGFloat = 0.75
        wave.move(to: CGPoint(x: cupLeft, y: liquidTop))
        for i in 0..<8 {
            let t = CGFloat(i) / 7.0
            let x = cupLeft + cupMidTopWidth * t
            let y = liquidTop + sin(phase * 2 + t * .pi * 2) * amp
            wave.addLine(to: CGPoint(x: x, y: y))
        }
        wave.addLine(to: CGPoint(x: cupRight, y: liquidTop + 2.5))
        wave.addLine(to: CGPoint(x: cupLeft, y: liquidTop + 2.5))
        wave.closeSubpath()
        ctx.setFillColor(NSColor(calibratedRed: 0.62, green: 0.40, blue: 0.22, alpha: 0.35).cgColor)
        ctx.addPath(wave)
        ctx.fillPath()
        ctx.restoreGState()

        ctx.setStrokeColor(NSColor.labelColor.withAlphaComponent(0.88).cgColor)
        ctx.setLineWidth(1.35)
        ctx.setLineJoin(.round)
        ctx.addPath(body)
        ctx.strokePath()

        let rim = CGRect(x: cupLeft - 0.6, y: cupTop - 1.4, width: cupMidTopWidth + 1.2, height: 2.8)
        ctx.setStrokeColor(NSColor.labelColor.withAlphaComponent(0.58).cgColor)
        ctx.setLineWidth(1.15)
        ctx.strokeEllipse(in: rim)

        // Larger, clearer handle that still clears the status-item edge.
        let handle = CGMutablePath()
        handle.move(to: CGPoint(x: cupRight - 0.4, y: cupTop + h * 0.07))
        handle.addCurve(
            to: CGPoint(x: cupRight - 0.4, y: cupTop + h * 0.40),
            control1: CGPoint(x: cupRight + w * 0.22, y: cupTop + h * 0.06),
            control2: CGPoint(x: cupRight + w * 0.22, y: cupTop + h * 0.40)
        )
        ctx.setStrokeColor(NSColor.labelColor.withAlphaComponent(0.84).cgColor)
        ctx.setLineWidth(1.4)
        ctx.setLineCap(.round)
        ctx.addPath(handle)
        ctx.strokePath()
    }

    private func drawSmoke(in ctx: CGContext, width w: CGFloat, cupTop: CGFloat, phase: CGFloat, intensity: CGFloat) {
        ctx.saveGState()
        // Reach is a touch shorter than before so the puff never grazes the top edge.
        let reach = cupTop * 0.58
        for i in 0..<3 {
            let offset = CGFloat(i) * 0.95
            let path = CGMutablePath()
            let baseX = w * (0.28 + CGFloat(i) * 0.13)
            path.move(to: CGPoint(x: baseX, y: cupTop - 0.5))
            for step in 1...7 {
                let t = CGFloat(step) / 7.0
                let y = cupTop - 0.5 - t * reach
                let x = baseX + sin(phase + offset + t * 3.4) * (1.5 + t * 1.35)
                path.addLine(to: CGPoint(x: x, y: y))
            }
            ctx.setStrokeColor(NSColor.labelColor.withAlphaComponent(0.28 * intensity * (1 - CGFloat(i) * 0.14)).cgColor)
            ctx.setLineWidth(1.25 - CGFloat(i) * 0.18)
            ctx.setLineCap(.round)
            ctx.addPath(path)
            ctx.strokePath()
        }
        ctx.restoreGState()
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }
}
