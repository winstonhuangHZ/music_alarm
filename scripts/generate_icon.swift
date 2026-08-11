import AppKit

// Renders the app icon (red rounded square with a white clock face) to a 1024px
// PNG. Usage: generate_icon <output.png>
let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png"

let side: CGFloat = 1024
let image = NSImage(size: NSSize(width: side, height: side))
image.lockFocus()

let red = NSColor(calibratedRed: 0.93, green: 0.36, blue: 0.30, alpha: 1.0)
let dark = NSColor(calibratedRed: 0.24, green: 0.24, blue: 0.30, alpha: 1.0)
let white = NSColor.white

// Rounded background
let bg = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: side, height: side),
                      xRadius: 220, yRadius: 220)
red.setFill()
bg.fill()

// Clock face
let faceRect = NSRect(x: 262, y: 262, width: 500, height: 500)
let facePath = NSBezierPath(ovalIn: faceRect)
white.setFill()
facePath.fill()

let ring = NSBezierPath(ovalIn: faceRect)
red.setStroke()
ring.lineWidth = 34
ring.stroke()

// Center dot
let dot = NSRect(x: 498, y: 498, width: 28, height: 28)
let dotPath = NSBezierPath(ovalIn: dot)
red.setFill()
dotPath.fill()

// Clock hands (AppKit coords: origin bottom-left, y up)
if let ctx = NSGraphicsContext.current?.cgContext {
    ctx.saveGState()
    ctx.translateBy(x: side / 2, y: side / 2)
    ctx.setStrokeColor(dark.cgColor)
    ctx.setLineCap(.round)

    ctx.setLineWidth(46)
    ctx.beginPath()
    ctx.move(to: CGPoint(x: 0, y: 0))
    ctx.addLine(to: CGPoint(x: 0, y: 150)) // hour hand (up)
    ctx.strokePath()

    ctx.setLineWidth(34)
    ctx.beginPath()
    ctx.move(to: CGPoint(x: 0, y: 0))
    ctx.addLine(to: CGPoint(x: 245, y: 0)) // minute hand (right)
    ctx.strokePath()

    ctx.restoreGState()
}

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
