import SwiftUI

enum DS {
    static let numeralFont = Font.system(size: 180, weight: .black, design: .default)
    static let smallCaption = Font.system(size: 11, weight: .medium, design: .default)
    static let hairline = Color.primary.opacity(0.18)
    static let paper = Color(nsColor: .textBackgroundColor)
    // Task rows' own selection highlight — deliberately not using List's
    // native selection binding at all (see TaskListView.swift), since its
    // active-state color is raw NSTableView drawing that neither `.tint()`
    // nor `.listItemTint()` can override on macOS, always showing the
    // user's system accent color regardless. This is a plain background
    // color under our own control instead.
    static let selection = Color.primary.opacity(0.06)
}

/// Renders a short string as stacked single-character lines, mimicking
/// vertical Japanese calendar typography (e.g. 火/曜/日).
struct VerticalText: View {
    let text: String
    var font: Font = .system(size: 20, weight: .bold)

    var body: some View {
        VStack(spacing: 2) {
            ForEach(Array(text.enumerated()), id: \.offset) { _, ch in
                Text(String(ch))
                    .font(font)
            }
        }
    }
}

struct HairlineDivider: View {
    var body: some View {
        Rectangle()
            .fill(DS.hairline)
            .frame(height: 1)
    }
}
