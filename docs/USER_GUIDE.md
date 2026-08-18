<p align="center">
  <img src="images/app-icon.png" width="96" height="96" alt="Hibimekuri app icon">
</p>

<h1 align="center">Hibimekuri User Guide</h1>

This guide walks through what Hibimekuri does, feature by feature.

## Philosophy

A **himekuri** (日めくり) is the paper tear-off calendar that has sat in Japanese homes,
shops, and offices for generations: one page per day, torn off each morning to reveal
the next. It was never a specialist's object — local businesses gave them away as
everyday gifts, and each page carried small, accessible pieces of seasonal awareness
and everyday wisdom, like a proverb or a lucky-day note, that anyone could read in
passing. The appeal was never the information by itself; it was the small physical
ritual of tearing a page away each morning, more deliberate than a glance at a phone
screen.

**Hibimekuri** (日々めくり) adds the Japanese repetition mark **々** to that idea: **日**
becomes **日々**, from one day to everyday life. The name suggests turning through the
days one page at a time — a himekuri for the days you keep.

This app borrows that shape for journaling instead of counting down days. Each page is
a single sitting: the date, a bit of real calendar detail connecting the day to the
wider season, a short piece of Japanese literature or idiom, a place to write, and a
small task list — closed out by a tear-off action that reveals the next day
underneath. A torn-off page isn't deleted; it moves to the [Archive](#archive), the
same way you'd keep a stack of paper instead of throwing it away.

That's also why the interface stays plain: minimal chrome, typography-led paper
surfaces, a dominant date numeral, hairline rules. Hibimekuri is meant to feel closer
to a physical object on a desk than to software — you can revisit this explanation
anytime from Hibimekuri menu → About Hibimekuri → "What is a himekuri?"

## The daily page

Each day is one page. It has four parts:

