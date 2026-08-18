import SwiftUI
import AppKit

/// Block-level style for a run of text in the rich note editor — headers
/// and blockquote, applied by `RichNoteEditor`'s toolbar to whatever's
/// selected (not auto-expanded to the enclosing line/paragraph; the user
/// selects the line's text first, same as any other formatting action).
/// Bold/italic/strikethrough/links reuse `AttributedString`'s own
/// `.inlinePresentationIntent`/`.link` attributes instead of a custom key,
/// since those already round-trip through Foundation's Markdown parser
/// (`AttributedString(markdown:)`) exactly the way this needs.
enum NoteBlockStyle: String, Codable, Hashable {
    case body, h1, h2, h3, blockquote, code
}

/// Which of the two note editors is showing — real WYSIWYG (no visible
/// Markdown syntax) or the raw Markdown source. Shared by `RichNoteEditor`
/// (whose toolbar behaves differently per mode: attribute changes in
/// `.formatted`, literal Markdown character insertion in `.markdown`),
/// `ExtendedPageView`, and `FocusModeView`.
enum NoteEditorMode {
    case formatted, markdown
}

/// A plain subscript-only custom attribute (`container[NoteBlockStyleKey.self]
/// = .h1`), not the dot-syntax `AttributeScope`/`AttributeDynamicLookup`
/// dance — fewer moving parts for the one custom key this editor needs.
struct NoteBlockStyleKey: AttributedStringKey {
    typealias Value = NoteBlockStyle
    static let name = "com.hibimekuri.noteBlockStyle"
}

/// Fenced-code info strings (for example `swift` in ```swift) do not have a
/// native `AttributedString` equivalent. Keep them alongside the code style so
/// opening formatted mode never silently removes that Markdown metadata.
struct NoteCodeLanguageKey: AttributedStringKey {
    typealias Value = String
    static let name = "com.hibimekuri.noteCodeLanguage"
}

/// Converts between the plain-Markdown `String` `DiaryEntry.journalText` is
/// stored as and the `AttributedString` `RichNoteEditor` edits live. Scoped
/// to what the editor's own toolbar can produce plus what a person would
/// plausibly type by hand in Markdown mode — bold, italic, strikethrough,
/// links, H1–H3, blockquote, bullet/numbered lists, and GitHub-style task
/// list checkboxes (`- [ ]` / `- [x]`, not part of CommonMark so Foundation's
/// own parser treats it as plain text — handled here by hand). Lists render
/// with a literal `"- "` / `"1. "` / `"☐ "` / `"☑ "` prefix, not a live
/// structural list — no auto-continuation on Return, no auto-renumbering —
/// matching `BlockMarkdownRenderer`'s same approach for the read-only
/// preview elsewhere in the app. Not a general Markdown-to-rich-text
/// engine; tables and nested lists fall back to plain body text rather than
/// corrupting it.
enum NoteMarkdown {
    private static let appKitBlockStyleKey = NSAttributedString.Key("com.hibimekuri.noteBlockStyle")
    private static let appKitCodeLanguageKey = NSAttributedString.Key("com.hibimekuri.noteCodeLanguage")
    private static let appKitInlineIntentKey = NSAttributedString.Key("com.hibimekuri.inlinePresentationIntent")
    private static let emptyCodeBlockMarker = "\u{200B}"

    static func parse(_ markdown: String) -> AttributedString {
        guard !markdown.isEmpty else { return AttributedString("") }
        let groups = topLevelGroups(in: markdown)

        // Foundation's Markdown parser intentionally removes blank-line
        // characters, retaining only block metadata. That means it cannot
        // tell a continuous list from two same-kind lists separated by a
        // blank line after the fact. Split before parsing so the formatted
        // editor keeps the writer's visible paragraph/list grouping.
        return groups.reduce(into: AttributedString()) { result, group in
            switch group {
            case .content(let source):
                result += parseGroup(source)
            case .separator(let source):
                result += AttributedString(source)
            }
        }
    }

