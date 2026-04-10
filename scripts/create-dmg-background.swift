#!/usr/bin/env swift
// Generates a DMG background image with a gradient, arrow, labels, and the real app icon.
// Usage: swift create-dmg-background.swift <output-path> <width> <height> [icon-path]

import Cocoa
import CoreGraphics
import ImageIO

let args = CommandLine.arguments
guard args.count >= 4,
      let width  = Int(args[2]),
      let height = Int(args[3]) else {
    print("Usage: swift create-dmg-background.swift <output.png> <width> <height> [icon.png]")
    exit(1)
}

let outputPath = args[1]
let iconPath   = args.count >= 5 ? args[4] : nil

// ──────────────────────────────────────────────
// Canvas
// ──────────────────────────────────────────────
guard let ctx = CGContext(
    data: nil,
    width: width,
    height: height,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
) else { print("Failed to create CGContext"); exit(1) }

// ──────────────────────────────────────────────
// Background gradient (dark indigo → charcoal)
// ──────────────────────────────────────────────
let bgColors = [
    CGColor(red: 0.08, green: 0.08, blue: 0.14, alpha: 1.0),
    CGColor(red: 0.11, green: 0.10, blue: 0.19, alpha: 1.0),
    CGColor(red: 0.08, green: 0.08, blue: 0.13, alpha: 1.0),
] as CFArray
let bg = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: bgColors, locations: [0.0, 0.5, 1.0])!
ctx.drawLinearGradient(bg,
    start: CGPoint(x: 0, y: CGFloat(height)),
    end:   CGPoint(x: CGFloat(width), y: 0),
    options: [])

// ──────────────────────────────────────────────
// Subtle grid
// ──────────────────────────────────────────────
ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.025))
ctx.setLineWidth(0.5)
let grid: CGFloat = 30
for x in stride(from: CGFloat(0), through: CGFloat(width), by: grid) {
    ctx.move(to: CGPoint(x: x, y: 0)); ctx.addLine(to: CGPoint(x: x, y: CGFloat(height)))
}
for y in stride(from: CGFloat(0), through: CGFloat(height), by: grid) {
    ctx.move(to: CGPoint(x: 0, y: y)); ctx.addLine(to: CGPoint(x: CGFloat(width), y: y))
}
ctx.strokePath()

// ──────────────────────────────────────────────
// Icon positions
// ──────────────────────────────────────────────
let leftCX  = CGFloat(width)  * 0.28
let rightCX = CGFloat(width)  * 0.72
let iconCY  = CGFloat(height) * 0.50   // vertical centre of icon area
let iconSize: CGFloat = 128

// Radial glows
func radialGlow(at centre: CGPoint, color: CGColor, radius: CGFloat) {
    let glowColors = [color, CGColor(red: 0, green: 0, blue: 0, alpha: 0)] as CFArray
    let glow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                          colors: glowColors, locations: [0.0, 1.0])!
    ctx.drawRadialGradient(glow,
        startCenter: centre, startRadius: 0,
        endCenter:   centre, endRadius: radius,
        options: [])
}
radialGlow(at: CGPoint(x: leftCX,  y: iconCY), color: CGColor(red: 0.39, green: 0.4, blue: 0.95, alpha: 0.12), radius: 140)
radialGlow(at: CGPoint(x: rightCX, y: iconCY), color: CGColor(red: 0.39, green: 0.4, blue: 0.95, alpha: 0.07), radius: 130)

// ──────────────────────────────────────────────
// App icon (left slot) – use real PNG if provided
// ──────────────────────────────────────────────
if let iconPath, let iconURL = URL(string: "file://\(iconPath)"),
   let imgSrc  = CGImageSourceCreateWithURL(iconURL as CFURL, nil),
   let appIcon = CGImageSourceCreateImageAtIndex(imgSrc, 0, nil) {

    let iconRect = CGRect(
        x: leftCX - iconSize / 2,
        y: iconCY - iconSize / 2,
        width: iconSize, height: iconSize)

    // Soft shadow behind icon
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -4), blur: 16,
                  color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.5))
    // Rounded-rect clip for the icon (macOS squircle approx)
    let cornerR = iconSize * 0.225
    let path = CGPath(roundedRect: iconRect, cornerWidth: cornerR, cornerHeight: cornerR, transform: nil)
    ctx.addPath(path); ctx.clip()
    ctx.drawImage(appIcon, in: iconRect)
    ctx.restoreGState()

} else {
    // Fallback: plain glow circle
    radialGlow(at: CGPoint(x: leftCX, y: iconCY),
               color: CGColor(red: 0.5, green: 0.5, blue: 1.0, alpha: 0.15), radius: 70)
}

