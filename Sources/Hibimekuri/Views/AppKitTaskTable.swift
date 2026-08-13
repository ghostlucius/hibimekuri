import SwiftUI
import AppKit

/// Wraps a real `NSTableView` to get genuine native drag-to-reorder for
/// task rows — a proper `.move` cursor (no copy badge), full control over
/// selection/insertion drawing, and Things-style live reflow while
/// dragging — none of which SwiftUI's own `List` or
/// `.draggable`/`.dropDestination` can actually deliver on macOS. Both were
/// tried first and both hit real, confirmed platform limits: `List`'s
/// native selection and reorder-insertion-line always render in the user's
/// system accent color with no available override (`.tint()`/
/// `.listItemTint()` do nothing for either — verified against a
/// forced-first-responder test harness, not assumed); `.draggable`'s
/// `Transferable` API has no way to declare `.move` over `.copy` (a
/// documented Apple Developer Forums limitation, not a bug in this app).
/// This is the one remaining lever with real, documented AppKit hooks for
/// all three: an explicit `NSDraggingSource` operation mask, a custom
/// `NSTableRowView` that suppresses native drawing, and `moveRow(at:to:)`
/// for the live shift.
struct AppKitTaskTable<Item: Identifiable, RowContent: View>: NSViewRepresentable where Item.ID == UUID {
    let items: [Item]
    // NSHostingView, when created by hand inside a Coordinator like this,
    // does NOT inherit the enclosing SwiftUI environment automatically —
    // row content relying on `@Environment(TaskStore.self)` crashed
    // outright the first time this ran ("No Observable object of type
    // TaskStore found") until this was passed through explicitly and
    // re-applied via `.environment(taskStore)` on each row.
    let taskStore: TaskStore
    let onReorder: ([Item]) -> Void
    @ViewBuilder let rowContent: (Item) -> RowContent

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let tableView = NSTableView()
        tableView.headerView = nil
        tableView.backgroundColor = .clear
        tableView.selectionHighlightStyle = .none
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.usesAutomaticRowHeights = true
        tableView.rowSizeStyle = .custom
        tableView.style = .plain
        tableView.allowsMultipleSelection = false
        // Suppresses the native accent-colored insertion-line/gap
        // indicator during reordering — the actual lever neither SwiftUI
        // API exposed. AppKit still shows its own floating drag-image
        // near the cursor and a clean `.move` arrow regardless, which
        // already closes most of the visual gap on its own.
        tableView.draggingDestinationFeedbackStyle = .none

