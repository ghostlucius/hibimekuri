import SwiftUI

/// Renders headings, lists, blockquotes, and code blocks with real visual
/// structure — bigger/bolder headers, bulleted/numbered lists, indented
/// quotes, monospaced code — on top of the inline formatting (bold/italic/
/// strikethrough/code span/links) `Text` already applies automatically from
/// parsed Markdown. Foundation's `.full` parser only exposes block
/// structure as metadata (`presentationIntent`); it doesn't turn that into
/// any visual effect on its own, so this walks the parsed runs and applies
/// fonts/prefixes/spacing by hand. Deliberately scoped to what
/// markdownguide.org's "basic syntax" page covers minus tables/images/HTML
/// (not attempted) — this is the extended layout's NOTE field, which has
/// the room for real Markdown; the compact memo and inline task notes stay
/// simple/inline-only on purpose.
private enum ListKind { case ordered, unordered }

enum BlockMarkdownRenderer {
    static func render(_ text: String) -> AttributedString {
        let fullOptions = AttributedString.MarkdownParsingOptions(interpretedSyntax: .full)
        guard let parsed = try? AttributedString(markdown: text, options: fullOptions) else {
            return fallbackInline(text)
        }

        var result = AttributedString()
        var previousBlockID: Int?
        var previousListID: Int?
        var markedBlockID: Int?

        for run in parsed.runs {
            var slice = AttributedString(parsed[run.range])
            let components = run.presentationIntent?.components ?? []

            let blockID = components.first?.identity
            let currentListID = outerListIdentity(components)

            if let level = headerLevel(components) {
                slice.font = headerFont(level: level)
            }

            if isCodeBlock(components) {
                // Code block content comes as one run with its own trailing
                // "\n" already baked in by the parser (a parsing artifact,
                // not meaningful vertical space) — trimmed here so the
                // blank-line separator added below doesn't double up into
                // two blank lines before whatever follows.
                var codeText = String(slice.characters)
                while codeText.hasSuffix("\n") { codeText.removeLast() }
                slice = AttributedString(codeText)
                slice.font = .system(size: 11, design: .monospaced)
            }

            if isBlockQuote(components) {
                slice.foregroundColor = .secondary
            }

            // New block: a blank line between blocks in general, but just a
            // single line break between sibling items of the *same* list —
            // otherwise every list item would read as its own paragraph
            // with a full blank line between, which doesn't read as a list.
            if let previousBlockID, blockID != previousBlockID {
                let sameList = currentListID != nil && currentListID == previousListID
                result += AttributedString(sameList ? "\n" : "\n\n")
            }

            // Only prepend the bullet/number/quote-mark once, on the first
            // run of its block — a list item or quote line is usually made
            // of several runs (its own inline bold/italic spans), and this
            // must not repeat the marker for each of those.
            if blockID != markedBlockID {
                if let ordinal = listOrdinal(components), let kind = nearestListKind(components) {
                    let depth = listNestingDepth(components)
                    let indent = String(repeating: "   ", count: max(0, depth - 1))
                    let marker = kind == .ordered ? "\(indent)\(ordinal). " : "\(indent)• "
                    result += AttributedString(marker)
                } else if isBlockQuote(components) {
                    var quoteMark = AttributedString("❝ ")
                    quoteMark.foregroundColor = .secondary
                    result += quoteMark
                }
                markedBlockID = blockID
            }

            result += slice
            previousBlockID = blockID
            previousListID = currentListID
        }

        return result
    }

    private static func headerLevel(_ components: [PresentationIntent.IntentType]) -> Int? {
        for component in components {
            if case let .header(level) = component.kind { return level }
        }
        return nil
    }

    private static func listOrdinal(_ components: [PresentationIntent.IntentType]) -> Int? {
        for component in components {
            if case let .listItem(ordinal) = component.kind { return ordinal }
        }
        return nil
    }

    /// The *nearest* enclosing list's kind, not just "is there an ordered
    /// list anywhere in the ancestor chain" — a `.contains` check on the
    /// whole chain gave a bulleted sub-list nested inside a numbered list
    /// numbers instead of bullets, because the outer numbered list was
    /// still "in the chain" even though it isn't the list this item
    /// actually belongs to. Components are ordered innermost-first, so the
    /// first list kind encountered is the correct, immediate one.
    private static func nearestListKind(_ components: [PresentationIntent.IntentType]) -> ListKind? {
        for component in components {
            switch component.kind {
            case .orderedList: return .ordered
            case .unorderedList: return .unordered
            default: continue
            }
        }
        return nil
    }

    private static func isCodeBlock(_ components: [PresentationIntent.IntentType]) -> Bool {
        components.contains { if case .codeBlock = $0.kind { return true }; return false }
    }

    private static func isBlockQuote(_ components: [PresentationIntent.IntentType]) -> Bool {
        components.contains { if case .blockQuote = $0.kind { return true }; return false }
    }

    private static func listNestingDepth(_ components: [PresentationIntent.IntentType]) -> Int {
        components.filter {
            if case .orderedList = $0.kind { return true }
            if case .unorderedList = $0.kind { return true }
            return false
        }.count
    }

    private static func outerListIdentity(_ components: [PresentationIntent.IntentType]) -> Int? {
        for component in components {
            switch component.kind {
            case .orderedList, .unorderedList:
                return component.identity
            default:
                continue
            }
        }
        return nil
    }

    private static func headerFont(level: Int) -> Font {
        switch level {
        case 1: return .system(size: 17, weight: .bold)
        case 2: return .system(size: 15, weight: .bold)
        default: return .system(size: 13, weight: .semibold)
        }
    }

    private static func fallbackInline(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}
