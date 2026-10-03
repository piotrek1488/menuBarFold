import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("usage: generate_icon.swift <resources-directory>\n", stderr)
    exit(2)
}

let resourcesDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let iconsetDirectory = resourcesDirectory.appendingPathComponent("MenuBarFold.iconset", isDirectory: true)
let fileManager = FileManager.default

try? fileManager.removeItem(at: iconsetDirectory)
try fileManager.createDirectory(at: iconsetDirectory, withIntermediateDirectories: true)

let variants: [(fileName: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1_024)
]

for variant in variants {
    let pixels = variant.pixels
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "MenuBarFold.Icon", code: 1)
    }

    bitmap.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

    let scale = CGFloat(pixels) / 1_024
    NSGraphicsContext.current?.cgContext.scaleBy(x: scale, y: scale)

    let background = NSBezierPath(
        roundedRect: NSRect(x: 72, y: 72, width: 880, height: 880),
        xRadius: 210,
        yRadius: 210
    )
    NSGradient(
        starting: NSColor(calibratedRed: 0.20, green: 0.42, blue: 0.98, alpha: 1),
        ending: NSColor(calibratedRed: 0.48, green: 0.22, blue: 0.88, alpha: 1)
    )?.draw(in: background, angle: -45)

    let menuBar = NSBezierPath(
        roundedRect: NSRect(x: 190, y: 580, width: 644, height: 142),
        xRadius: 71,
        yRadius: 71
    )
    NSColor.white.withAlphaComponent(0.94).setFill()
    menuBar.fill()

    for x in [260, 350, 440] {
        let dot = NSBezierPath(ovalIn: NSRect(x: x, y: 633, width: 36, height: 36))
        NSColor(calibratedRed: 0.30, green: 0.35, blue: 0.55, alpha: 0.50).setFill()
        dot.fill()
    }

    let divider = NSBezierPath(
        roundedRect: NSRect(x: 535, y: 612, width: 18, height: 78),
        xRadius: 9,
        yRadius: 9
    )
    NSColor(calibratedRed: 0.26, green: 0.31, blue: 0.52, alpha: 0.65).setFill()
    divider.fill()

    let chevron = NSBezierPath()
    chevron.move(to: NSPoint(x: 690, y: 686))
    chevron.line(to: NSPoint(x: 635, y: 651))
    chevron.line(to: NSPoint(x: 690, y: 616))
    chevron.lineWidth = 22
    chevron.lineCapStyle = .round
    chevron.lineJoinStyle = .round
    NSColor(calibratedRed: 0.26, green: 0.31, blue: 0.52, alpha: 0.85).setStroke()
    chevron.stroke()

    let fold = NSBezierPath(
        roundedRect: NSRect(x: 278, y: 335, width: 468, height: 106),
        xRadius: 53,
        yRadius: 53
    )
    NSColor.white.withAlphaComponent(0.84).setFill()
    fold.fill()

    let hidden = NSBezierPath(
        roundedRect: NSRect(x: 278, y: 335, width: 250, height: 106),
        xRadius: 53,
        yRadius: 53
    )
    NSColor.white.withAlphaComponent(0.28).setFill()
    hidden.fill()

    NSGraphicsContext.restoreGraphicsState()

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "MenuBarFold.Icon", code: 2)
    }
    try png.write(to: iconsetDirectory.appendingPathComponent(variant.fileName))
}
