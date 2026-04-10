#!/usr/bin/env swift
// Generates a DMG background image with a gradient, arrow, and label.
// Usage: swift create-dmg-background.swift <output-path> <width> <height>

import Cocoa

let args = CommandLine.arguments
guard args.count >= 4,
      let width = Int(args[2]),
      let height = Int(args[3]) else {
    print("Usage: swift create-dmg-background.swift <output.png> <width> <height>")
    exit(1)
}

let outputPath = args[1]
let size = CGSize(width: width, height: height)

guard let ctx = CGContext(
    data: nil,
    width: width,
    height: height,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
) else {
    print("Failed to create CGContext")
    exit(1)
}

// -- Background gradient (dark indigo to charcoal) --
let gradientColors = [
    CGColor(red: 0.09, green: 0.09, blue: 0.15, alpha: 1.0),
    CGColor(red: 0.12, green: 0.11, blue: 0.20, alpha: 1.0),
    CGColor(red: 0.09, green: 0.09, blue: 0.14, alpha: 1.0),
] as CFArray

let gradient = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: gradientColors,
    locations: [0.0, 0.5, 1.0]
)!

ctx.drawLinearGradient(
    gradient,
    start: CGPoint(x: 0, y: CGFloat(height)),
    end: CGPoint(x: CGFloat(width), y: 0),
    options: []
)

// -- Subtle grid pattern --
ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.02))
ctx.setLineWidth(0.5)
let gridSpacing: CGFloat = 30
for x in stride(from: 0, through: CGFloat(width), by: gridSpacing) {
    ctx.move(to: CGPoint(x: x, y: 0))
    ctx.addLine(to: CGPoint(x: x, y: CGFloat(height)))
}
for y in stride(from: 0, through: CGFloat(height), by: gridSpacing) {
    ctx.move(to: CGPoint(x: 0, y: y))
    ctx.addLine(to: CGPoint(x: CGFloat(width), y: y))
}
ctx.strokePath()

// -- Glow circles behind icon positions --
let leftCenter = CGPoint(x: CGFloat(width) * 0.28, y: CGFloat(height) * 0.48)
let rightCenter = CGPoint(x: CGFloat(width) * 0.72, y: CGFloat(height) * 0.48)

func drawGlow(at center: CGPoint, color: CGColor, radius: CGFloat) {
    let glowColors = [
        color,
        CGColor(red: 0, green: 0, blue: 0, alpha: 0),
    ] as CFArray
    let glow = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: glowColors,
        locations: [0.0, 1.0]
    )!
    ctx.drawRadialGradient(
        glow,
        startCenter: center, startRadius: 0,
        endCenter: center, endRadius: radius,
        options: []
    )
}

drawGlow(at: leftCenter, color: CGColor(red: 0.39, green: 0.4, blue: 0.95, alpha: 0.08), radius: 120)
drawGlow(at: rightCenter, color: CGColor(red: 0.39, green: 0.4, blue: 0.95, alpha: 0.06), radius: 120)

// -- Arrow in the center --
let arrowY = CGFloat(height) * 0.48
let arrowLeft = CGFloat(width) * 0.41
let arrowRight = CGFloat(width) * 0.59
let arrowHeadSize: CGFloat = 12
let arrowMid = (arrowLeft + arrowRight) / 2

// Arrow shaft
ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.25))
ctx.setLineWidth(2.0)
ctx.setLineCap(.round)

// Dashed line
let dashPattern: [CGFloat] = [6, 4]
ctx.setLineDash(phase: 0, lengths: dashPattern)
ctx.move(to: CGPoint(x: arrowLeft, y: arrowY))
ctx.addLine(to: CGPoint(x: arrowRight - arrowHeadSize, y: arrowY))
ctx.strokePath()

// Arrow head (solid)
ctx.setLineDash(phase: 0, lengths: [])
ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.25))
ctx.move(to: CGPoint(x: arrowRight, y: arrowY))
ctx.addLine(to: CGPoint(x: arrowRight - arrowHeadSize * 1.5, y: arrowY - arrowHeadSize * 0.7))
ctx.addLine(to: CGPoint(x: arrowRight - arrowHeadSize * 1.5, y: arrowY + arrowHeadSize * 0.7))
ctx.closePath()
ctx.fillPath()

// -- Text labels --
func drawText(_ text: String, at point: CGPoint, fontSize: CGFloat, alpha: CGFloat, bold: Bool = false) {
    let font: NSFont
    if bold {
        font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
    } else {
        font = NSFont.systemFont(ofSize: fontSize, weight: .regular)
    }
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor(white: 1.0, alpha: alpha),
    ]
    let str = NSAttributedString(string: text, attributes: attrs)
    let line = CTLineCreateWithAttributedString(str)
    let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)

    ctx.saveGState()
    // CoreGraphics has flipped Y for text, so we transform
    ctx.textMatrix = CGAffineTransform(scaleX: 1, y: 1)
    ctx.textPosition = CGPoint(
        x: point.x - bounds.width / 2,
        y: point.y - bounds.height / 2
    )
    CTLineDraw(line, ctx)
    ctx.restoreGState()
}

// Label below left icon area
let labelY = CGFloat(height) * 0.22
drawText("Markdown Viewer", at: CGPoint(x: leftCenter.x, y: labelY), fontSize: 13, alpha: 0.5, bold: true)

// Label below right icon area
drawText("Applications", at: CGPoint(x: rightCenter.x, y: labelY), fontSize: 13, alpha: 0.5, bold: true)

// Instruction text at bottom
drawText("Arraste para instalar", at: CGPoint(x: CGFloat(width) / 2, y: CGFloat(height) * 0.10), fontSize: 11, alpha: 0.3)

// -- Save --
guard let image = ctx.makeImage() else {
    print("Failed to create image")
    exit(1)
}

let url = URL(fileURLWithPath: outputPath)
guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
    print("Failed to create image destination")
    exit(1)
}
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else {
    print("Failed to write image")
    exit(1)
}
print("Background image saved to \(outputPath)")