        let column = NSTableColumn(identifier: .init("task"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.dataSource = context.coordinator
        tableView.delegate = context.coordinator
        tableView.registerForDraggedTypes([.taskRowPasteboardType])

        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.automaticallyAdjustsContentInsets = false

        context.coordinator.tableView = tableView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.syncIfNeeded(with: items)
    }

    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        var parent: AppKitTaskTable
        weak var tableView: NSTableView?
        private var draggedItemID: UUID?
        // The single source of truth for row order and content, both
        // while idle (kept in sync with `parent.items`) and mid-drag
        // (live-shifted here so `moveRow(at:to:)`'s animation and the
        // eventual commit read from the exact same array). The previous
        // version of this file mutated the table's visual row order
        // during `validateDrop` while `acceptDrop` still re-derived
        // `fromIndex` from the untouched `parent.items` — two different
        // coordinate frames that silently produced a drop that looked
        // right mid-drag but committed no real change. Routing both the
        // animation and the commit through this one array removes that
        // whole bug class instead of patching around it.
        private var workingItems: [Item]
        // Snapshot of `workingItems` taken once, at the moment the drag
        // starts (`willBeginAt`) — before any live reflow has touched it.
        // `validateDrop` computes every proposed position from this fixed
        // frame, never from `workingItems` itself. Computing `fromIndex`
        // from `workingItems` (the previous approach) meant it kept
        // shifting as the drag reflowed rows: reversing direction
        // mid-drag recomputed `fromIndex` against an array the drag had
        // already mutated, and the `toIndex -= 1` adjustment below
        // compounded against that moving target — confirmed via manual
        // testing to silently land back on the same index instead of
        // actually moving back, i.e. dragging past a row and then
        // reversing direction got stuck instead of undoing the reflow.
        // Row *count* never changes during a pure reorder, so a row's
        // on-screen slot index stays meaningful against this fixed
        // snapshot throughout the whole gesture.
        private var dragOriginItems: [Item]

        init(_ parent: AppKitTaskTable) {
            self.parent = parent
            self.workingItems = parent.items
            self.dragOriginItems = parent.items
        }

        /// Re-syncs from the SwiftUI-owned `items` whenever they change for
        /// reasons other than our own drag (e.g. a task toggled elsewhere,
        /// or the commit from our own `onReorder` flowing back around).
        /// Skipped mid-drag so an unrelated SwiftUI re-render can't yank
        /// the table back to the pre-drag order out from under the user's
        /// cursor.
        func syncIfNeeded(with items: [Item]) {
            guard draggedItemID == nil else { return }
            workingItems = items
            tableView?.reloadData()
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            workingItems.count
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard workingItems.indices.contains(row) else { return nil }
            let item = workingItems[row]
            let identifier = NSUserInterfaceItemIdentifier("row")
            // The dragged task's own slot renders invisible (not removed —
            // that would collapse its row height and jolt the layout) so
            // the only visible copy of it is the floating snapshot AppKit
            // is already dragging under the cursor. Without this, both the
            // floating snapshot and this row's real content are on screen
            // at once, i.e. the task appears twice.
            let isBeingDragged = item.id == draggedItemID
            let content = AnyView(parent.rowContent(item).environment(parent.taskStore).opacity(isBeingDragged ? 0 : 1))
            let hosting: NSHostingView<AnyView>
            if let reused = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSHostingView<AnyView> {
                hosting = reused
                hosting.rootView = content
            } else {
                hosting = NSHostingView(rootView: content)
                hosting.identifier = identifier
            }
            return hosting
        }

        func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
            PlainRowView()
        }

