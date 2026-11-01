import AppKit

// Renders the Music Alarm app icon to a 1024px PNG. The icon is generated from
// code so every build produces the same AppIcon.icns set.
// Usage: generate_icon <output.png>
let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png"

let side: CGFloat = 1024
let image = NSImage(size: NSSize(width: side, height: side))
image.lockFocus()

let backgroundTop = NSColor(calibratedRed: 0.16, green: 0.11, blue: 0.29, alpha: 1.0)
let backgroundBottom = NSColor(calibratedRed: 0.07, green: 0.08, blue: 0.16, alpha: 1.0)
let plum = NSColor(calibratedRed: 0.16, green: 0.11, blue: 0.25, alpha: 1.0)
let cream = NSColor(calibratedRed: 1.0, green: 0.96, blue: 0.87, alpha: 1.0)
let orange = NSColor(calibratedRed: 1.0, green: 0.47, blue: 0.19, alpha: 1.0)
let coral = NSColor(calibratedRed: 0.98, green: 0.24, blue: 0.32, alpha: 1.0)
let violet = NSColor(calibratedRed: 0.51, green: 0.25, blue: 0.86, alpha: 1.0)

func drawLinearGradient(in rect: CGRect, colors: [NSColor], start: CGPoint, end: CGPoint) {
    guard let context = NSGraphicsContext.current?.cgContext,
          let gradient = CGGradient(
              colorsSpace: CGColorSpaceCreateDeviceRGB(),
              colors: colors.map(\.cgColor) as CFArray,
              locations: nil
          ) else { return }

    context.saveGState()
    context.addRect(rect)
    context.clip()
    context.drawLinearGradient(gradient, start: start, end: end, options: [])
    context.restoreGState()
}

func drawRoundedLine(context: CGContext, from: CGPoint, to: CGPoint, color: NSColor, width: CGFloat) {
    context.saveGState()
    context.setStrokeColor(color.cgColor)
    context.setLineWidth(width)
    context.setLineCap(.round)
    context.move(to: from)
    context.addLine(to: to)
    context.strokePath()
    context.restoreGState()
}

// Deep plum background with a restrained Dawn Flow diagonal.
let backgroundRect = NSRect(x: 0, y: 0, width: side, height: side)
let backgroundPath = NSBezierPath(roundedRect: backgroundRect, xRadius: 224, yRadius: 224)
backgroundPath.addClip()
drawLinearGradient(
    in: backgroundRect,
    colors: [backgroundTop, violet, backgroundBottom],
    start: CGPoint(x: 90, y: 970),
    end: CGPoint(x: 960, y: 30)
)

// A soft accent glow keeps the silhouette readable at small sizes.
if let context = NSGraphicsContext.current?.cgContext {
    context.saveGState()
    context.setFillColor(orange.withAlphaComponent(0.14).cgColor)
    context.fillEllipse(in: CGRect(x: 116, y: 100, width: 430, height: 430))
    context.setFillColor(violet.withAlphaComponent(0.16).cgColor)
    context.fillEllipse(in: CGRect(x: 550, y: 545, width: 390, height: 390))
    context.restoreGState()
}

// Alarm bells: simple angled strokes keep the clock readable without literal
// detailed bells that disappear at small sizes.
if let context = NSGraphicsContext.current?.cgContext {
    drawRoundedLine(context: context, from: CGPoint(x: 286, y: 780), to: CGPoint(x: 220, y: 858), color: orange, width: 38)
    drawRoundedLine(context: context, from: CGPoint(x: 738, y: 858), to: CGPoint(x: 672, y: 780), color: coral, width: 38)
}

// Clock face shadow.
let faceRect = NSRect(x: 188, y: 164, width: 648, height: 648)
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.30)
shadow.shadowBlurRadius = 34
shadow.shadowOffset = NSSize(width: 0, height: -18)
NSGraphicsContext.current?.saveGraphicsState()
shadow.set()
plum.setFill()
NSBezierPath(ovalIn: faceRect).fill()
NSGraphicsContext.current?.restoreGraphicsState()

// Orange-to-coral outer ring and warm face.
let ringOuter = NSBezierPath(ovalIn: faceRect)
ringOuter.addClip()
drawLinearGradient(
    in: faceRect,
    colors: [orange, coral, violet],
    start: CGPoint(x: 235, y: 780),
    end: CGPoint(x: 800, y: 200)
)
let innerRect = faceRect.insetBy(dx: 34, dy: 34)
cream.setFill()
NSBezierPath(ovalIn: innerRect).fill()

if let context = NSGraphicsContext.current?.cgContext {
    let center = CGPoint(x: side / 2, y: 488)

    // Clock hands point to a calm 10:00. The long hand also suggests an audio
    // beat, while both hands remain legible at 16px.
    drawRoundedLine(context: context, from: center, to: CGPoint(x: 355, y: 700), color: plum, width: 48)
    drawRoundedLine(context: context, from: center, to: CGPoint(x: 515, y: 760), color: plum, width: 34)

    context.setFillColor(orange.cgColor)
    context.fillEllipse(in: CGRect(x: center.x - 25, y: center.y - 25, width: 50, height: 50))

    // A compact eighth note in the lower-right quadrant supplies the music cue
    // without competing with the clock hands.
    context.setStrokeColor(coral.cgColor)
    context.setFillColor(coral.cgColor)
    context.setLineCap(.round)
    context.setLineWidth(24)
    context.move(to: CGPoint(x: 625, y: 310))
    context.addLine(to: CGPoint(x: 625, y: 472))
    context.strokePath()
    context.fillEllipse(in: CGRect(x: 582, y: 270, width: 86, height: 52))
    context.setLineWidth(20)
    context.move(to: CGPoint(x: 625, y: 472))
    context.addLine(to: CGPoint(x: 710, y: 520))
    context.strokePath()
    context.fillEllipse(in: CGRect(x: 672, y: 488, width: 86, height: 52))
}

// A small inner highlight gives the flat icon enough depth without making it
// look like a glossy skeuomorphic badge.
let highlight = NSBezierPath(ovalIn: innerRect.insetBy(dx: 20, dy: 20))
NSColor.white.withAlphaComponent(0.20).setStroke()
highlight.lineWidth = 6
highlight.stroke()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fputs("Failed to render icon\n", stderr)
    exit(1)
}

do {
    try png.write(to: URL(fileURLWithPath: outPath))
    print("Icon written to \(outPath)")
} catch {
    fputs("Failed to write icon: \(error)\n", stderr)
    exit(1)
}
