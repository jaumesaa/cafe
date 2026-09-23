import SwiftUI

struct CoffeeCupView: View {
    var fill: CGFloat
    var smoke: Bool
    var active: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: false)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                draw(context: context, size: size, time: time)
            }
        }
        .accessibilityHidden(true)
    }

    private func draw(context: GraphicsContext, size: CGSize, time: TimeInterval) {
        let cup = cupRect(in: size)
        drawContactShadow(context: context, cup: cup)
        if smoke || active {
            drawGlow(context: context, cup: cup, time: time)
        }
        drawHandle(context: context, cup: cup)
        drawBody(context: context, cup: cup)
        drawLiquid(context: context, cup: cup, time: time)
        drawRim(context: context, cup: cup)
        drawSpecular(context: context, cup: cup)
        drawSmoke(context: context, cup: cup, time: time)
    }

    private func cupRect(in size: CGSize) -> CGRect {
        // Active sessions get a slightly larger cup presence in the already-awake UI.
        let heightFactor: CGFloat = active ? 0.68 : 0.62
        let height = size.height * heightFactor
        let width = height * 0.82
        let x = (size.width - width) * 0.46
        let y = size.height * (active ? 0.22 : 0.28)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func innerRect(from cup: CGRect) -> CGRect {
        cup.insetBy(dx: cup.width * 0.10, dy: cup.height * 0.08)
    }

    private func bodyPath(in cup: CGRect) -> Path {
        let topL = CGPoint(x: cup.minX + cup.width * 0.08, y: cup.minY + cup.height * 0.08)
        let topR = CGPoint(x: cup.maxX - cup.width * 0.08, y: cup.minY + cup.height * 0.08)
        let botL = CGPoint(x: cup.minX + cup.width * 0.18, y: cup.maxY - cup.height * 0.06)
        let botR = CGPoint(x: cup.maxX - cup.width * 0.18, y: cup.maxY - cup.height * 0.06)
        var path = Path()
        path.move(to: topL)
        path.addCurve(
            to: botL,
            control1: CGPoint(x: cup.minX + cup.width * 0.02, y: cup.minY + cup.height * 0.38),
            control2: CGPoint(x: cup.minX + cup.width * 0.10, y: cup.minY + cup.height * 0.78)
        )
        path.addQuadCurve(to: botR, control: CGPoint(x: cup.midX, y: cup.maxY + cup.height * 0.02))
        path.addCurve(
            to: topR,
            control1: CGPoint(x: cup.maxX - cup.width * 0.10, y: cup.minY + cup.height * 0.78),
            control2: CGPoint(x: cup.maxX - cup.width * 0.02, y: cup.minY + cup.height * 0.38)
        )
        path.closeSubpath()
        return path
    }

    private func innerPath(in cup: CGRect) -> Path {
        let inner = innerRect(from: cup)
        let topL = CGPoint(x: inner.minX + inner.width * 0.04, y: cup.minY + cup.height * 0.13)
        let topR = CGPoint(x: inner.maxX - inner.width * 0.04, y: cup.minY + cup.height * 0.13)
        let botL = CGPoint(x: inner.minX + inner.width * 0.16, y: inner.maxY - inner.height * 0.08)
        let botR = CGPoint(x: inner.maxX - inner.width * 0.16, y: inner.maxY - inner.height * 0.08)
        var path = Path()
        path.move(to: topL)
        path.addCurve(
            to: botL,
            control1: CGPoint(x: inner.minX, y: inner.minY + inner.height * 0.36),
            control2: CGPoint(x: inner.minX + inner.width * 0.08, y: inner.minY + inner.height * 0.78)
        )
        path.addQuadCurve(to: botR, control: CGPoint(x: inner.midX, y: inner.maxY + 2))
        path.addCurve(
            to: topR,
            control1: CGPoint(x: inner.maxX - inner.width * 0.08, y: inner.minY + inner.height * 0.78),
            control2: CGPoint(x: inner.maxX, y: inner.minY + inner.height * 0.36)
        )
        path.closeSubpath()
        return path
    }

    private func drawContactShadow(context: GraphicsContext, cup: CGRect) {
        let shadow = CGRect(
            x: cup.minX + cup.width * 0.12,
            y: cup.maxY - 8,
            width: cup.width * 0.76,
            height: 18
        )
        var ctx = context
        ctx.addFilter(.blur(radius: 10))
        ctx.fill(
            Path(ellipseIn: shadow),
            with: .color(.black.opacity(0.45))
        )
    }

    private func drawGlow(context: GraphicsContext, cup: CGRect, time: TimeInterval) {
        let pulse = 0.22 + 0.06 * sin(time * 1.4)
        var ctx = context
        ctx.addFilter(.blur(radius: 28))
        ctx.fill(
            Path(ellipseIn: CGRect(
                x: cup.midX - cup.width * 0.55,
                y: cup.minY - 10,
                width: cup.width * 1.1,
                height: cup.height * 0.7
            )),
            with: .color(CafeTheme.glow.opacity(pulse))
        )
    }

    private func drawHandle(context: GraphicsContext, cup: CGRect) {
        var path = Path()
        let start = CGPoint(x: cup.maxX - cup.width * 0.10, y: cup.minY + cup.height * 0.28)
        let end = CGPoint(x: cup.maxX - cup.width * 0.14, y: cup.minY + cup.height * 0.62)
        path.move(to: start)
        path.addCurve(
            to: end,
            control1: CGPoint(x: cup.maxX + cup.width * 0.28, y: cup.minY + cup.height * 0.22),
            control2: CGPoint(x: cup.maxX + cup.width * 0.30, y: cup.minY + cup.height * 0.66)
        )
        context.stroke(
            path,
            with: .linearGradient(
                Gradient(colors: [
                    CafeTheme.ceramic,
                    CafeTheme.ceramicShadow,
                    CafeTheme.ceramic.opacity(0.85)
                ]),
                startPoint: CGPoint(x: cup.maxX, y: cup.minY),
                endPoint: CGPoint(x: cup.maxX + cup.width * 0.32, y: cup.maxY)
            ),
            style: StrokeStyle(lineWidth: cup.width * 0.085, lineCap: .round)
        )
        context.stroke(
            path,
            with: .color(.white.opacity(0.28)),
            style: StrokeStyle(lineWidth: cup.width * 0.025, lineCap: .round)
        )
    }

    private func drawBody(context: GraphicsContext, cup: CGRect) {
        let path = bodyPath(in: cup)
        context.fill(
            path,
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: Color.white.opacity(0.98), location: 0),
                    .init(color: CafeTheme.ceramic, location: 0.35),
                    .init(color: CafeTheme.ceramicShadow.opacity(0.9), location: 1)
                ]),
                startPoint: CGPoint(x: cup.minX, y: cup.minY),
                endPoint: CGPoint(x: cup.maxX, y: cup.maxY)
            )
        )
        var innerShade = context
        innerShade.clip(to: innerPath(in: cup))
        innerShade.fill(
            innerPath(in: cup),
            with: .linearGradient(
                Gradient(colors: [
                    Color.black.opacity(0.22),
                    Color.black.opacity(0.08)
                ]),
                startPoint: CGPoint(x: cup.midX, y: cup.minY),
                endPoint: CGPoint(x: cup.midX, y: cup.maxY)
            )
        )
    }

    private func drawLiquid(context: GraphicsContext, cup: CGRect, time: TimeInterval) {
        let cavity = innerPath(in: cup)
        let bounds = cavity.boundingRect
        let fill = max(0, min(1, fill))
        guard fill > 0.01 else { return }

        let maxHeight = bounds.height * 0.86
        let liquidHeight = maxHeight * fill
        let surfaceY = bounds.maxY - liquidHeight - bounds.height * 0.02

        var ctx = context
        ctx.clip(to: cavity)

        var liquid = Path()
        liquid.move(to: CGPoint(x: bounds.minX - 4, y: bounds.maxY + 4))
        liquid.addLine(to: CGPoint(x: bounds.minX - 4, y: surfaceY))
        let steps = 18
        for i in 0...steps {
            let x = bounds.minX + bounds.width * CGFloat(i) / CGFloat(steps)
            let wave = sin(time * 2.1 + Double(x) * 0.085) * 2.4
                + sin(time * 1.3 + Double(x) * 0.16) * 1.2
            liquid.addLine(to: CGPoint(x: x, y: surfaceY + CGFloat(wave)))
        }
        liquid.addLine(to: CGPoint(x: bounds.maxX + 4, y: bounds.maxY + 4))
        liquid.closeSubpath()

        ctx.fill(
            liquid,
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: CafeTheme.coffeeHighlight.opacity(0.95), location: 0),
                    .init(color: CafeTheme.coffee, location: 0.28),
                    .init(color: CafeTheme.espresso, location: 1)
                ]),
                startPoint: CGPoint(x: bounds.midX, y: surfaceY - 8),
                endPoint: CGPoint(x: bounds.midX, y: bounds.maxY)
            )
        )

        var highlight = Path()
        let hy = surfaceY + 1.5
        highlight.addEllipse(in: CGRect(
            x: bounds.minX + bounds.width * 0.12,
            y: hy - 5,
            width: bounds.width * 0.76,
            height: 10
        ))
        ctx.fill(highlight, with: .color(CafeTheme.foam.opacity(0.16)))

        var sheen = Path()
        sheen.addEllipse(in: CGRect(
            x: bounds.minX + bounds.width * 0.18,
            y: surfaceY + liquidHeight * 0.22,
            width: bounds.width * 0.18,
            height: liquidHeight * 0.38
        ))
        var sheenCtx = ctx
        sheenCtx.addFilter(.blur(radius: 7))
        sheenCtx.fill(sheen, with: .color(.white.opacity(0.10)))
    }

    private func drawRim(context: GraphicsContext, cup: CGRect) {
        let ellipse = CGRect(
            x: cup.minX + cup.width * 0.07,
            y: cup.minY + cup.height * 0.015,
            width: cup.width * 0.86,
            height: cup.height * 0.16
        )
        context.fill(
            Path(ellipseIn: ellipse.insetBy(dx: 5, dy: 4)),
            with: .color(Color.black.opacity(0.18))
        )
        context.stroke(
            Path(ellipseIn: ellipse),
            with: .linearGradient(
                Gradient(colors: [
                    .white,
                    CafeTheme.ceramic,
                    CafeTheme.ceramicShadow
                ]),
                startPoint: CGPoint(x: ellipse.minX, y: ellipse.minY),
                endPoint: CGPoint(x: ellipse.maxX, y: ellipse.maxY)
            ),
            lineWidth: 5
        )
        context.stroke(
            Path(ellipseIn: ellipse.insetBy(dx: 1.2, dy: 1.2)),
            with: .color(.white.opacity(0.55)),
            lineWidth: 0.8
        )
    }

    private func drawSpecular(context: GraphicsContext, cup: CGRect) {
        var path = Path()
        path.move(to: CGPoint(x: cup.minX + cup.width * 0.18, y: cup.minY + cup.height * 0.22))
        path.addQuadCurve(
            to: CGPoint(x: cup.minX + cup.width * 0.22, y: cup.minY + cup.height * 0.72),
            control: CGPoint(x: cup.minX + cup.width * 0.08, y: cup.minY + cup.height * 0.48)
        )
        context.stroke(
            path,
            with: .color(.white.opacity(0.38)),
            style: StrokeStyle(lineWidth: 2.2, lineCap: .round)
        )
    }

    private func drawSmoke(context: GraphicsContext, cup: CGRect, time: TimeInterval) {
        let opacity = smoke ? 1.0 : 0.0
        guard opacity > 0.01 else { return }
        let origin = CGPoint(x: cup.midX, y: cup.minY + cup.height * 0.02)
        for i in 0..<7 {
            let seed = Double(i) * 0.93
            let speed = 0.22 + Double(i) * 0.035
            let progress = CGFloat((time * speed + seed).truncatingRemainder(dividingBy: 1.0))
            if progress < 0 { continue }
            var path = Path()
            path.move(to: origin)
            let lift = 92 * progress
            let sway = sin(time * 1.5 + seed) * 16 * progress
            let mid = CGPoint(
                x: origin.x + sway * 0.45 + CGFloat(i - 3) * 2.2,
                y: origin.y - lift * 0.55
            )
            let end = CGPoint(
                x: origin.x + sway + CGFloat(i - 3) * 3.4,
                y: origin.y - lift
            )
            path.move(to: CGPoint(x: origin.x + CGFloat(i - 3) * 3.0, y: origin.y + 6))
            path.addCurve(
                to: end,
                control1: CGPoint(x: origin.x - 12 + CGFloat(i), y: mid.y + 10),
                control2: CGPoint(x: mid.x + 14, y: end.y + 16)
            )
            var smokeCtx = context
            smokeCtx.addFilter(.blur(radius: 1.6 + progress * 3.2))
            smokeCtx.stroke(
                path,
                with: .color(Color.white.opacity((1 - progress) * 0.42 * opacity)),
                style: StrokeStyle(lineWidth: 3.4 - progress * 2.1, lineCap: .round)
            )
        }
    }
}
