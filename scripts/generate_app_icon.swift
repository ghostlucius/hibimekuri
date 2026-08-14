#!/usr/bin/env swift
import AppKit

// Generates the two neutral app icon variants (Light/Dark) at every size
// macOS's .iconset format needs, then packs each into a .icns via iconutil.
// No Xcode/Icon Composer available in this environment, so this draws the
// icon directly with AppKit/CoreGraphics instead — a rounded-square paper
// tile, a compact brand glyph, and a small folded (dog-ear) corner to read as a torn
// calendar page. Run once at build/design time, not part of the app itself;
// output lands in AppIcon/AppIcon.icns and AppIcon/AppIconDark.icns.
//
// This is the *static* icon only — Finder/Launchpad/before-first-launch,
// where nothing is running to draw a live date. The actual running app
// overwrites its Dock tile with today's real day number instead (see
// AppIconManager.swift), so this one shows 日々 ("hibi" — days/everyday
// life), the compact mark for Hibimekuri / 日々めくり, rather than a numeral
// that would just look stale sitting in Launchpad.

struct Theme {
    let name: String
    let background: NSColor
    let numeral: NSColor
    let fold: NSColor
    let crease: NSColor
}

let lightTheme = Theme(
    name: "AppIcon",
    background: NSColor(calibratedRed: 0.973, green: 0.961, blue: 0.937, alpha: 1),
    numeral: NSColor(calibratedRed: 0.10, green: 0.09, blue: 0.08, alpha: 1),
    fold: NSColor(calibratedRed: 0.894, green: 0.875, blue: 0.827, alpha: 1),
    crease: NSColor(calibratedRed: 0.788, green: 0.761, blue: 0.694, alpha: 1)
)

let darkTheme = Theme(
    name: "AppIconDark",
    background: NSColor(calibratedWhite: 0.11, alpha: 1),
    numeral: NSColor(calibratedRed: 0.961, green: 0.957, blue: 0.941, alpha: 1),
    fold: NSColor(calibratedWhite: 0.18, alpha: 1),
    crease: NSColor(calibratedWhite: 0.24, alpha: 1)
)

let iconSetSizes: [(name: String, points: CGFloat, scale: CGFloat)] = [
    ("icon_16x16", 16, 1), ("icon_16x16@2x", 16, 2),
    ("icon_32x32", 32, 1), ("icon_32x32@2x", 32, 2),
    ("icon_128x128", 128, 1), ("icon_128x128@2x", 128, 2),
    ("icon_256x256", 256, 1), ("icon_256x256@2x", 256, 2),
    ("icon_512x512", 512, 1), ("icon_512x512@2x", 512, 2),
]

func drawIcon(size: CGFloat, theme: Theme) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    // macOS icons carry built-in breathing room — the visible glyph is
    // roughly 80% of the canvas, centered, with transparent margin around
    // it (Apple's own icons, and every other Dock icon, work this way).
    // Drawing the rounded-square edge-to-edge in the full canvas (the
    // original version of this script) made this icon look noticeably
    // larger/bolder than its neighbors in the Dock.
    let contentScale: CGFloat = 0.80
    let contentSize = size * contentScale
    let inset = (size - contentSize) / 2

    // Rounded-square base, matching macOS's ~22% corner-radius convention,
    // sized to the inset content area, not the full canvas.
    let radius = contentSize * 0.224
    let rect = NSRect(x: inset, y: inset, width: contentSize, height: contentSize)
    let base = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    theme.background.setFill()
    base.fill()

    // Big bold glyph, centered within the content area. Two compact kanji
    // read better slightly smaller than a one-character mark, especially at
    // tiny Finder sizes.
    let glyphFont = NSFont.systemFont(ofSize: contentSize * 0.34, weight: .black)
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [
        .font: glyphFont,
        .foregroundColor: theme.numeral,
        .paragraphStyle: paragraph,
    ]
    let numeral = NSAttributedString(string: "日々", attributes: attrs)
    let textSize = numeral.size()
    let textRect = NSRect(
        x: inset + (contentSize - textSize.width) / 2,
        y: inset + (contentSize - textSize.height) / 2 - contentSize * 0.02,
        width: textSize.width,
        height: textSize.height
    )
    numeral.draw(in: textRect)

    // Folded page corner (dog-ear), inset from the rounded corner so it
    // reads as a fold detail rather than fighting the base shape's own
    // rounding. All coordinates relative to the content rect's own corner
    // (inset, inset)...(inset+contentSize, inset+contentSize), not the
    // full canvas.
    let margin = contentSize * 0.07
    let foldSize = contentSize * 0.24
    let p1 = NSPoint(x: inset + contentSize - margin, y: inset + margin + foldSize) // up the right edge
    let p2 = NSPoint(x: inset + contentSize - margin, y: inset + margin)            // corner
    let p3 = NSPoint(x: inset + contentSize - margin - foldSize, y: inset + margin) // along the bottom edge
    let fold = NSBezierPath()
    fold.move(to: p1)
    fold.line(to: p2)
    fold.line(to: p3)
    fold.close()
    theme.fold.setFill()
    fold.fill()

    let crease = NSBezierPath()
    crease.move(to: p1)
    crease.line(to: p3)
    theme.crease.setStroke()
    crease.lineWidth = max(1, contentSize * 0.006)
    crease.stroke()

    image.unlockFocus()
    return image
}

func pngData(_ image: NSImage, size: CGFloat) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size), pixelsHigh: Int(size),
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: size, height: size)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let projectRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent()
let outputDir = projectRoot.appendingPathComponent("AppIcon")
try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

for theme in [lightTheme, darkTheme] {
    let iconsetDir = outputDir.appendingPathComponent("\(theme.name).iconset")
    try? FileManager.default.removeItem(at: iconsetDir)
    try! FileManager.default.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

    for entry in iconSetSizes {
        let pixelSize = entry.points * entry.scale
        let image = drawIcon(size: pixelSize, theme: theme)
        let data = pngData(image, size: pixelSize)
        let fileURL = iconsetDir.appendingPathComponent("\(entry.name).png")
        try! data.write(to: fileURL)
    }

    let icnsURL = outputDir.appendingPathComponent("\(theme.name).icns")
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    process.arguments = ["-c", "icns", iconsetDir.path, "-o", icnsURL.path]
    try! process.run()
    process.waitUntilExit()

    // Also keep a 1024 PNG preview alongside, handy for eyeballing without
    // opening the .icns.
    let preview = drawIcon(size: 1024, theme: theme)
    try! pngData(preview, size: 1024).write(to: outputDir.appendingPathComponent("\(theme.name)-preview.png"))

    try? FileManager.default.removeItem(at: iconsetDir)

    print("Generated \(icnsURL.path)")
}