    private static func parseGroup(_ markdown: String) -> AttributedString {
        if let codeBlock = fencedCodeBlock(in: markdown) {
            // An empty attributed string has no run for AppKit to carry our
            // code-style and language attributes through the live editor.
            // Keep one invisible marker internally, then remove it again
            // while serializing so an empty fence remains exactly empty.
            let contents = codeBlock.contents.isEmpty ? emptyCodeBlockMarker : codeBlock.contents
            var result = AttributedString(contents)
            result.font = .system(size: 11, design: .monospaced)
            result[NoteBlockStyleKey.self] = .code
            if let language = codeBlock.language {
                result[NoteCodeLanguageKey.self] = language
            }
            return result
        }

        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .full)
        guard let parsed = try? AttributedString(markdown: markdown, options: options) else {
            return AttributedString(markdown)
        }

        // First pass: which list-item blocks are checked-off task items, so
        // *every* run belonging to that item (not just its first) gets
        // consistent strikethrough/secondary styling below — an inline bold
        // word inside a checked item shouldn't stay full-color while the
        // rest of the line dims.
        var checkedBlocks: Set<Int> = []
        var uncheckedTaskBlocks: Set<Int> = []
        for run in parsed.runs {
            let components = run.presentationIntent?.components ?? []
            guard listPrefix(components) != nil, let blockID = components.first?.identity else { continue }
            let text = String(parsed[run.range].characters)
            if text.hasPrefix("[x] ") || text.hasPrefix("[X] ") {
                checkedBlocks.insert(blockID)
            } else if text.hasPrefix("[ ] ") {
                uncheckedTaskBlocks.insert(blockID)
            }
        }

        var result = AttributedString()
        var previousBlockID: Int?
        var previousListContainerID: Int?
        // Only the *first* run of a (possibly multi-run) list item gets its
        // marker — a bold/italic span partway through the same item is
        // still more of that one item's text, not a new item. Missing this
        // guard was a real bug: "buy **milk**" as one list item parses as
        // two runs sharing one block identity, and without this check both
        // runs matched listPrefix(), producing "- buy - milk" instead of
        // "- buy milk" (with milk bold).
        var markedListBlockID: Int?

        for run in parsed.runs {
            var slice = AttributedString(parsed[run.range])
            let components = run.presentationIntent?.components ?? []
            let blockID = components.first?.identity
            let listContainerID = listContainerIdentity(components)

            if let previousBlockID, blockID != previousBlockID {
                let startsNewListGroup = listContainerID != nil
                    && previousListContainerID != nil
                    && listContainerID != previousListContainerID
                result += AttributedString(startsNewListGroup ? "\n\n" : "\n")
            }

            if let level = headerLevel(components) {
                slice.font = headerFont(level: level)
                slice[NoteBlockStyleKey.self] = blockStyle(forHeaderLevel: level)
            } else if isBlockQuote(components) {
                slice.foregroundColor = .secondary
                slice[NoteBlockStyleKey.self] = .blockquote
            } else if isCodeBlock(components) {
                slice.font = .system(size: 11, design: .monospaced)
                slice[NoteBlockStyleKey.self] = .code
            } else if listPrefix(components) != nil {
                let isChecked = blockID.map(checkedBlocks.contains) ?? false
                let isUncheckedTask = blockID.map(uncheckedTaskBlocks.contains) ?? false

                if blockID != markedListBlockID {
                    if isChecked || isUncheckedTask {
                        let stripped = String(slice.characters.dropFirst(4))
                        slice = AttributedString(isChecked ? "☑ " : "☐ ") + AttributedString(stripped)
                    } else if let prefix = listPrefix(components) {
                        slice = AttributedString(prefix) + slice
                    }
                    markedListBlockID = blockID
                }
                if isChecked {
                    slice.strikethroughStyle = .single
                    slice.foregroundColor = .secondary
                }
            }

            result += slice
            previousBlockID = blockID
            previousListContainerID = listContainerID
        }

