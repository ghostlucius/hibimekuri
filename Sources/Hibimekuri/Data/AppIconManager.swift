import SwiftUI
import AppKit

/// Draws the running app's Dock icon live — the actual numeral for today,
/// on the same rounded-tile/folded-corner design as the static bundle icon
/// (`scripts/generate_app_icon.swift`), redrawn in memory each time instead
/// of loading a fixed `.icns`. Tracks resolved appearance (the explicit
/// Light/Dark choice, or the system's own appearance while "System" is
/// selected) and the actual calendar day, so the Dock tile reads as a real
/// tear-off page. This only affects the Dock/Cmd-Tab tile of the *running*
/// app — the static Finder/Launchpad icon (before first launch) stays
/// whichever bundled `.icns` Info.plist's CFBundleIconFile points at, since
/// that one can't be redrawn without the app already running to draw it.
enum AppIconManager {
    private struct Theme {
        let background: NSColor
        let numeral: NSColor
        let fold: NSColor
        let crease: NSColor
    }

    // Kept in sync by eye with scripts/generate_app_icon.swift's themes —
    // both draw the same tile design, just for different content (today's
    // number here, the static 暦 fallback there).
    private static let lightTheme = Theme(
        background: NSColor(calibratedRed: 0.973, green: 0.961, blue: 0.937, alpha: 1),
        numeral: NSColor(calibratedRed: 0.10, green: 0.09, blue: 0.08, alpha: 1),
        fold: NSColor(calibratedRed: 0.894, green: 0.875, blue: 0.827, alpha: 1),
        crease: NSColor(calibratedRed: 0.788, green: 0.761, blue: 0.694, alpha: 1)
    )

    private static let darkTheme = Theme(
        background: NSColor(calibratedWhite: 0.11, alpha: 1),
        numeral: NSColor(calibratedRed: 0.961, green: 0.957, blue: 0.941, alpha: 1),
        fold: NSColor(calibratedWhite: 0.18, alpha: 1),
        crease: NSColor(calibratedWhite: 0.24, alpha: 1)
    )

    private static var dayChangeObserver: NSObjectProtocol?

    /// Call once at launch: paints the icon for right now, then keeps it
    /// rolling over at midnight for as long as the app stays open.
    static func start() {
        applyForCurrentSystemAppearance()
        guard dayChangeObserver == nil else { return }
        // NSCalendarDayChanged (not a manual midnight Timer) also fires
        // correctly across sleep/wake and timezone changes, which a naive
        // "sleep until midnight" timer would miss if the Mac was asleep
        // exactly then.
        dayChangeObserver = NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged, object: nil, queue: .main
        ) { _ in
            applyForCurrentSystemAppearance()
        }
    }

    static func apply(colorScheme: ColorScheme) {
        let theme = colorScheme == .dark ? darkTheme : lightTheme
        NSApp.applicationIconImage = renderIcon(day: currentDayString(), theme: theme)
    }

    static func applyForCurrentSystemAppearance() {
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        apply(colorScheme: isDark ? .dark : .light)
    }

    private static func currentDayString() -> String {
        String(Calendar.current.component(.day, from: Date()))
    }

    private static func renderIcon(day: String, theme: Theme) -> NSImage {
        let canvasSize: CGFloat = 512
        let image = NSImage(size: NSSize(width: canvasSize, height: canvasSize))
        image.lockFocus()

        let contentScale: CGFloat = 0.80
        let contentSize = canvasSize * contentScale
        let inset = (canvasSize - contentSize) / 2

        let radius = contentSize * 0.224
        let rect = NSRect(x: inset, y: inset, width: contentSize, height: contentSize)
        let base = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        theme.background.setFill()
        base.fill()

        // Two-digit days ("31") start a notch smaller than single digits so
        // they sit as comfortably in the tile as "2" does, then the fit
        // loop below is the real guarantee — it keeps shrinking until the
        // drawn width actually fits, rather than trusting the ratio alone.
        var fontSize = contentSize * (day.count > 1 ? 0.40 : 0.52)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        var attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .black),
            .foregroundColor: theme.numeral,
            .paragraphStyle: paragraph,
        ]
        var numeral = NSAttributedString(string: day, attributes: attrs)
        while numeral.size().width > contentSize * 0.86 && fontSize > 10 {
            fontSize *= 0.92
            attrs[.font] = NSFont.systemFont(ofSize: fontSize, weight: .black)
            numeral = NSAttributedString(string: day, attributes: attrs)
        }
        let textSize = numeral.size()
        let textRect = NSRect(
            x: inset + (contentSize - textSize.width) / 2,
            y: inset + (contentSize - textSize.height) / 2 - contentSize * 0.02,
            width: textSize.width,
            height: textSize.height
        )
        numeral.draw(in: textRect)

        // Folded page corner (dog-ear), same as the static icon.
        let margin = contentSize * 0.07
        let foldSize = contentSize * 0.24
        let p1 = NSPoint(x: inset + contentSize - margin, y: inset + margin + foldSize)
        let p2 = NSPoint(x: inset + contentSize - margin, y: inset + margin)
        let p3 = NSPoint(x: inset + contentSize - margin - foldSize, y: inset + margin)
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
}