        func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
            guard workingItems.indices.contains(row) else { return nil }
            let pasteboardItem = NSPasteboardItem()
            pasteboardItem.setString(workingItems[row].id.uuidString, forType: .taskRowPasteboardType)
            return pasteboardItem
        }

        // AppKit's default drag-and-drop shows a floating snapshot of the
        // dragged row that tracks the cursor directly (every mouse-moved
        // event, not just row-boundary crossings) — this is exactly the
        // "pick up the block and carry it" feel Things and the Angular CDK
        // drag-drop example both have, and it's already smooth for free
        // since it's driven by real cursor position rather than an
        // animation. The row's own slot in the table is made invisible in
        // `viewFor row` above so this floating snapshot is the only
        // visible copy of the task — otherwise both it and the real row
        // are on screen simultaneously.
        //
        // AppKit's *automatic* snapshot of the row (the default behavior
        // when you only implement `pasteboardWriterForRow`) came back
        // blank for this row — confirmed by testing, not assumed: with
        // nothing else changed, the floating image was invisible across
        // the entire drag. `NSHostingView` content built on SwiftUI's
        // Metal-backed rendering path doesn't reliably rasterize through
        // whatever internal snapshot AppKit uses for row drag images.
        // Rendering the same SwiftUI content through `ImageRenderer`
        // directly and setting it explicitly on the dragging item sidesteps
        // that entirely — it's a separate, independent rendering path.
        func tableView(_ tableView: NSTableView, draggingSession session: NSDraggingSession, willBeginAt screenPoint: NSPoint, forRowIndexes rowIndexes: IndexSet) {
            guard let index = rowIndexes.first, workingItems.indices.contains(index) else { return }
            let item = workingItems[index]
            draggedItemID = item.id
            dragOriginItems = workingItems

            // `ImageRenderer` builds an isolated render tree that doesn't
            // inherit `NSApp.appearance` — the app's actual dark-mode
            // switch (see AppearanceController.swift) is applied globally
            // through AppKit, not through SwiftUI's `.preferredColorScheme`
            // environment, so without this the snapshot rendered using
            // light-mode color resolution regardless of the app's real
            // current appearance, showing up as washed-out/grayed text.
            let isDark = tableView.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let renderer = ImageRenderer(content: parent.rowContent(item)
                .environment(parent.taskStore)
                .environment(\.colorScheme, isDark ? .dark : .light)
                .frame(width: tableView.bounds.width, alignment: .leading))
            renderer.scale = tableView.window?.backingScaleFactor ?? 2
            if let dragImage = renderer.nsImage {
                session.enumerateDraggingItems(options: [], for: nil, classes: [NSPasteboardItem.self], searchOptions: [:]) { draggingItem, _, _ in
                    draggingItem.setDraggingFrame(NSRect(origin: draggingItem.draggingFrame.origin, size: dragImage.size), contents: dragImage)
                }
            }

            tableView.reloadData()
        }

        // The actual `.move`-not-`.copy` fix — SwiftUI's `.draggable` has
        // no equivalent hook at all.
        func tableView(_ tableView: NSTableView, draggingSession session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
            .move
        }

        // Live-reflow: as the drag crosses over another row, shift that
        // row out of the way immediately (Things/Angular-CDK-style)
        // instead of waiting for the drop. `proposedRow` under `.above`
        // means "insert before this index"; subtracting one when moving
        // downward accounts for the dragged row's own slot disappearing
        // ahead of the insertion point.
        //
        // AppKit sometimes proposes `.on` instead of `.above` — notably
        // when the cursor is above the very first row, outside any row's
        // vertical span. Rejecting that (the original approach) meant the
        // drop silently stuck at whatever the last accepted `.above`
        // location was, so dragging all the way to the top could leave
        // the item one slot short of first place. `setDropRow` is
        // AppKit's documented way to normalize any proposal to a plain
        // insertion-style drop before evaluating it.
        func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
            guard let draggedItemID,
                  let fromIndex = dragOriginItems.firstIndex(where: { $0.id == draggedItemID }) else {
                return []
            }
            if dropOperation != .above {
                tableView.setDropRow(row, dropOperation: .above)
            }
            var toIndex = row
            if toIndex > fromIndex {
                toIndex -= 1
            }
            toIndex = max(0, min(toIndex, dragOriginItems.count - 1))

            // Always recomputed fresh from the fixed pre-drag snapshot, not
            // by mutating `workingItems` incrementally — see
            // `dragOriginItems`'s doc comment for why that broke reversing
            // direction mid-drag.
            var proposed = dragOriginItems
            let item = proposed.remove(at: fromIndex)
            proposed.insert(item, at: toIndex)

            if proposed.map(\.id) != workingItems.map(\.id) {
                workingItems = proposed
                // `moveRow` cross-fades between the old and new position —
                // even with zero-duration animation wrapping, it still
                // briefly rendered the row at both places at once, and a
                // real drag re-triggers that on every boundary crossing,
                // making the "duplicate" visible for most of the drag
                // rather than one frame. A plain reload has no transition
                // state to be caught mid-flight in, so there's nothing to
                // double-render — it just always shows exactly what
                // `workingItems` currently says.
                tableView.reloadData()
            }
            return .move
        }

        func tableView(_ tableView: NSTableView, draggingSession session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
            // An empty operation means the drag was cancelled (dropped
            // outside a valid target, or Escape) — snap the live-shifted
            // visual state back to the real committed order rather than
            // leaving the table showing an order nothing ever confirmed.
            if operation == [] {
                workingItems = parent.items
            }
            draggedItemID = nil
            // Unconditional: this is what un-hides the dragged row's real
            // content again (see `viewFor row`), whether the drop
            // committed or was cancelled — waiting for the eventual
            // SwiftUI-driven `updateNSView` to do it would leave the row
            // invisible for however long that takes to fire.
            tableView.reloadData()
        }

        func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
            guard draggedItemID != nil else { return false }
            parent.onReorder(workingItems)
            return true
        }
    }
}

/// Suppresses `NSTableView`'s own accent-colored row selection drawing
/// entirely — our row content already draws its own `isSelected`
/// background (plain, theme-appropriate gray), so this just prevents the
/// system layer underneath it from painting anything at all, in any color.
private final class PlainRowView: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {}
    override var isEmphasized: Bool {
        get { false }
        set {}
    }
}

private extension NSPasteboard.PasteboardType {
    static let taskRowPasteboardType = NSPasteboard.PasteboardType("com.himekuri.taskrow")
}