- **The date and almanac.** The big numeral is today's date. Around it: the weekday,
  the month, the year (with the Reiwa/Heisei/Shōwa era numbers), and a set of
  traditional Japanese calendar fields — see [Understanding the almanac](#understanding-the-almanac)
  below if you're not familiar with them. Two small reference calendars for last month
  and next month sit underneath, so you always know where you are.
- **A quote.** A Japanese idiom, proverb, or line of literature, with an English
  reading underneath if you're using the app in English. You can switch this out for
  an English word of the day, or your own quotes — see [Choosing what the daily
  quote shows](#choosing-what-the-daily-quote-shows).
- **A memo.** A place to write about your day. Tap it to start typing; tap away to see
  it rendered. It supports Markdown — headers, lists, blockquotes, code blocks,
  **bold**, *italic*, ~~strikethrough~~, `inline code`, and links. See [Writing in
  Markdown](#writing-in-markdown) for the full syntax.
- **A task list.** See [Tasks](#tasks) below.

Tapping the numeral flips it over to show the full current month as a small calendar,
with any day that has a task due marked with a red ring. Tap it again to flip back.

### Tearing off a page

When you're done with today, click **Tear Off Today**. The page peels away — with a
small paper-rustle sound — and the next day appears underneath, ready to write on.
Torn-off pages aren't deleted — they move to the [Archive](#archive), exactly like a
stack of paper you kept instead of throwing away.

You can also write and tear off several days ahead of the real calendar date if you
want to plan in advance — tearing off a page just moves you to the next one, whatever
today's date actually is.

### Catching up

If life gets busy and you fall behind — the app is showing a day from last week while
the calendar has long since moved on — a small icon appears in the top corner (next to
the sun and archive icons) to let you catch up. Tapping it tears through every day
between where you are and today in quick succession, landing you back on the real
date. Every day it tears through still becomes a real (likely blank) entry in the
Archive, the same as if you'd torn it off by hand.

## Understanding the almanac

Hibimekuri shows several traditional Japanese calendar fields alongside the regular
date. They're computed from real astronomical calculations, not a lookup table, so
they're accurate for any date the app can show.

- **Kanshi (干支)** — the day's position in the 60-day sexagenary cycle, a
  traditional East Asian way of naming days (and years), combining one of 10 "stems"
  with one of 12 "branches."
- **Rokuyō (六曜)** — a six-day cycle traditionally used to judge whether a day is
  lucky or unlucky for things like weddings or moving house.
- **Kyūreki (旧暦)** — the date according to the old lunar calendar, including leap
  months when they occur.
- **Jūnichoku (十二直)** — a twelve-day cycle of traditional activity guidance (each
  day is said to favor or disfavor certain kinds of activities).
- **Moon phase** — the current phase of the moon, with an icon.
- **Era year** — the year in the Reiwa (令和) era, alongside the two prior eras
  (Heisei/平成, Shōwa/昭和) for reference.

One thing intentionally left out: 九星 (nine-star astrology). It needs a much more
precise reference calculation than the app can currently guarantee, so it's left out
rather than shown unreliably.

None of this is the official Japanese ephemeris — treat it as a well-researched
approximation, not a religious or civil authority.

## Tasks

The task list is separate from any single day — it's a persistent list that carries
forward, not something you fill out fresh each morning.

- **Add a task** with the "+" button or the "Add a task" row.
- **Check it off** — done tasks stay visible with a strikethrough rather than
  disappearing, so you can see what you got done.
- **Click a task once** to select it. **Double-click** to expand it and edit its notes
  or set a defer date. Clicking anywhere else closes it again and saves your changes.
- **A task's notes field** is the same rich Markdown editor as the daily note — see
  [Focus Mode and formatted text](#focus-mode-and-formatted-text) and [Writing in
  Markdown](#writing-in-markdown). This is also where you'd add a checklist of smaller
  steps for a task, written as Markdown.
- **Reorder tasks** by dragging them. Reordering is only available while no task is
  expanded.
- **"Do later"** — give a task a defer date to hide it from the main list until that
  date arrives. Deferred tasks are still visible behind a small "+N scheduled" link, so
  they're not completely out of sight.
- **Deadlines** — if a task has a date set, Hibimekuri can send you a single local
  reminder on the morning it's due. No account or server involved.
- **Deleting a task** doesn't destroy it right away — it moves to a "Recently deleted"
  list in Settings for a while (you choose how long: 15, 30, or 90 days) in case you
  want it back. If you want it gone sooner, "Empty Deleted Tasks…" in that same Settings
  section removes everything in it immediately.

## Focus Mode and formatted text

The daily memo, the wide-window layout's note panel, and each task's notes field all
share the same editor, with two small icons above it:

- **The expand icon** opens **Focus Mode** — a full-window, distraction-free view for
  writing, with everything else out of the way. Click the same icon again, or press
  **Escape**, to leave it. Whatever you write is saved to the same note you started
  from; nothing is lost by entering or leaving.
- **The formatting icon** switches between two ways of editing the same text:
  - **Formatted** (the default) — a true WYSIWYG view. Formatting renders live as you
    apply it; you never see Markdown symbols like `**` or `#`. Select some text and a
    small floating toolbar appears above it, themed to match your current theme, with
    buttons for headers (H1/H2/H3), **bold**, *italic*, links, blockquotes, bulleted/
    numbered lists, checklists, and code blocks. You can also just type Markdown syntax
    directly here — a complete marker like `# `, `- `, or `- [ ] ` converts live to its
    formatted equivalent, the same result as pressing the matching toolbar button.
  - **Markdown** — the same content shown as raw Markdown source, for typing syntax
    directly instead of using the toolbar.

  Switching between the two doesn't change what's saved — it's the same text either
  way, just shown differently.

## Writing in Markdown

Wherever Hibimekuri renders Markdown — the daily memo, the wide-window note, task
notes, and Focus Mode — the same basic syntax works. Type it in plain text (or in
Markdown mode, or directly into formatted mode) and it renders automatically.

| To get this | Type this |
| --- | --- |
| **Bold** | `**bold**` |
| *Italic* | `*italic*` |
| ~~Strikethrough~~ | `~~strikethrough~~` |
| A link | `[link text](https://example.com)` |
| Heading | `# Heading 1`, `## Heading 2`, `### Heading 3` |
| Blockquote | `> quoted text` |
| Bulleted list | `- item` |
| Numbered list | `1. item` |
| Checklist | `- [ ] not done` and `- [x] done` |
| Code block | fence with three backticks (` ``` `) on their own line, before and after |

**Checklists** have their own toolbar button in formatted mode, or type them by hand in
either mode:

```
- [ ] Pack the bag
- [x] Buy tickets
- [ ] Call the hotel
```

An unchecked item shows as a `☐` box; a checked one shows as `☑`, struck through — a
good place to keep a small checklist for a task without needing a separate feature for
it.

Not supported anywhere in Hibimekuri: tables, images, and nested lists.

## Choosing what the daily quote shows

In Settings, under **Daily Quote**, you can pick what the quote card on each page
shows:

- **Japanese idiom** (the default) — a proverb, four-character idiom, or line of
  literature, in Japanese, with an English reading if you're using the app in English.
- **Word of the day** (English mode only) — an English word instead, for readers who'd
  rather not see Japanese content at all.
- **Custom** — your own quotes, from a file you provide.

### Using your own quotes

Select **Custom**, then click **Import Quotes…** and choose a JSON file. The format is
a simple array:

```json
[
  { "text": "Your quote here.", "attribution": "Optional source" }
]
```

`attribution` is optional — leave it out entirely for a quote with no byline. There's
no fixed number of quotes required; Hibimekuri rotates through however many you
provide, reshuffling the order slightly each year so it doesn't repeat identically.

Not sure where to start? Click **Download Sample…** right next to the import button to
save a working example file, or look at
[`sample-custom-quotes.json`](sample-custom-quotes.json) in this repository.

This is entirely your own content — Hibimekuri doesn't bundle or share anyone's
quotes. Whatever you import stays local to your Mac (or syncs via iCloud Drive if you
have that turned on, same as your entries and tasks).

## Archive

Every page you've torn off lives in the Archive, most recent first. You can:

- **Search** it by what you wrote or by date.
- **Open** any entry to read the full page as it was that day.
- **Restore** an entry to bring it back as the current, editable page — useful if you
  tore something off by mistake, or want to add more to a day you already closed out.

## Themes and appearance

Settings → Appearance lets you pick from six paper themes — Classic, Sumi, Matcha,
Washi, Zen, and Sakura — each with its own paper color, ink color, accent, and (in the
wide-window layout) a themed illustration. Independently, you can set Light, Dark, or
System mode.

The Dock icon follows along too — it shows today's actual date and matches whichever
theme and light/dark mode is active, updating itself automatically at midnight.

## Wide-window layout

Resize the window wider and Hibimekuri switches to a two-pane layout: the calendar
side stays exactly as it is in the compact view, while tasks, your memo, and the
tear-off button move into a dedicated pane on the right with more room to work in.
Resize back down and it returns to the single-column compact page.

The note panel's footer also has **Previous Day** and **Next Day** buttons, plus a
jump-to-today shortcut — a quick way to look ahead and write or adjust tasks on a
future day without tearing anything off first.

## Language

Settings → Language switches the whole app between Japanese and English — not just
labels, but weekday names, era names, almanac field names, and section headers. The
idiom itself always stays in Japanese even in English mode (only its meaning
translates) — that content is Japanese by nature, not something to replace.

## Your data stays yours

Hibimekuri treats what you write as yours, not the app's. There's no account to create
and nothing to sign in to — you can use the entire app, every day, without ever giving
it your name, your email, or a network connection. Nothing you write is collected,
analyzed, or sent anywhere. The app doesn't know you exist beyond the files on your own
disk.

That shows up in a few concrete ways:

- **A format you can read without Hibimekuri.** Everything is stored as plain,
  human-readable JSON — not a proprietary format or a database locked inside the app.
  You can find it via **Settings → Reveal in Finder**, and open `entries.json` or
  `tasks.json` in any text editor, with or without Hibimekuri running. If you ever stop
  using the app, your journal doesn't stop being readable.
- **100% local by default.** Nothing leaves your Mac unless you turn on iCloud Drive
  sync yourself (Settings → Sync via iCloud), which shares the same plain files with
  your other Macs signed into the same iCloud account. There's no hosted service behind
  this — it's the same mechanism as any other file synced through iCloud Drive, and
  it's off until you turn it on.
- **Export anytime** — Settings → Export Data copies your entries and tasks
  (`entries.json` and `tasks.json`) to a folder you choose, immediately. Custom Quote
  content isn't included, since it's your own imported file rather than something
  Hibimekuri generates.
- **Recovery** — if a data file is ever damaged or unreadable, Hibimekuri backs up the
  original automatically and starts fresh rather than losing everything silently. You'll
  see a message in Settings if this ever happens.
- **A backup before every save, not just on damage.** Hibimekuri keeps a rolling history
  of the last few versions of each file (`entries.previous.*.json`,
  `tasks.previous.*.json`) right alongside the current one, written just before each
  save. If you ever open the storage folder in Finder and notice these, that's what
  they are — an extra safety margin, not something to clean up by hand.

## Accessibility

Hibimekuri is built to work with VoiceOver and keyboard navigation: icon-only controls
have spoken labels, interactive elements that could be operated only by a mouse
gesture have real button/keyboard equivalents, animations respect Reduce Motion, and
status indicators (like an overdue task) never rely on color alone. A collapsed task
also has a VoiceOver "Show details" action, so opening it doesn't require a
double-click.

The one keyboard shortcut in the app is **Escape**, to leave Focus Mode. Reordering
tasks by dragging, and switching between Formatted and Markdown mode, are currently
mouse/trackpad-only.