// ──────────────────────────────────────────────
// Applications folder icon (right slot) – system folder glyph
// ──────────────────────────────────────────────
// Draw a simple stylised "folder" shape
let fW: CGFloat = iconSize * 0.85
let fH: CGFloat = fW * 0.75
let fX = rightCX - fW / 2
let fY = iconCY  - fH / 2

ctx.saveGState()
// folder body
let folderPath = CGMutablePath()
let tabH: CGFloat = fH * 0.18
let tabW: CGFloat = fW * 0.38
folderPath.addRoundedRect(in: CGRect(x: fX, y: fY, width: fW, height: fH - tabH),
                          cornerWidth: 8, cornerHeight: 8)
ctx.addPath(folderPath)
ctx.setFillColor(CGColor(red: 0.24, green: 0.50, blue: 0.90, alpha: 0.75))
ctx.fillPath()
// folder tab
let tab = CGMutablePath()
tab.move(to: CGPoint(x: fX + 6, y: fY + fH - tabH))
tab.addLine(to: CGPoint(x: fX + tabW, y: fY + fH - tabH))
tab.addLine(to: CGPoint(x: fX + tabW + 10, y: fY + fH))
tab.addLine(to: CGPoint(x: fX + 6, y: fY + fH))
tab.closeSubpath()
ctx.addPath(tab)
ctx.setFillColor(CGColor(red: 0.28, green: 0.58, blue: 0.97, alpha: 0.80))
ctx.fillPath()
ctx.restoreGState()

// ──────────────────────────────────────────────
// Arrow (left → right, dashed)
// ──────────────────────────────────────────────
let arrowY     = iconCY
let arrowLeft  = CGFloat(width) * 0.415
let arrowRight = CGFloat(width) * 0.585
let headSize: CGFloat = 11

ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.28))
ctx.setLineWidth(2.0)
ctx.setLineCap(.round)
ctx.setLineDash(phase: 0, lengths: [7, 5])
ctx.move(to: CGPoint(x: arrowLeft, y: arrowY))
ctx.addLine(to: CGPoint(x: arrowRight - headSize * 1.2, y: arrowY))
ctx.strokePath()

ctx.setLineDash(phase: 0, lengths: [])
ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.28))
ctx.move(to: CGPoint(x: arrowRight, y: arrowY))
ctx.addLine(to: CGPoint(x: arrowRight - headSize * 1.8, y: arrowY - headSize * 0.7))
ctx.addLine(to: CGPoint(x: arrowRight - headSize * 1.8, y: arrowY + headSize * 0.7))
ctx.closePath()
ctx.fillPath()

// ──────────────────────────────────────────────
// Text labels
// ──────────────────────────────────────────────
func drawCentredText(_ text: String, at point: CGPoint, size: CGFloat, alpha: CGFloat, bold: Bool = false) {
    let font = bold
        ? NSFont.systemFont(ofSize: size, weight: .semibold)
        : NSFont.systemFont(ofSize: size, weight: .regular)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor(white: 1.0, alpha: alpha),
    ]
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attrs))
    let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
    ctx.textMatrix = .identity
    ctx.textPosition = CGPoint(x: point.x - bounds.width / 2, y: point.y - bounds.height / 2)
    CTLineDraw(line, ctx)
}

let labelY = CGFloat(height) * 0.20
drawCentredText("Markdown Viewer", at: CGPoint(x: leftCX,  y: labelY), size: 13, alpha: 0.55, bold: true)
drawCentredText("Applications",    at: CGPoint(x: rightCX, y: labelY), size: 13, alpha: 0.55, bold: true)
drawCentredText("Arraste para instalar", at: CGPoint(x: CGFloat(width) / 2, y: CGFloat(height) * 0.09),
                size: 11, alpha: 0.30)

// ──────────────────────────────────────────────
// Save PNG
// ──────────────────────────────────────────────
guard let image = ctx.makeImage() else { print("Failed to create image"); exit(1) }
let destURL = URL(fileURLWithPath: outputPath)
guard let dest = CGImageDestinationCreateWithURL(destURL as CFURL, "public.png" as CFString, 1, nil)
else { print("Failed to create destination"); exit(1) }
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else { print("Failed to write image"); exit(1) }
print("✓ Background saved to \(outputPath)")
