import Foundation

/// One entry from a user-imported quote file, ready for display. `id` is
/// synthesized from the entry's position when the file is loaded — the
/// user-facing JSON format (`CustomQuoteEntry`) has no `id` field, since
/// requiring someone to invent stable IDs for their own quote list would be
/// needless friction for content the app never redistributes.
struct CustomQuote: Identifiable, Hashable {
    let id: Int
    let text: String
    let attribution: String?
}

/// The on-disk/import JSON shape: `[{ "text": "...", "attribution": "..." }]`,
/// `attribution` optional. Deliberately minimal — no `id`, no fixed count
/// requirement (see `CustomQuoteStore.quote(for:)`, which rotates through
/// however many entries are present).
struct CustomQuoteEntry: Codable, Hashable {
    let text: String
    let attribution: String?
}
