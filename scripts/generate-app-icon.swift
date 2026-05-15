#!/usr/bin/env swift

import AppKit
import CoreGraphics
import CoreImage
import Foundation

private let canvas: CGFloat = 1024
private let buildURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent(".build/app-icon", isDirectory: true)
private let resourceURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("Sources/DisplayRecall/Resources", isDirectory: true)
private let iconsetURL = buildURL.appendingPathComponent("AppIcon.iconset", isDirectory: true)

private let plateRect = CGRect(x: 96, y: 96, width: 832, height: 832)
private let plateCornerRadius: CGFloat = 186
private let backgroundTop = NSColor(calibratedRed: 0.04, green: 0.25, blue: 0.36, alpha: 1.0)
private let backgroundBottom = NSColor(calibratedRed: 0.02, green: 0.45, blue: 0.70, alpha: 1.0)
private let symbolColor = NSColor.white

private func makeSymbolImage(size: CGFloat) throws -> NSImage {
    let configuration = NSImage.SymbolConfiguration(pointSize: size, weight: .semibold)
        .applying(.init(paletteColors: [symbolColor]))
    guard let image = NSImage(systemSymbolName: "rectangle.on.rectangle", accessibilityDescription: "Display Recall")?
        .withSymbolConfiguration(configuration) else {
        throw CocoaError(.fileReadUnknown)
    }
    image.isTemplate = false
    return image
}

private func drawIcon(in context: CGContext) throws {
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)

    let background = NSBezierPath(
        roundedRect: plateRect,
        xRadius: plateCornerRadius,
        yRadius: plateCornerRadius
    )

    context.setShadow(
        offset: CGSize(width: 0, height: -22),
        blur: 42,
        color: NSColor.black.withAlphaComponent(0.28).cgColor
    )
    backgroundTop.setFill()
    background.fill()
    context.setShadow(offset: .zero, blur: 0, color: nil)

    background.addClip()

    let gradient = NSGradient(colors: [backgroundTop, backgroundBottom])!
    gradient.draw(in: background, angle: -45)

    NSColor(calibratedWhite: 1.0, alpha: 0.16).setFill()
    NSBezierPath(ovalIn: CGRect(x: -60, y: 700, width: 480, height: 390)).fill()
    NSColor(calibratedWhite: 0.0, alpha: 0.14).setFill()
    NSBezierPath(ovalIn: CGRect(x: 610, y: -20, width: 460, height: 390)).fill()

    let symbol = try makeSymbolImage(size: 460)
    let symbolSize = symbol.size
    let scale = min(520 / symbolSize.width, 470 / symbolSize.height)
    let drawSize = CGSize(width: symbolSize.width * scale, height: symbolSize.height * scale)
    let symbolRect = CGRect(
        x: (canvas - drawSize.width) / 2,
        y: (canvas - drawSize.height) / 2 - 4,
        width: drawSize.width,
        height: drawSize.height
    )

    context.setShadow(offset: CGSize(width: 0, height: -12), blur: 24, color: NSColor.black.withAlphaComponent(0.22).cgColor)
    symbol.draw(in: symbolRect, from: .zero, operation: .sourceOver, fraction: 1.0)

    NSGraphicsContext.restoreGraphicsState()
}

private func renderPNG(pixelSize: Int, to outputURL: URL) throws {
    let width = pixelSize
    let height = pixelSize
    let bytesPerRow = width * 4
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw CocoaError(.fileWriteUnknown)
    }

    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    context.scaleBy(x: CGFloat(pixelSize) / canvas, y: CGFloat(pixelSize) / canvas)
    try drawIcon(in: context)

    guard let image = context.makeImage() else {
        throw CocoaError(.fileWriteUnknown)
    }
    let bitmap = NSBitmapImageRep(cgImage: image)
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    try data.write(to: outputURL, options: .atomic)
}

private func runIconutil() throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    process.arguments = [
        "-c",
        "icns",
        iconsetURL.path,
        "-o",
        resourceURL.appendingPathComponent("AppIcon.icns").path
    ]
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        throw CocoaError(.fileWriteUnknown)
    }
}

try FileManager.default.createDirectory(at: resourceURL, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: buildURL, withIntermediateDirectories: true)
if FileManager.default.fileExists(atPath: iconsetURL.path) {
    try FileManager.default.removeItem(at: iconsetURL)
}
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let svgURL = resourceURL.appendingPathComponent("AppIcon.svg")
if FileManager.default.fileExists(atPath: svgURL.path) {
    try FileManager.default.removeItem(at: svgURL)
}

try renderPNG(pixelSize: 1024, to: resourceURL.appendingPathComponent("AppIcon.png"))

let iconsetFiles: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (fileName, size) in iconsetFiles {
    try renderPNG(pixelSize: size, to: iconsetURL.appendingPathComponent(fileName))
}

try runIconutil()
print(resourceURL.appendingPathComponent("AppIcon.png").path)
