import AppKit

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.setFillColor(NSColor(calibratedRed: 0.09, green: 0.07, blue: 0.05, alpha: 1).cgColor)
    ctx.fill(rect)

    let glow = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            NSColor(calibratedRed: 0.72, green: 0.46, blue: 0.18, alpha: 0.55).cgColor,
            NSColor(calibratedRed: 0.72, green: 0.46, blue: 0.18, alpha: 0).cgColor
        ] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawRadialGradient(
        glow,
        startCenter: CGPoint(x: rect.midX, y: rect.midY * 0.62),
        startRadius: 20,
        endCenter: CGPoint(x: rect.midX, y: rect.midY * 0.62),
        endRadius: 420,
        options: []
    )

    let cup = CGRect(x: 280, y: 250, width: 420, height: 500)

    // Handle
    ctx.setStrokeColor(NSColor(calibratedRed: 0.93, green: 0.90, blue: 0.86, alpha: 1).cgColor)
    ctx.setLineWidth(48)
    ctx.setLineCap(.round)
    ctx.move(to: CGPoint(x: cup.maxX - 40, y: cup.minY + 330))
    ctx.addCurve(
        to: CGPoint(x: cup.maxX - 55, y: cup.minY + 160),
        control1: CGPoint(x: cup.maxX + 130, y: cup.minY + 350),
        control2: CGPoint(x: cup.maxX + 140, y: cup.minY + 140)
    )
    ctx.strokePath()

    // Body
    let body = CGMutablePath()
    body.move(to: CGPoint(x: cup.minX + 40, y: cup.maxY - 80))
    body.addCurve(
        to: CGPoint(x: cup.minX + 70, y: cup.minY + 40),
        control1: CGPoint(x: cup.minX - 10, y: cup.midY + 80),
        control2: CGPoint(x: cup.minX + 30, y: cup.minY + 140)
    )
    body.addQuadCurve(
        to: CGPoint(x: cup.maxX - 110, y: cup.minY + 40),
        control: CGPoint(x: cup.midX - 20, y: cup.minY - 10)
    )
    body.addCurve(
        to: CGPoint(x: cup.maxX - 50, y: cup.maxY - 80),
        control1: CGPoint(x: cup.maxX - 70, y: cup.minY + 140),
        control2: CGPoint(x: cup.maxX + 10, y: cup.midY + 80)
    )
    body.closeSubpath()
    ctx.setFillColor(NSColor(calibratedRed: 0.94, green: 0.91, blue: 0.87, alpha: 1).cgColor)
    ctx.addPath(body)
    ctx.fillPath()

    // Liquid
    ctx.saveGState()
    ctx.addPath(body)
    ctx.clip()
    let liquid = CGRect(x: cup.minX, y: cup.minY + 40, width: cup.width, height: 310)
    ctx.setFillColor(NSColor(calibratedRed: 0.32, green: 0.16, blue: 0.07, alpha: 1).cgColor)
    ctx.fill(liquid)
    ctx.restoreGState()

    // Rim
    let rim = CGRect(x: cup.minX + 28, y: cup.maxY - 130, width: 360, height: 90)
    ctx.setStrokeColor(NSColor.white.cgColor)
    ctx.setLineWidth(22)
    ctx.strokeEllipse(in: rim)

    // Smoke
    ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.35).cgColor)
    ctx.setLineWidth(14)
    ctx.setLineCap(.round)
    for i in 0..<3 {
        let x = cup.midX - 40 + CGFloat(i) * 36
        ctx.move(to: CGPoint(x: x, y: cup.maxY - 40))
        ctx.addCurve(
            to: CGPoint(x: x + CGFloat(i - 1) * 28, y: cup.maxY + 90),
            control1: CGPoint(x: x - 30, y: cup.maxY + 20),
            control2: CGPoint(x: x + 40, y: cup.maxY + 50)
        )
        ctx.strokePath()
    }

    return true
}

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fputs("Failed to encode icon\n", stderr)
    exit(1)
}

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png")
try png.write(to: out)
print("Wrote \(out.path)")
