import SwiftUI
import AppKit

/// The formatted note editor uses AppKit's mature `NSTextView`, wrapped for
/// SwiftUI. This preserves the rich editor on macOS 14 through current macOS
/// releases without changing the app's Markdown storage format.
struct RichNoteEditor: View {
    @Binding var text: AttributedString
    let themePalette: ThemePalette

    @State private var selection = NSRange(location: 0, length: 0)
    @State private var controller = RichTextEditorController()

    private var hasRangeSelection: Bool { selection.location != NSNotFound && selection.length > 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if hasRangeSelection {
                NoteFormattingToolbar(
                    text: $text,
                    selection: $selection,
                    controller: controller,
                    palette: themePalette
                )
                .padding(.bottom, 6)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            AppKitRichTextEditor(
                text: $text,
                selection: $selection,
                controller: controller,
                palette: themePalette
            )
        }
        .animation(.easeInOut(duration: 0.12), value: hasRangeSelection)
    }
}

@MainActor
private final class RichTextEditorController {
    weak var textView: NSTextView?

    func focus() {
        guard let textView else { return }
        textView.window?.makeFirstResponder(textView)
    }
}

private struct AppKitRichTextEditor: NSViewRepresentable {
    @Binding var text: AttributedString
    @Binding var selection: NSRange
    let controller: RichTextEditorController
    let palette: ThemePalette

    private static let blockStyleAttribute = NSAttributedString.Key("com.hibimekuri.noteBlockStyle")

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        let textView = ChecklistTextView()
        textView.delegate = context.coordinator
        textView.drawsBackground = false
        textView.isRichText = true
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.usesRuler = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.textContainerInset = NSSize(width: 0, height: 2)
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true

        scrollView.documentView = textView
        context.coordinator.textView = textView
        controller.textView = textView
        context.coordinator.render(force: true)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        controller.textView = context.coordinator.textView
        context.coordinator.render(force: false)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: AppKitRichTextEditor
        weak var textView: NSTextView?
        private var isRendering = false

        init(parent: AppKitRichTextEditor) {
            self.parent = parent
        }

        func render(force: Bool) {
            guard let textView else { return }
            textView.insertionPointColor = NSColor(parent.palette.accent)
            textView.textColor = NSColor(parent.palette.textPrimary)
            textView.selectedTextAttributes = [
                .backgroundColor: NSColor(parent.palette.accent).withAlphaComponent(0.28)
            ]

            let expected = styledText(from: parent.text)
            guard force || !textView.attributedString().isEqual(to: expected) else { return }

            isRendering = true
            let restoredSelection = validSelection(parent.selection, textLength: expected.length)
            textView.textStorage?.setAttributedString(expected)
            textView.setSelectedRange(restoredSelection)
            isRendering = false
        }

        func textDidChange(_ notification: Notification) {
            guard !isRendering, let textView else { return }
            parent.text = NoteMarkdown.attributedString(from: textView.attributedString())
            parent.selection = textView.selectedRange()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard !isRendering, let textView else { return }
            parent.selection = textView.selectedRange()
        }

        private func validSelection(_ selection: NSRange, textLength: Int) -> NSRange {
            guard selection.location != NSNotFound else { return NSRange(location: 0, length: 0) }
            let location = min(max(0, selection.location), textLength)
            return NSRange(location: location, length: min(selection.length, textLength - location))
        }

        /// The stored Markdown has no visual colors of its own. Apply the
        /// terminal-like code treatment only at the AppKit rendering edge so
        /// the saved source stays portable Markdown.
        private func styledText(from attributed: AttributedString) -> NSAttributedString {
            let native = NSMutableAttributedString(
                attributedString: NoteMarkdown.appKitAttributedString(from: attributed)
            )
            let fullRange = NSRange(location: 0, length: native.length)
            guard fullRange.length > 0 else { return native }

            var codeRanges: [NSRange] = []
            native.enumerateAttribute(
                AppKitRichTextEditor.blockStyleAttribute,
                in: fullRange
            ) { value, range, _ in
                guard value as? String == NoteBlockStyle.code.rawValue else { return }
                codeRanges.append(range)
            }
            for range in codeRanges {
                native.addAttributes([
                    .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
                    .foregroundColor: NSColor(calibratedWhite: 0.92, alpha: 1),
                    .backgroundColor: NSColor(calibratedWhite: 0.12, alpha: 1)
                ], range: range)
            }
            return native
        }
    }
}

/// The formatting bar intentionally keeps the existing visible controls and
/// only appears for a real text selection.
private struct NoteFormattingToolbar: View {
    @Binding var text: AttributedString
    @Binding var selection: NSRange
    let controller: RichTextEditorController
    let palette: ThemePalette

    @State private var enteringLink = false
    @State private var linkURL = ""
    @State private var linkSelection: NSRange?
    @FocusState private var linkFieldFocused: Bool

