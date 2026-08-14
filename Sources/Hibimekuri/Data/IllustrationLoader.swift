import AppKit
import Foundation

/// Loads a theme illustration as a **pre-rasterized bitmap**, off the main
/// thread, and caches it.
///
/// Why not just hand SwiftUI the SVG-backed `NSImage` (what
/// `DiaryIllustrationView` used to do): AppKit caches a vector image's
/// rasterization *per drawn size*, and that view draws at the live
/// `GeometryReader` size — so every distinct window width/height during a
/// resize is a fresh rasterization of a ~1.1 MB, 14k-line vector. Measured
/// on this Mac against the real asset:
///
/// - first rasterize at a given size: ~160 ms
/// - redraw at the *same* size: ~0.3 ms (AppKit's per-size cache hit)
/// - redraw at a *different* size: ~100–119 ms (cache miss, all over again)
/// - redraw of an already-rasterized **bitmap** at any size: ~3–5 ms
///
/// That per-size cost is what made expanding into the extended layout stall
/// for ~190 ms before the crossfade could even start (reading as a "pause,
/// then a stiff animation"), and made live resizing lurch — it was
/// re-rasterizing continuously as the width changed. Rasterizing once, at
/// the source's intrinsic resolution, and letting SwiftUI scale that bitmap
/// takes the cost out of the resize path entirely.
///
/// Rasterizing at intrinsic size (1254×1254 ≈ 6 MB) rather than 2× for
/// retina is a deliberate trade: this is a heavily edge-masked background
/// watermark (see `DiaryIllustrationView`'s gradient masks), not detail
/// anyone reads, so a slight upscale softness is invisible while 2× would
/// be ~25 MB per cached variant.
@MainActor
enum IllustrationLoader {
    private static var cache: [String: NSImage] = [:]
    /// Least-recently-used first. Five themes × light/dark = 10 possible
    /// variants, but only the current theme's two are ever in play in
    /// practice — this just stops a user clicking through every theme from
    /// pinning all ten bitmaps in memory at once.
    private static var recentlyUsed: [String] = []
    private static let cacheLimit = 3

    /// Already-rasterized and ready to draw this frame, or nil if it still
    /// needs loading.
    static func cached(_ name: String) -> NSImage? {
        cache[name]
    }

    static func load(_ name: String) async -> NSImage? {
        if let hit = cache[name] {
            markUsed(name)
            return hit
        }
        let rasterized = await Task.detached(priority: .userInitiated) {
            rasterize(named: name)
        }.value
        guard let rasterized else { return nil }
        cache[name] = rasterized
        markUsed(name)
        return rasterized
    }

    /// Fire-and-forget warm-up so the first expand into the extended layout
    /// finds the bitmap already built instead of waiting on it.
    static func warm(_ name: String?) {
        guard let name, cache[name] == nil else { return }
        Task { _ = await load(name) }
    }

    private static func markUsed(_ name: String) {
        recentlyUsed.removeAll { $0 == name }
        recentlyUsed.append(name)
        while recentlyUsed.count > cacheLimit, let oldest = recentlyUsed.first {
            recentlyUsed.removeFirst()
            cache.removeValue(forKey: oldest)
        }
    }

    /// Runs off the main actor — `NSGraphicsContext.current` is thread-local,
    /// so drawing into a private bitmap rep here touches no shared UI state.
    nonisolated private static func rasterize(named name: String) -> NSImage? {
        guard let url = Bundle.module.url(forResource: name, withExtension: "svg"),
              let vector = NSImage(contentsOf: url) else { return nil }

        let size = vector.size
        guard size.width > 0, size.height > 0,
              let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: Int(size.width),
                pixelsHigh: Int(size.height),
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
              ) else { return nil }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        vector.draw(in: NSRect(origin: .zero, size: size))
        NSGraphicsContext.restoreGraphicsState()

        let bitmap = NSImage(size: size)
        bitmap.addRepresentation(rep)
        return bitmap
    }
}