        return result
    }

    private struct FencedCodeBlock {
        let contents: String
        let language: String?
    }

    private static func fencedCodeBlock(in markdown: String) -> FencedCodeBlock? {
        let lines = markdown.components(separatedBy: "\n")
        guard lines.count >= 2,
              let openingFence = lines.first?.trimmingCharacters(in: .whitespaces),
              openingFence.hasPrefix("```"),
              lines.last?.trimmingCharacters(in: .whitespaces).hasPrefix("```") == true else {
            return nil
        }
        let language = String(openingFence.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        return FencedCodeBlock(
            contents: lines.dropFirst().dropLast().joined(separator: "\n"),
            language: language.isEmpty ? nil : language
        )
    }

    /// Keeps source blank lines as a formatting boundary without splitting
    /// fenced code, where blank lines are literal content.
    private enum TopLevelGroup {
        case content(String)
        case separator(String)
    }

    private static func topLevelGroups(in markdown: String) -> [TopLevelGroup] {
        var groups: [TopLevelGroup] = []
        var currentLines: [String] = []
        var pendingBlankLines = 0
        var isInsideCodeFence = false
        var needsBlockBoundary = false

        func appendContent() {
            guard !currentLines.isEmpty else { return }
            groups.append(.content(currentLines.joined(separator: "\n")))
            currentLines.removeAll(keepingCapacity: true)
        }

        func appendPendingSeparator(beforeContent: Bool) {
            guard pendingBlankLines > 0 else { return }
            // A blank line between two blocks occupies two newlines; every
            // additional blank line contributes one more. At the beginning
            // or end of a note, there is no second block-side newline.
            let hasEarlierContent = groups.contains { group in
                if case .content = group { return true }
                return false
            }
            let newlineCount = pendingBlankLines + (beforeContent && hasEarlierContent ? 1 : 0)
            groups.append(.separator(String(repeating: "\n", count: newlineCount)))
            pendingBlankLines = 0
        }

        for line in markdown.split(separator: "\n", omittingEmptySubsequences: false) {
            let text = String(line)
            if text.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                if isInsideCodeFence {
                    currentLines.append(text)
                    isInsideCodeFence = false
                    appendContent()
                    needsBlockBoundary = true
                } else {
                    let hadPendingSeparator = pendingBlankLines > 0
                    let hasCurrentContent = !currentLines.isEmpty
                    appendPendingSeparator(beforeContent: true)
                    if needsBlockBoundary && !hadPendingSeparator {
                        groups.append(.separator("\n"))
                    }
                    needsBlockBoundary = false
                    appendContent()
                    if hasCurrentContent {
                        groups.append(.separator("\n"))
                    }
                    isInsideCodeFence = true
                    currentLines.append(text)
                }
                continue
            }

            if !isInsideCodeFence, text.trimmingCharacters(in: .whitespaces).isEmpty {
                appendContent()
                pendingBlankLines += 1
            } else {
                let hadPendingSeparator = pendingBlankLines > 0
                appendPendingSeparator(beforeContent: true)
                if needsBlockBoundary && !hadPendingSeparator {
                    groups.append(.separator("\n"))
                }
                needsBlockBoundary = false
                currentLines.append(text)
            }
        }

        appendContent()
        appendPendingSeparator(beforeContent: false)
        return groups.isEmpty ? [.content(markdown)] : groups
    }

    /// `fontResolutionContext`-free, unlike an earlier version of this
    /// function — inline styling is read from `.inlinePresentationIntent`
    /// (an `OptionSet`, directly comparable) rather than `.font`, which
    /// needed a resolution context this static function has no
    /// `@Environment` to provide.
    static func serialize(_ attributed: AttributedString) -> String {
        struct Line {
            var text = ""
            var blockStyle: NoteBlockStyle?
            var codeLanguage: String?
        }
        var lines: [Line] = [Line()]

        for run in attributed.runs {
            let text = String(attributed[run.range].characters)
            let style = run[NoteBlockStyleKey.self]
            let codeLanguage = run[NoteCodeLanguageKey.self]
            let pieces = text.components(separatedBy: "\n")
            for (index, piece) in pieces.enumerated() {
                if index > 0 { lines.append(Line()) }
                // An empty line within a fenced code block is still code,
                // not a separator between two independent code blocks.
                if style == .code, lines[lines.count - 1].blockStyle == nil {
                    lines[lines.count - 1].blockStyle = style
                }
                if style == .code, lines[lines.count - 1].codeLanguage == nil {
                    lines[lines.count - 1].codeLanguage = codeLanguage
                }
                guard !piece.isEmpty else { continue }
                if lines[lines.count - 1].blockStyle == nil {
                    lines[lines.count - 1].blockStyle = style
                }
                lines[lines.count - 1].text += style == .code ? piece : markdownSpan(piece, run: run)
            }
        }

        let markdownLines = lines.map { line -> String in
            if line.text.hasPrefix("☐ ") {
                return "- [ ] " + line.text.dropFirst(2)
            }
            if line.text.hasPrefix("☑ ") {
                return "- [x] " + line.text.dropFirst(2)
            }
            switch line.blockStyle {
            case .h1: return "# " + line.text
            case .h2: return "## " + line.text
            case .h3: return "### " + line.text
            case .blockquote: return "> " + line.text
            case .code: return line.text
            case .body, nil: return line.text
            }
        }

        // Consecutive list items join with a single newline (staying one
        // list); everything else needs a *blank* line between entries or
        // re-parsing merges them back into one soft-wrapped paragraph —
        // confirmed as a real bug: a blockquote followed by a plain
        // paragraph, both single-newline-joined, survived one round trip
        // intact but came back on the second as the paragraph's text
        // merged straight into the blockquote.
        //
        // A blank `Line` (empty text, no block style) can show up here for
        // two different reasons: a paragraph break the user actually typed,
        // or the literal "\n\n" `parse()` inserts between two adjacent
        // lists of different types so they render visibly separated in the
        // WYSIWYG editor (see `listContainerIdentity` above) — and that one
        // logical gap can span *multiple* blank `Line`s once a "\n\n" run
        // gets split on "\n". Since Markdown doesn't distinguish "one blank
        // line" from "several" (both just mean "new paragraph"), every run
        // of one or more blank lines collapses to exactly one "\n\n" here,
        // and `pendingBlankSeparator` stops the line right after it from
        // adding a second one on top — without this, that gap serialized as
        // three blank lines instead of one, compounding a little further on
        // every formatted-mode round trip.
        var output = ""
        var previousWasListItem = false
        var pendingBlankSeparator = false
        var index = 0
        while index < markdownLines.count {
            if lines[index].blockStyle == .code {
                var codeLines: [String] = []
                var codeLanguage: String?
                while index < markdownLines.count, lines[index].blockStyle == .code {
                    codeLines.append(markdownLines[index] == emptyCodeBlockMarker ? "" : markdownLines[index])
                    codeLanguage = codeLanguage ?? lines[index].codeLanguage
                    index += 1
                }
                if !output.isEmpty && !pendingBlankSeparator { output += "\n\n" }
                let openingFence = "```" + (codeLanguage ?? "")
                output += codeLines == [""]
                    ? openingFence + "\n```"
                    : openingFence + "\n" + codeLines.joined(separator: "\n") + "\n```"
                previousWasListItem = false
                pendingBlankSeparator = false
                continue
            }

            let line = markdownLines[index]
            guard !line.isEmpty else {
                if !output.isEmpty {
                    if pendingBlankSeparator {
                        output += "\n"
                    } else {
                        output += "\n\n"
                        pendingBlankSeparator = true
                    }
                }
                previousWasListItem = false
                index += 1
                continue
            }

            let isListItem = Self.isListItemLine(line)
            if !output.isEmpty && !pendingBlankSeparator {
                output += (previousWasListItem && isListItem) ? "\n" : "\n\n"
            }
            output += line
            previousWasListItem = isListItem
            pendingBlankSeparator = false
            index += 1
        }
        return output
    }

    /// The formatted editor is an AppKit view on macOS 14+, while the
    /// storage model stays Swift's `AttributedString`. Carry our one custom
    /// block-style attribute explicitly: Foundation's automatic bridge does
    /// not guarantee preservation of custom Swift attribute keys.
    static func appKitAttributedString(from attributed: AttributedString) -> NSAttributedString {
        let native = NSMutableAttributedString(attributedString: NSAttributedString(attributed))
        var location = 0

        for run in attributed.runs {
            let runText = String(attributed[run.range].characters)
            let length = (runText as NSString).length
            if let style = run[NoteBlockStyleKey.self], length > 0 {
                native.addAttribute(appKitBlockStyleKey, value: style.rawValue, range: NSRange(location: location, length: length))
            }
            if let language = run[NoteCodeLanguageKey.self], length > 0 {
                native.addAttribute(appKitCodeLanguageKey, value: language, range: NSRange(location: location, length: length))
            }
            if let intent = run.inlinePresentationIntent, length > 0 {
                native.addAttribute(
                    appKitInlineIntentKey,
                    value: String(intent.rawValue),
                    range: NSRange(location: location, length: length)
                )
            }
            location += length
        }
        return native
    }

    static func attributedString(from native: NSAttributedString) -> AttributedString {
        var attributed = AttributedString(native)
        let plainText = String(attributed.characters)
        let fullRange = NSRange(location: 0, length: native.length)

        native.enumerateAttribute(appKitBlockStyleKey, in: fullRange) { value, range, _ in
            guard let rawValue = value as? String,
                  let style = NoteBlockStyle(rawValue: rawValue),
                  let stringRange = Range(range, in: plainText),
                  let lower = AttributedString.Index(stringRange.lowerBound, within: attributed),
                  let upper = AttributedString.Index(stringRange.upperBound, within: attributed),
                  lower < upper else { return }
            attributed[lower..<upper][NoteBlockStyleKey.self] = style
        }
        native.enumerateAttribute(appKitCodeLanguageKey, in: fullRange) { value, range, _ in
            guard let language = value as? String,
                  let stringRange = Range(range, in: plainText),
                  let lower = AttributedString.Index(stringRange.lowerBound, within: attributed),
                  let upper = AttributedString.Index(stringRange.upperBound, within: attributed),
                  lower < upper else { return }
            attributed[lower..<upper][NoteCodeLanguageKey.self] = language
        }
        native.enumerateAttribute(appKitInlineIntentKey, in: fullRange) { value, range, _ in
            guard let rawValue = value as? String,
                  let rawIntent = UInt(rawValue),
                  let stringRange = Range(range, in: plainText),
                  let lower = AttributedString.Index(stringRange.lowerBound, within: attributed),
                  let upper = AttributedString.Index(stringRange.upperBound, within: attributed),
                  lower < upper else { return }
            attributed[lower..<upper].inlinePresentationIntent = InlinePresentationIntent(rawValue: rawIntent)
        }
        return attributed
    }

    private static func isListItemLine(_ line: String) -> Bool {
        if line.hasPrefix("- ") { return true }
        guard let dotIndex = line.firstIndex(of: ".") else { return false }
        let ordinal = line[line.startIndex..<dotIndex]
        return !ordinal.isEmpty && ordinal.allSatisfy(\.isNumber) && line[dotIndex...].hasPrefix(". ")
    }

    // MARK: - Serialize helpers

    private static func markdownSpan(_ text: String, run: AttributedString.Runs.Element) -> String {
        var result = text
        if let link = run.link {
            result = "[\(result)](\(link.absoluteString))"
        }
        let intent = run.inlinePresentationIntent ?? []
        if intent.contains(.emphasized) { result = "*\(result)*" }
        if intent.contains(.stronglyEmphasized) { result = "**\(result)**" }
        if intent.contains(.strikethrough) { result = "~~\(result)~~" }
        return result
    }

    // MARK: - Parse helpers

    private static func blockStyle(forHeaderLevel level: Int) -> NoteBlockStyle {
        switch level {
        case 1: return .h1
        case 2: return .h2
        default: return .h3
        }
    }

    private static func headerLevel(_ components: [PresentationIntent.IntentType]) -> Int? {
        for component in components {
            if case let .header(level) = component.kind { return level }
        }
        return nil
    }

    private static func isBlockQuote(_ components: [PresentationIntent.IntentType]) -> Bool {
        components.contains { if case .blockQuote = $0.kind { return true }; return false }
    }

    private static func isCodeBlock(_ components: [PresentationIntent.IntentType]) -> Bool {
        components.contains { if case .codeBlock = $0.kind { return true }; return false }
    }

    private static func listPrefix(_ components: [PresentationIntent.IntentType]) -> String? {
        for component in components {
            switch component.kind {
            case let .listItem(ordinal):
                let ordered = components.contains { if case .orderedList = $0.kind { return true }; return false }
                return ordered ? "\(ordinal). " : "- "
            default:
                continue
            }
        }
        return nil
    }

    private static func listContainerIdentity(_ components: [PresentationIntent.IntentType]) -> Int? {
        for component in components {
            switch component.kind {
            case .unorderedList, .orderedList:
                return component.identity
            default:
                continue
            }
        }
        return nil
    }

    /// Matches `BlockMarkdownRenderer.headerFont` exactly, so a header
    /// looks the same whether it's showing in the rich editor or in a
    /// read-only rendered preview elsewhere in the app.
    static func headerFont(level: Int) -> Font {
        switch level {
        case 1: return .system(size: 17, weight: .bold)
        case 2: return .system(size: 15, weight: .bold)
        default: return .system(size: 13, weight: .semibold)
        }
    }
}