    var body: some View {
        HStack(spacing: 2) {
            if enteringLink {
                TextField(
                    "",
                    text: $linkURL,
                    prompt: Text("Enter URL").foregroundStyle(palette.background.opacity(0.65))
                )
                .textFieldStyle(.plain)
                .foregroundStyle(palette.background)
                .frame(width: 270, height: 22)
                .focused($linkFieldFocused)
                .onSubmit(applyLink)
                .onExitCommand {
                    enteringLink = false
                    linkSelection = nil
                    DispatchQueue.main.async { controller.focus() }
                }
            } else {
                button("H1") { header(1) }
                button("H2") { header(2) }
                button("H3") { header(3) }
                Divider().frame(height: 14).padding(.horizontal, 2)
                iconButton("bold") { toggleInline(.stronglyEmphasized) }
                iconButton("italic") { toggleInline(.emphasized) }
                iconButton("link") { beginLink() }
                iconButton("quote.opening") { blockquote() }
                iconButton("chevron.left.forwardslash.chevron.right") { codeBlock() }
                iconButton("list.bullet") { listPrefix(.bullet) }
                iconButton("list.number") { listPrefix(.ordered) }
                iconButton("checklist") { listPrefix(.checklist) }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 8).fill(palette.accent))
    }

    private func button(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(palette.background)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func iconButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(palette.background)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func selectedRange(in attributed: AttributedString) -> Range<AttributedString.Index>? {
        selectedRange(in: attributed, selection: selection)
    }

    private func selectedRange(
        in attributed: AttributedString,
        selection: NSRange
    ) -> Range<AttributedString.Index>? {
        let plainText = String(attributed.characters)
        guard selection.location != NSNotFound,
              let stringRange = Range(selection, in: plainText),
              let lower = AttributedString.Index(stringRange.lowerBound, within: attributed),
              let upper = AttributedString.Index(stringRange.upperBound, within: attributed),
              lower < upper else { return nil }
        return lower..<upper
    }

    private func mutateSelection(_ mutation: (inout AttributedString, Range<AttributedString.Index>) -> Void) {
        guard let range = selectedRange(in: text) else { return }
        var updated = text
        mutation(&updated, range)
        text = updated
        DispatchQueue.main.async { controller.focus() }
    }

    private func toggleInline(_ trait: InlinePresentationIntent) {
        mutateSelection { updated, range in
            let allAlreadySet = updated[range].runs.allSatisfy {
                ($0.inlinePresentationIntent ?? []).contains(trait)
            }
            var intent = updated[range].runs.first?.inlinePresentationIntent ?? []
            if allAlreadySet { intent.remove(trait) } else { intent.insert(trait) }
            updated[range].inlinePresentationIntent = intent
        }
    }

    private func header(_ level: Int) {
        mutateSelection { updated, range in
            let style: NoteBlockStyle = level == 1 ? .h1 : (level == 2 ? .h2 : .h3)
            updated[range].font = NoteMarkdown.headerFont(level: level)
            updated[range][NoteBlockStyleKey.self] = style
        }
    }

    private func blockquote() {
        mutateSelection { updated, range in
            updated[range].foregroundColor = .secondary
            updated[range][NoteBlockStyleKey.self] = .blockquote
        }
    }

    private func beginLink() {
        guard let range = selectedRange(in: text) else { return }
        linkURL = text[range].runs.first?.link?.absoluteString ?? ""
        linkSelection = selection
        enteringLink = true
        DispatchQueue.main.async { linkFieldFocused = true }
    }

    private func applyLink() {
        let trimmed = linkURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            enteringLink = false
            linkSelection = nil
            DispatchQueue.main.async { controller.focus() }
            return
        }
        let source = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: source),
              url.host != nil,
              let capturedSelection = linkSelection,
              let range = selectedRange(in: text, selection: capturedSelection) else { return }
        var updated = text
        updated[range].link = url
        text = updated
        enteringLink = false
        linkSelection = nil
        DispatchQueue.main.async { controller.focus() }
    }

    private func codeBlock() {
        let ranges = selectedLineRanges(in: text)
        guard !ranges.isEmpty else { return }
        var updated = text
        let removesCodeBlock = ranges.allSatisfy {
            text[$0][NoteBlockStyleKey.self] == .code
        }
        for range in ranges {
            if removesCodeBlock {
                updated[range].font = nil
                updated[range][NoteBlockStyleKey.self] = .body
            } else {
                updated[range].font = .system(size: 11, design: .monospaced)
                updated[range][NoteBlockStyleKey.self] = .code
            }
        }
        text = updated
        DispatchQueue.main.async { controller.focus() }
    }

    private enum ListFormat { case bullet, ordered, checklist }

    private struct SelectedLine {
        let attributedRange: Range<AttributedString.Index>
        let nsRange: NSRange
        let text: String
    }

    private func listPrefix(_ format: ListFormat) {
        let lines = selectedLines(in: text)
        guard !lines.isEmpty else { return }
        var updated = text
        let markerLengths = lines.map { markerLength(in: $0.text, format: format) }
        let removesMarkers = markerLengths.allSatisfy { $0 != nil }
        var selectionOffset = 0

        if removesMarkers {
            for (line, markerLength) in zip(lines, markerLengths).reversed() {
                guard let markerLength,
                      let range = Range(
                        NSRange(location: line.nsRange.location, length: markerLength),
                        in: String(updated.characters)
                      ),
                      let lower = AttributedString.Index(range.lowerBound, within: updated),
                      let upper = AttributedString.Index(range.upperBound, within: updated) else { continue }
                if line.nsRange.location <= selection.location { selectionOffset -= markerLength }
                updated.removeSubrange(lower..<upper)
            }
        } else {
            for line in lines {
                updated[line.attributedRange][NoteBlockStyleKey.self] = .body
            }

            for (index, line) in lines.enumerated().reversed() where markerLengths[index] == nil {
                let prefix = marker(for: format, ordinal: index + 1)
                guard let range = Range(
                    NSRange(location: line.nsRange.location, length: 0),
                    in: String(updated.characters)
                ), let start = AttributedString.Index(range.lowerBound, within: updated) else { continue }
                if line.nsRange.location <= selection.location { selectionOffset += prefix.utf16.count }
                updated.insert(AttributedString(prefix), at: start)
            }
        }

        text = updated
        selection.location = max(0, selection.location + selectionOffset)
        DispatchQueue.main.async { controller.focus() }
    }

    private func marker(for format: ListFormat, ordinal: Int) -> String {
        switch format {
        case .bullet: return "- "
        case .ordered: return "\(ordinal). "
        case .checklist: return "☐ "
        }
    }

    private func markerLength(in text: String, format: ListFormat) -> Int? {
        switch format {
        case .bullet:
            return text.hasPrefix("- ") ? 2 : nil
        case .checklist:
            return (text.hasPrefix("☐ ") || text.hasPrefix("☑ ")) ? 2 : nil
        case .ordered:
            guard let dot = text.firstIndex(of: ".") else { return nil }
            let number = text[..<dot]
            let suffix = text[dot...]
            guard !number.isEmpty, number.allSatisfy(\.isNumber), suffix.hasPrefix(". ") else { return nil }
            return String(text[..<suffix.index(suffix.startIndex, offsetBy: 2)]).utf16.count
        }
    }

    private func selectedLineRanges(in attributed: AttributedString) -> [Range<AttributedString.Index>] {
        selectedLines(in: attributed).map(\.attributedRange)
    }

    private func selectedLines(in attributed: AttributedString) -> [SelectedLine] {
        let plainText = String(attributed.characters)
        let string = plainText as NSString
        guard selection.location != NSNotFound, selection.location <= string.length else { return [] }

        let selectionEnd = min(NSMaxRange(selection), string.length)
        var lineRange = string.lineRange(for: NSRange(location: selection.location, length: 0))
        var lines: [SelectedLine] = []

        while true {
            if let stringRange = Range(lineRange, in: plainText),
               let lower = AttributedString.Index(stringRange.lowerBound, within: attributed),
               let upper = AttributedString.Index(stringRange.upperBound, within: attributed),
               lower < upper {
                lines.append(SelectedLine(
                    attributedRange: lower..<upper,
                    nsRange: lineRange,
                    text: String(attributed[lower..<upper].characters)
                ))
            }

            let nextLocation = NSMaxRange(lineRange)
            guard nextLocation < selectionEnd, nextLocation < string.length else { break }
            lineRange = string.lineRange(for: NSRange(location: nextLocation, length: 0))
        }
        return lines
    }
}

