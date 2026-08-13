import SwiftUI
import AppKit

/// Fills the space that opens up below the quote/literature section in the
/// extended layout with the active theme's illustration, cropped to fill
/// (not letterboxed). Every theme recolors the same source mountain/pagoda
/// vector (`Art/fuji-pagoda-detailed-handdrawn-vector.svg`, a single fill
/// color swapped per theme/mode — see `DiaryTheme.definition`), the same
/// way Matcha's original two variants were made.
///
/// This view is only ever mounted inside `ExtendedPageView` — compact mode
/// never creates it at all. It fades in via a **covering scrim**, not by
/// animating the image's own opacity: a plain `Color` (the page's own
/// background) sits on top of the image and animates from fully opaque to
/// fully transparent, gradually revealing the image underneath. This reads
/// identically to a real opacity fade, but sidesteps a real bug found by
/// isolated testing — `GeometryReader` wrapping an `Image(nsImage:)` (an
/// NSImage-backed image, needed here since this package has no asset
/// catalog to load through `Image("name")`) simply does not animate
/// `.opacity()` applied to it: three different triggering mechanisms
/// (inheriting the ancestor's insertion transition, `withAnimation` in
/// `onAppear`, and an explicit `.animation(_, value:)`) were all confirmed,
/// via a temporary debug harness with an artificially slow 3-second
/// duration, to render the image at full opacity almost immediately
/// instead of animating. The same harness confirmed a plain `Color` DOES
/// animate correctly under the exact same trigger — the bug is specific to
/// this `GeometryReader`+`Image(nsImage:)` combination, not the animation
/// code. The `GeometryReader` itself can't be removed — it's what makes
/// `.aspectRatio(.fill)` size correctly against this view's flexible
/// parent frame (see the sizing comment below).
struct DiaryIllustrationView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false

    var body: some View {
        Group {
            if let name = themeManager.illustrationName, let nsImage = Self.loadSVG(named: name) {
                // `.aspectRatio(.fill)` alone doesn't reliably negotiate a
                // size when its parent offers a flexible (`maxHeight:
                // .infinity`) proposal — confirmed by testing at a tall
                // window height, where the image quietly stopped short of
                // the bottom edge instead of covering it, even though the
                // exact same setup filled correctly at a shorter height.
                // Measuring the available rect explicitly and handing the
                // image its exact target size removes that ambiguity.
                GeometryReader { proxy in
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        // A hard-edged rectangle reads as a photo pasted
                        // onto the page, especially where it meets the
                        // quote card above and the pane's side edges at
                        // narrower extended widths. Fading opacity toward
                        // each edge lets the page's own background show
                        // through at the boundary instead, so it dissolves
                        // into the page like a watermark rather than being
                        // visibly cropped. Two chained `.mask()` calls
                        // multiply together (vertical fade × horizontal
                        // fade), softening all four edges at once without
                        // needing a single combined gradient shape.
                        .mask(
                            LinearGradient(
                                stops: [
                                    .init(color: .black.opacity(0), location: 0),
                                    .init(color: .black, location: 0.22),
                                    .init(color: .black, location: 1)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .mask(
                            LinearGradient(
                                stops: [
                                    .init(color: .black.opacity(0), location: 0),
                                    .init(color: .black, location: 0.12),
                                    .init(color: .black, location: 0.88),
                                    .init(color: .black.opacity(0), location: 1)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                // The fade-in scrim sits OUTSIDE the GeometryReader as a
                // sibling overlay, not nested inside it — nesting it
                // inside (tried first) hit the exact same animation bug
                // as the image itself: a plain `Color`, once placed
                // inside this `GeometryReader`'s content, stopped
                // animating opacity too. Applied here, from outside, it's
                // a normal `Color` in a normal (non-`GeometryReader`)
                // context — confirmed to animate correctly, matching the
                // isolated test that found the bug in the first place.
                .overlay(DS.paper.opacity(isVisible ? 0 : 1))
                .allowsHitTesting(false)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.5), value: isVisible)
                .onAppear {
                    isVisible = reduceMotion
                    // Deferred to the next run loop tick rather than set
                    // directly: this view's insertion happens inside the
                    // ancestor's own insertion transition (the whole
                    // extended pane fading in), and a state change made
                    // synchronously inside `onAppear` while that outer
                    // transaction is still active can get folded into it
                    // instead of running as its own independent animation.
                    DispatchQueue.main.async {
                        isVisible = true
                    }
                }
                .onDisappear {
                    isVisible = false
                }
                .accessibilityHidden(true)
            }
        }
    }

    private static var cache: [String: NSImage] = [:]

    private static func loadSVG(named name: String) -> NSImage? {
        if let cached = cache[name] { return cached }
        guard let url = Bundle.module.url(forResource: name, withExtension: "svg"),
              let image = NSImage(contentsOf: url) else { return nil }
        cache[name] = image
        return image
    }
}