/// Makes the visible task-list marker in formatted notes behave like a real
/// checkbox without changing the literal Markdown editor.
private final class ChecklistTextView: NSTextView {
    override func mouseDown(with event: NSEvent) {
        guard let layoutManager, let textContainer else {
            super.mouseDown(with: event)
            return
        }

        let textViewPoint = convert(event.locationInWindow, from: nil)
        let containerOrigin = textContainerOrigin
        let containerPoint = NSPoint(
            x: textViewPoint.x - containerOrigin.x,
            y: textViewPoint.y - containerOrigin.y
        )
        let glyphIndex = layoutManager.glyphIndex(for: containerPoint, in: textContainer)
        let characterIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
        let source = string as NSString
        guard characterIndex < source.length else {
            super.mouseDown(with: event)
            return
        }

        let lineRange = source.lineRange(for: NSRange(location: characterIndex, length: 0))
        let firstCharacter = source.substring(with: NSRange(location: lineRange.location, length: 1))
        let checkboxRange = NSRange(location: lineRange.location, length: 1)
        let checkboxGlyphRange = layoutManager.glyphRange(forCharacterRange: checkboxRange, actualCharacterRange: nil)
        let checkboxRect = layoutManager.boundingRect(forGlyphRange: checkboxGlyphRange, in: textContainer)

        guard (firstCharacter == "☐" || firstCharacter == "☑"),
              checkboxRect.insetBy(dx: -4, dy: -3).contains(containerPoint),
              let textStorage else {
            super.mouseDown(with: event)
            return
        }

        let attributes = textStorage.attributes(at: lineRange.location, effectiveRange: nil)
        let replacement = NSAttributedString(
            string: firstCharacter == "☐" ? "☑" : "☐",
            attributes: attributes
        )
        textStorage.replaceCharacters(in: checkboxRange, with: replacement)
        didChangeText()
    }
}
