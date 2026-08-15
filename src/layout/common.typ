// Shared layout vocabulary for every sheet layout: fonts, colours, components.
// - Body text uses ETBembo. Headings and labels use Montserrat.

#import "@preview/cuti:0.4.0": fakebold, regex-fakebold, fakesc
#import "../resolve.typ": resolve, dedup-by
#import "../data/abilities.typ": ability-names
#import "../data/skills.typ": skill-list
#import "../data/constants.typ": alignment-names
#import "../data/tools.typ": tool

// Kind and activation predicates over resolved trait dicts.
// - Both layouts filter `c.traits` with them.
// - The card lumps the trait kinds into one Traits list and splits activated items into its action-economy tables.
// - The letter splits class features, species traits, and feats into boxes.
// - The layouts share these predicates; the partition stays per-layout.
#let feature-kind(t) = t.at("kind", default: none)
#let activation-of(t) = t.at("activation", default: none)
#let is-trait-kind(t) = ("trait", "class-feature", "subclass-feature", "invocation", "magic-item").contains(feature-kind(t))
#let is-feat-kind(t) = feature-kind(t) == "feat"
#let is-class-feature-kind(t) = ("class-feature", "subclass-feature", "invocation").contains(feature-kind(t))

// --- Source grouping (the Features & Traits / Class Features lists) ---------
// - Both layouts group the passive feature lists by source under eyebrow sub-headers: species, each class, invocations, magic items.
// - A subclass feature folds into its class's group, tagged.
// - Single lines carry subclass, feat-category, or granter tags.
// - These predicates read the resolver's ancestry fields: `class-source`, `via-name`, `via-kind` (resolve.typ `flatten-features`).
// - The partition into boxes stays per-layout.

// A trait's group: `order` ranks the categories; `label` is the eyebrow text.
// - Order: species, classes, invocations, feats, magic items, unrecognized.
// - Ties break by first occurrence (see `trait-groups`).
// - `label: none` marks a trailing unlabeled group for features with no known source.
// - Only the card deck passes feats here; the letter keeps its own Feats box.
#let trait-group-of(t) = {
  let k = feature-kind(t)
  if k == "trait" { (order: 0, label: t.at("source", default: "Species")) }
  else if k == "class-feature" { (order: 1, label: t.at("source", default: "Class")) }
  else if k == "subclass-feature" { (order: 1, label: t.at("class-source", default: t.at("source", default: "Class"))) }
  else if k == "invocation" { (order: 2, label: "Eldritch Invocations") }
  else if k == "feat" { (order: 3, label: "Feats") }
  else if k == "magic-item" { (order: 4, label: "Magic Items") }
  else { (order: 5, label: none) }
}

// Group items by a key, keeping first-occurrence order for the groups and declaration order within each.
// - Returns `(key, items)` pairs.
// - Keys compare structurally, so a dict or an array works as a composite key.
// - Two sites: `trait-groups` (source groups) and `spellcasting-head` (sources sharing all four displayed values).
#let group-by(items, key) = {
  let groups = ()
  for it in items {
    let k = key(it)
    let i = groups.position(g => g.key == k)
    if i == none { groups.push((key: k, items: (it,))) } else {
      let g = groups.at(i)
      g.items.push(it)
      groups.at(i) = g
    }
  }
  groups
}

// Partition a trait list into ordered (label, items) groups.
// - Items keep declaration order, which puts a class's own features before its subclass's.
// - Groups sort by category order, then by first occurrence.
// - The body is a `{ … }` block: a leading-dot chain after a line break does not continue a top-level `#let` expression.
#let trait-groups(traits) = {
  // `.sorted` is stable, so equal-order groups keep first-occurrence order.
  group-by(traits, trait-group-of)
    .sorted(key: g => g.key.order)
    .map(g => (label: g.key.label, items: g.items))
}

// Per-line source tags for a feature line, as plain strings. `feature-item` renders them as a tiny eyebrow after the name.
// - A subclass feature carries its subclass name.
// - A feat carries its 2024 category: Origin or Fighting Style. A General feat carries none.
// - A feat also carries its granter when the granter is a chosen feature, such as an invocation.
// - Skip a structural granter (background, class, Fighting Style feature): the name restates the category or the masthead subtitle.
#let feature-tags(t) = {
  let k = feature-kind(t)
  if k == "subclass-feature" {
    let s = t.at("source", default: none)
    if s != none { (s,) } else { () }
  } else if k == "feat" {
    let cats = ("Origin Feat": "Origin", "Fighting Style Feat": "Fighting Style")
    let s = t.at("source", default: none)
    let tags = ()
    if s != none and cats.at(s, default: none) != none { tags.push(cats.at(s)) }
    let vk = t.at("via-kind", default: none)
    if vk != none and not ("background", "class", "class-feature").contains(vk) {
      tags.push(t.via-name)
    }
    tags
  } else { () }
}

#let label-font = "Montserrat"
#let math-font = "Euler Math"
#let text-font = "ETBembo"
// ETBembo draws the text; `covers` draws the digits from the Euler Math font.
// - Bare numbers then match the dice and modifier figures set in math mode.
// - Euler has one weight: bold bare numbers need `bold-num` (below).
// - Euler has one style: an italic digit needs `text(font: text-font)` to opt back out of the covers.
// - Lettered text still gets real ETBembo bold.
#let body-font = ((name: math-font, covers: regex("[0-9]")), text-font)
#let ink = rgb("#2b2b2b")
#let accent = rgb("#7a1f2b")
#let rule-color = rgb("#b8b0a8")

// Render a math source string (digits, the die "d", the operators + - / and spaces) as one Euler math equation.
// - Synthesises bold for the digits and letters only, and only when the surrounding context is bold.
// - Euler has one weight: its glyphs ignore `text(weight:)`, so bold stat values would drop to regular next to the bold ETBembo scores, HP, and speed.
// - cuti's stroke-based fake bold supplies that weight.
// - A `math.equation` skips the surrounding `text(weight:)`, so the `context` that reads the weight lives here, at construction, inside the bold cell.
// - Reading the weight in a `show math.equation` handler always reads regular; avoid that.
// - Stroking the whole equation makes the + and − signs blobby: a thin uniform glyph takes an outline badly.
// - `regex-fakebold` strokes only the `[0-9A-Za-z]+` runs, so the operator glyphs and the math spacing stay untouched.
#let _math-num(src) = context {
  let w = text.weight
  let bold = w == "bold" or (type(w) == int and w >= 600)
  let eq = eval(src, mode: "math")
  if bold { regex-fakebold(reg-exp: "[0-9A-Za-z]+", stroke: 0.055em, eq) } else { eq }
}

// Format a modifier in math mode.
// - Non-negatives get an explicit unary plus.
// - The ASCII "-" renders as math's real minus glyph.
#let fmt-mod(n) = _math-num(if n >= 0 { "+" + str(n) } else { str(n) })

// Fake bold for a bare number.
// - The digit `covers` on `body-font` draws it from Euler, which has one weight, so `text(weight:)` does nothing.
// - cuti's `fakebold` thickens the glyph with the same em-relative stroke as `_math-num`.
// - A bare number has no sign, so no alnum-run split is needed.
#let bold-num(n) = fakebold(stroke: 0.055em, [#n])

// A stat cell's value: a bare int takes the faked bold, already-styled content (a `fmt-mod`, a size string, a `checkbox`) passes through.
// - Shared by the card's `stat-cell` and the letter's `stat-box`, so the two branch alike.
#let num-value(v) = if type(v) == int { bold-num(v) } else { v }

// A bold bare number in the body font at one size — the number-box primitives' shared cell (ability score, AC, HP, hit dice, coins).
#let big-num(v, size) = text(font: body-font, size: size)[#bold-num(v)]

// Render a run of dice or modifier text ("1d8+2", "+5", "−1d4") in math mode.
// - Spaces out the die "d": a glued "d8" evaluates as one unknown identifier and errors.
// - Normalises the unicode minus to ASCII.
#let fmt-dice(s) = _math-num(s.replace("−", "-").replace("d", " d "))

// Render a spell's damage from the resolver's separate plain-data fields.
// - `fmt-dice` mathifies the dice expression.
// - The damage type and the beam label follow as upright prose.
// - One line, no surrounding whitespace: a multi-line content block would carry a leading and a trailing space, invisible in a table cell but a gap before the next word wherever this sits mid-sentence (`item-action-note`, `spell-action-note`'s joined parts).
#let fmt-spell-damage(dice, type: none, label: none) = [#fmt-dice(dice)#if type != none [ #type]#if label != none [ (#label)]]

// Render a saving-throw cell: the upright ability abbreviation, then the mathified DC.
// - The one save-DC display site: the spell table's HIT/SAVE column and the Cunning Strike table's SAVE column share it, so a save reads alike everywhere.
#let fmt-save(save, dc) = [#upper(save) $#dc$]

// Render every equation in the Euler Math OpenType font, with tight operators.
// - Font and operator spacing only: the bold synthesis lives in `_math-num`, because a math-equation show rule skips the surrounding weight.
// - `class("normal", …)` drops math's binary spacing, so a dice expression sets as one token ("1d6+4", "1d6−1").
// - Typst normalises the ASCII "-" of a source expression to `sym.minus`, which is what the rule matches.
// - An operator with no right-hand operand ("AC $12 +$ slot") hugs its left term, so authored prose gives every operator both of its operands.
// - Each layout applies it as `show math.equation: math-styled`.
#let math-styled = it => {
  show "+": math.class.with("normal")
  show sym.minus: math.class.with("normal")
  text(font: math-font, it)
}

// Faux small caps.
// - ETBembo ships its small-caps face under the same family and style as the roman, so Typst selects the roman and `smallcaps()`/`smcp` does nothing.
// - cuti's `fakesc` uppercases lowercase letters at `ratio` size; capitals stay tall.
// - Pass a mixed-case string ("Spell DC").
#let small-caps(s, ratio: 0.76) = fakesc(s, scaling: ratio)

// Give the full alignment name from its two-letter code (LG, NN, ...).
// - Unknown codes and `none` pass through unchanged.
#let alignment-name(code) = if code == none { none } else {
  alignment-names.at(code, default: code)
}

// The divider between peer identity facts — species, classes, size/type, background, alignment — on the placard and the card masthead. A string, so a caller can measure a joined line before it wraps.
#let meta-sep = " · "

// Build the header's upper meta line: size and creature type, then the background ("Small Humanoid · Sage").
// - The alignment sits on the line below, beside the proficiency bonus.
// - Each part drops out when absent.
#let meta-line(c) = {
  let parts = ()
  let st = (c.size, c.creature-type).filter(x => x != none).join(" ")
  if st != "" { parts.push(st) }
  if c.background != none { parts.push(c.background) }
  parts.join(meta-sep)
}

// A small uppercase Montserrat label.
#let label(body, size: 6pt, color: ink) = text(
  font: label-font, size: size, weight: "medium", tracking: 0.5pt, fill: color,
  upper(body),
)

// A tiny accent Montserrat eyebrow, uppercased.
// - Used by the card footer heads, the proficiency-line labels, the spellcasting source names, and the resource tracker's headers and derivation labels.
// - Each site keeps its own size, weight, and tracking: those three carry the tier distinctions.
// - This helper names only the shared font, accent, and uppercase.
#let eyebrow(body, size: 6pt, weight: "regular", tracking: 0pt) = text(
  font: label-font, size: size, weight: weight, fill: accent, tracking: tracking,
)[#upper(body)]

// A page-number footer, "n/m", right-aligned in the lower margin.
// - Chrome text: it inherits `ink`, separate from `accent`.
// - Avoid `align(bottom, …)` inside a `height: 100%` box: the footer region always spans to the page's physical bottom edge, and only its top moves with `footer-descent`. Bottom alignment pins the text to that edge, and a borderless print clips it.
// - Plain text sits `footer-descent` below the body, inboard of the printer's edge clip. The call site tunes `footer-descent`.
#let page-number-footer(n, m, size: 7pt) = align(right, text(font: label-font, size: size, weight: "medium")[#(str(n) + "/" + str(m))])

// The card's headline stat size: AC, HP, and each ability modifier read at one size, so the top of the core card has a single tier of prominent numbers.
#let card-stat-size = 13pt

// A boxed value with a label underneath: the building block for the stats strip.
// - `height: 100%` stretches the box to the tallest cell in its grid row, so the whole strip reads at one height.
// - `center + horizon` centres the value and label in the stretched box.
// - Mirrors the letter layout's `stat-box`.
#let stat-cell(value, name, width: auto, big: false) = box(
  width: width, height: 100%,
  inset: (x: 3pt, y: 3pt),
  stroke: 0.5pt + rule-color,
  radius: 2pt,
)[
  #set align(center + horizon)
  #text(font: body-font, size: if big { card-stat-size } else { 11pt }, weight: "bold")[#num-value(value)]
  #linebreak()
  #label(name, size: 5pt)
]

// Proficiency icons, all drawn at one size, so the hierarchy reads correctly.
// - Levels: empty (none), half-filled 45° split (Jack of All Trades), filled (proficient), filled ring (expertise).
// - `prof-mark-size` is that one size: every save, skill, and armor circle draws at it, so they read as one control.
#let prof-mark-size = 6pt
#let mark-empty(size) = circle(radius: size / 2, fill: none, stroke: 0.6pt + accent)
#let mark-full(size) = circle(radius: size / 2, fill: accent, stroke: none)

#let mark-expertise(size) = box(width: size, height: size)[
  #place(circle(radius: size / 2, fill: accent, stroke: none))
  #place(center + horizon, circle(radius: size / 6, fill: white, stroke: none))
]

#let mark-half(size) = box(width: size, height: size)[
  #place(circle(radius: size / 2, fill: accent, stroke: none))
  // White out the upper-right triangle, leaving the lower-left half filled.
  #place(polygon(fill: white, stroke: none, (0pt, 0pt), (size, 0pt), (size, size)))
  #place(circle(radius: size / 2, fill: none, stroke: 0.6pt + accent))
]

#let prof-mark(data, size: prof-mark-size) = {
  if data.level == "expertise" { mark-expertise(size) }
  else if data.level == "proficient" { mark-full(size) }
  else if data.at("joat", default: false) { mark-half(size) }
  else { mark-empty(size) }
}

// The advantage badge: a hexagon enclosing "A".
// - A third marker shape: circles mark proficiency, diamonds mark resource tracking, so this hexagon reads as a separate control.
// - Flat-top (top/bottom edges horizontal) so it is wide enough to hold the letter.
// - Two sites: the save-advantage footnote (`character-notes`) and a `skill-row` with `eff-check-advantage`.
// - A save advantage stays off the save boxes: it rarely covers all of an ability's saves. A check advantage covers one whole skill, which is one row.
#let adv-badge(size: 9.5pt) = box(baseline: 0.2em, width: size, height: size)[
  #place(polygon(
    fill: none, stroke: 0.6pt + accent,
    (size * 0.25, 0pt), (size * 0.75, 0pt), (size, size * 0.5),
    (size * 0.75, size), (size * 0.25, size), (0pt, size * 0.5),
  ))
  #place(center + horizon, text(
    font: label-font, size: size * 0.6, weight: "bold", fill: accent,
  )[A])
]

// One ability column: big score, modifier underneath, save below that.
// - The score takes the prominent slot at `card-stat-size`, reading as one tier with AC and HP; the modifier sits beneath it in the secondary size.
// - The two need no SCORE/MOD labels (the letter's rail carries them): the modifier always shows its sign, the score never does.
#let ability-cell(id, score, mod, save) = box(
  width: 100%,
  inset: (x: 2pt, y: 3pt),
  stroke: 0.5pt + rule-color,
  radius: 2pt,
)[
  #set align(center)
  // Full ability name (label uppercases it), e.g. INTELLIGENCE — the card cell is wide enough to spell it out rather than the three-letter abbreviation.
  #label(ability-names.at(id), size: 5.5pt, color: accent)
  #linebreak()
  #big-num(score, card-stat-size)
  #linebreak()
  #text(font: body-font, size: 9pt)[#fmt-mod(mod)]
  #linebreak()
  #v(1pt)
  // Same proficiency mark as the skill rows, so save and skill circles read as one consistent control (see `prof-mark`).
  #box(baseline: 1.5pt, if save.proficient { mark-full(prof-mark-size) } else { mark-empty(prof-mark-size) })
  #h(1.5pt)
  #text(font: label-font, size: 5pt, fill: ink)[SAVE ]
  #text(
    font: body-font, size: 7pt,
    weight: if save.proficient { "bold" } else { "regular" },
  )[#fmt-mod(save.bonus)]
]

// A single skill row: proficiency marker, name (emphasised by proficiency), and the computed bonus.
// - An `eff-check-advantage` skill trails its name with the advantage hexagon.
// - The badge sits inside the 1fr name cell, thus it cannot widen the card's skills grid.
#let skill-row(sk, data) = {
  let weight = if data.level != none { "bold" } else { "regular" }
  let size = 7.5pt
  grid(
    columns: (8pt, 1fr, auto),
    align: (center + horizon, left + horizon, right + horizon),
    gutter: 2pt,
    prof-mark(data),
    text(font: body-font, size: size, weight: weight)[
      #sk.name#if data.at("advantage", default: false) [ #adv-badge(size: size * 0.85)]
    ],
    text(font: body-font, size: size, weight: weight)[#fmt-mod(data.bonus)],
  )
}

// One class, subclass first and no parens: "Great Old One Warlock 9".
#let _identity-class(cls) = {
  let s = ""
  if cls.at("subclass", default: none) != none { s += cls.subclass + " " }
  s + cls.name + " " + str(cls.level)
}

// The peer identity facts, one part per fact: species, then each class. The placard packs these into lines itself, so they stay a list here.
#let identity-parts(c) = {
  let parts = ()
  if c.species != none { parts.push(c.species.name) }
  parts + c.classes.map(_identity-class)
}

// The identity line: "Orc · Fighter 1 · Great Old One Warlock 9".
#let identity-line(c) = identity-parts(c).join(meta-sep)

// Title-case a kebab/space key for display ("herbalism-kit" -> "Herbalism Kit").
#let titly(s) = s.split("-").map(w => upper(w.first()) + w.slice(1)).join(" ")

// A comma-joined, title-cased list — the display form of a proficiency-key list. Both layouts render these (the card as an inline tier-2 line, the letter as a labelled block); they share the data form, separate from the styling.
#let titly-list(items) = items.map(titly).join(", ")

// Print a value, or a quiet (rule-colour) em dash when absent — for optional stat fields (Size, Alignment), separate from table cells (whose empty-cell dash is plain ink, matching the cell text).
#let or-dash(v) = if v == none { text(fill: rule-color)[—] } else { v }

// Display label for a tool-proficiency id. Tool proficiencies are stored as apostrophe-free ids; recover the catalog's canonical name (which carries the typographic apostrophe — "Calligrapher’s Supplies") rather than title-casing the id (which would drop it). Falls back to `titly` for ids missing from the catalog.
#let tool-label(id) = {
  let t = tool.at(id, default: none)
  if t != none { t.name } else { titly(id) }
}

// Spell-level label: 0 -> "Cantrips", otherwise "1st Level" etc.
#let ordinal(n) = if n == 1 { "1st" } else if n == 2 { "2nd" } else if n == 3 { "3rd" } else { str(n) + "th" }

// Vertical rhythm shared by every card/section so headings sit in step:
// - `rule-gap`: a card title's rule line to its first content.
// - `head-gap`: a section heading to its own content (tight, so they bind).
// - `section-gap`: between stacked sections on a card (looser than head-gap).
// The two section gaps stay clearly different: a heading hugs the content below it, and the air goes above the next section, separate from beneath its heading.
#let rule-gap = 4pt
#let head-gap = 2.5pt
#let section-gap = 16pt

// Mirrors `section-gap`'s role, for the letter sheet: the gap between one top-level framed-box/section and the next, on either page. One unified value, so every letter transition from one block's end to the next block's start — including a heading, and including a table-to-table gap like attack-table -> Cunning Strike table — routes through this one token instead of a repeated literal `v(8pt)`.
#let letter-section-gap = 8pt

// The standard gutter between side-by-side columns (the card masthead/skills/footer grids, the letter's two macro-columns, the identity meta row, the armor-training marks) — one token instead of a repeated literal 8pt. Tighter intra-box grids (5pt) and the wide N-up list gutter (14pt) stay separate from this.
#let grid-gutter = 8pt

// Tabular rhythm, defined here once and shared by every table and stacked list (via `sheet-table` / `stacked-lines` below) — the reason those builders exist.
// - Invariant: the gap between rows/items must exceed the leading between wrapped lines within a row/item, or a cell whose content wraps reads with looser spacing than the rows themselves (structure inverted).
// - `dense-leading`: leading between wrapped lines inside a cell/item.
// - `row-inset`: table cell y-inset; the between-row gap is 2*row-inset.
// - `row-gap`: spacing between stacked wrapping items.
// All three are `em`-relative, so they scale with font size: the dense 6x4 cards (8pt) get proportionally tight gaps while the roomy letter (9.5pt) gets looser ones, from one definition. The invariant holds by construction at every size: 2*row-inset (0.64em) and row-gap (0.62em) both exceed dense-leading (0.5em).
#let dense-leading = 0.5em
#let row-inset = 0.32em
#let row-gap = 0.62em
// Gap between eyebrow-headed source groups inside one feature box (the grouped Features & Traits / Class Features lists): wider than `row-gap` so groups read as units, narrower than a full between-section gap.
#let group-gap = 1.1em

// The one table constructor. Every sheet table routes through this so the rhythm above lives in a single place and no table can pick a bespoke (wrong) inset or leading.
// - Owns the cell text style: a `set text(font: body-font, size)` so every body cell reads in the body font at the shared `size`. A cell that wants emphasis wraps its content in `text(weight: …)`/`emph`, nothing more. The `label`-styled headers set their own font, so the rule skips them.
// - `headers` are plain strings (rendered as 5.5pt labels); `rows` is an array of content-cell arrays; `align` passes straight through to `table` (a single alignment, a per-column array, or a function).
// - `atomic-rows` (both the letter's page-spanning spell table AND the card deck's spell table) marks every body cell `breakable: false`, so a row skips a mid-cell split across a page/card break — it bumps whole to the next region instead. On the cards it pairs with `keep-groups`: a level-group bumps intact when it fits a card, and a group taller than a card splits between rows rather than mid-cell.
// - The returned table is wrapped in a zero-spacing block (mirroring `feature-box`/`keep-together`'s own `block(spacing: 0pt, …)`): a bare `table()` placed in flow otherwise carries Typst's default block spacing on top of whatever explicit gap a caller places around it (`v(section-gap)`, `v(head-gap)`, …), silently doubling that gap wherever two such tables are adjacent (e.g. attack-table -> Cunning Strike table) while a spot already wrapped in a zero-spacing block (a `feature-box` heading) reads correctly — a real, visible inconsistency. Zeroing it here, once, makes every explicit gap around a sheet-table exact by construction.
// - `width: 100%` avoids the auto-width block collapsing a `1fr` column to near-zero (the same trap `keep-together`'s `measure` guards against).
#let sheet-table(columns, headers, rows, align: left + top, size: 8pt, atomic-rows: false) = {
  set par(leading: dense-leading)
  set text(font: body-font, size: size)
  let cell = if atomic-rows { c => table.cell(breakable: false, c) } else { c => c }
  // `rows.len()` — the row count (each element is one row's cells) — separate from `rows.flatten().len()` (the flattened cell count, used below to pass cells to `table()`): with >1 column the cell count always exceeds the real last-row index, so comparing against it below would miss every actual row and silently leave the last row's bottom inset un-zeroed.
  let last-row = rows.len()
  block(width: 100%, spacing: 0pt, table(
    columns: columns,
    // The header's own top inset and the last row's own bottom inset are
    // zeroed: without this, a table's rendered edge sits `row-inset` further
    // from its own ink than a bare heading's clamped text does (section-head
    // clamps `top-edge`/`bottom-edge` to the glyphs), so an explicit gap
    // (`v(section-gap)`) reads visibly looser next to a table than next to a
    // heading even though both call sites pass the identical token. Every
    // *interior* row keeps the normal row-inset on both sides.
    inset: (x, y) => (
      left: 4pt, right: 4pt,
      top: if y == 0 { 0pt } else { row-inset },
      bottom: if y == last-row { 0pt } else { row-inset },
    ),
    stroke: (x, y) => if y == 0 { (bottom: 0.6pt + rule-color) } else { none },
    align: align,
    table.header(..headers.map(h => label(h, size: 5.5pt))),
    ..rows.flatten().map(cell),
  ))
}

// Keep a block from splitting across a page break — unless it is taller than the page region on its own, in which case it must split (there is nowhere it would fit whole).
// - Drives the card deck's overflow policy: a unit (e.g. a spell level-group) bumps intact to a fresh card when it does not fit the space left, and only splits when a single unit exceeds a whole card.
// - `region.height` is the full page body height (what `layout` reports in the top-level flow), so the test reads "bigger than a card", separate from "bigger than the space remaining".
// - The outer `block(spacing: 0pt, …)` zeroes the gap around a unit: the `context`/`layout` wrapper is itself a block with default spacing, so setting `spacing: 0pt` only on the inner block leaves that outer gap in place (it stacks on top of the caller's `v(…)` and inflates the list). Callers place the exact gaps between units themselves (`v(section-gap)` / `v(row-gap)`).
#let keep-together(body) = block(spacing: 0pt, context layout(region => {
  // Measure at the real content width (`box(width: region.width, …)`): a bare `measure` lays the body out unconstrained, which collapses a `1fr` table column to near-zero width and reports a wildly inflated height.
  let need = measure(box(width: region.width, body)).height
  block(breakable: need > region.height, spacing: 0pt, body)
}))

// The one stacked-list constructor for wrapping items (feature "name — desc" lines, bullet inventories, proficiency lines). Same invariant as `sheet-table`: intra-item wrapped lines use `dense-leading`; the between-item gap is `row-gap`, which is larger. `items` is an array of content.
#let stacked-lines(items) = {
  set par(leading: dense-leading)
  stack(spacing: row-gap, ..items)
}

// A `stacked-lines` list partitioned into N side-by-side columns of roughly equal item count (the Gear card's Inventory) — mirrors the skills-grid slice pattern (card.typ `_core-card`).
// - Items are sliced by count up front, separate from flow/balance, so each column is a plain `stacked-lines` in its own grid cell — a real N-up grid, avoiding a snake that dumps a short tail list into a single lopsided column.
// - `columns` is clamped to `items.len()` (and a too-short list falls back to one `stacked-lines` column) so a handful of items leaves no empty grid cells.
#let stacked-lines-columns(items, columns: 2, column-gutter: 14pt) = {
  let n = calc.max(1, calc.min(columns, items.len()))
  if n <= 1 { return stacked-lines(items) }
  let rows-per-col = calc.ceil(items.len() / n)
  let cols = range(n).map(ci => items.slice(
    ci * rows-per-col, calc.min((ci + 1) * rows-per-col, items.len()),
  ))
  grid(columns: n * (1fr,), column-gutter: column-gutter, ..cols.map(stacked-lines))
}

// A bulleted inventory list: one "• item" line per entry, as a single `stacked-lines` column or an N-up grid. Shared by the Gear card's Inventory (2 columns) and the letter's Equipment box (1 column).
#let bullet-lines(items, size: 8pt, columns: 1) = stacked-lines-columns(
  items.map(e => text(font: body-font, size: size)[• #e]),
  columns: columns,
)

// The one section-heading style, shared by card section heads, spell-level heads, and (matching) the letter's framed-box titles: Montserrat, bold, accent, uppercase, letter-spaced to read as small-caps labels. `top-edge`/`bottom-edge` clamp the line box to the glyphs so head-gap/section-gap are the visible gaps — otherwise the font's leading floats the caps high in their box, stealing space above and adding phantom space below.
#let section-head(title, size: 7.5pt) = text(
  font: label-font, size: size, weight: "bold", fill: accent, tracking: 0.6pt,
  top-edge: "cap-height", bottom-edge: "baseline",
)[#upper(title)]

// A section heading bound to the content beneath it so the heading stays off the foot of a card/page.
// - The heading is a sticky block: when its body must split across a break (taller than a card under `keep-together`, or the letter's page flow), Typst carries a sticky block to the next region together with the block that follows it — the heading lands with at least the top of its body instead of orphaning.
// - A `stack(spacing: head-gap, heading, body)` cannot do this: a stack skips flow layout, so it ignores stickiness and lets a break land between the heading and the body.
// - `below: gap` reproduces the exact heading→body gap (bodies here — `sheet-table`, `limited-use-lines` — carry zero surrounding spacing), and `above: 0pt` leaves the caller's leading gap (`v(section-gap)`) as the only space above the heading.
#let sticky-head(heading, body, gap: head-gap) = {
  block(sticky: true, above: 0pt, below: gap, breakable: false, heading)
  body
}

// The Spellcasting header: a table (only when there are sources) whose first column labels the sources and whose columns give the casting ability, its modifier, attack bonus, and save DC. The modifier is the source's own resolver-carried `modifier` — display reads this field directly, since `attack` may include item bonuses (Rod of the Pact Keeper).
// Sources whose four displayed values all match share one row, their names joined by "/": a character with a species cantrip, two feat grants and a caster class (Elara) casts everything off one Charisma at one attack bonus and one DC, and four rows of identical numbers say that once each. Sources still differ where the numbers do — a Rod of the Pact Keeper scoped to "Warlock" splits attack and DC away from a feat's own, so those keep their own rows.
// The merge is display-only. `c.spellcasting` stays per-source everywhere else: `spell-table` groups by it, `merge-slots` reads each source's slots, and `resolve-spellcasting` projects `eff-spell-any-slot` between sources.
#let spellcasting-head(sources, size: 8pt, source-label: "Spellcasting") = if sources.len() > 0 {
  // Group on the four displayed values, in first-occurrence order (`group-by`, shared with `trait-groups`).
  let rows = group-by(sources, s => (s.ability, s.modifier, s.attack, s.save-dc))
    .map(g => (names: g.items.map(s => s.source), stats: g.items.first()))
  sheet-table(
    (1fr, auto, auto, auto, auto),
    (source-label, "Ability", "Modifier", "Attack Bonus", "Save DC"),
    rows.map(r => (
      // One `eyebrow` for the whole joined label: the separator carries the same accent and tracking as the names, so the cell reads as one label rather than several styled runs.
      // Each name is boxed, so the only breakable points are the separators: the letter's Source column is narrow enough that a long merged label wraps, and it must break between two sources rather than through the middle of "Magic Initiate (Druid)".
      eyebrow(r.names.map(n => box(n)).join(" / "), size: size - 1.5pt),
      [#ability-names.at(r.stats.ability)],
      [#fmt-mod(r.stats.modifier)],
      [#fmt-mod(r.stats.attack)],
      [#r.stats.save-dc],
    )),
    align: (left + horizon, left + horizon, center + horizon, center + horizon, center + horizon),
    size: size,
  )
}

// A small filled up-triangle — the notation for a spell's per-slot upcast scaling.
// - Drawn (the sheet fonts lack a unicode glyph), like the clock/AoE icons.
// - A distinct shape from the circle/diamond/hexagon marker vocabulary: scaling is separate from proficiency (circle), resource tracking (diamond), and save advantage (hexagon), so it earns its own filled-accent glyph.
// - Used in two places: trailing a spell's `scaling` prose in the SPELLS table's DAMAGE/EFFECT cell, and — mark only, no prose — flagging an upcastable spell in the card deck's ATTACK / Bonus Action / Reaction notes.
#let _scaling-mark(s) = box(baseline: 0.1em, width: s, height: s)[
  #place(polygon(fill: accent, (s / 2, s * 0.12), (s * 0.9, s * 0.88), (s * 0.1, s * 0.88)))
]

// True when a spell can be cast with a higher-level slot to greater effect — it carries `scaling` prose and stays free of a fixed slot (a warlock's pact slots). Cantrips scale by character level, so they skip this.
#let _upcastable(s) = s.at("level", default: 0) != 0 and not s.at("fixed-slot", default: false) and s.at("scaling", default: none) != none

// A spell's name where it titles a row of the card deck's action-economy tables (ATTACK / BONUS ACTION / REACTION), which mix spells with weapon attacks, features, feats and magic items.
// - Italic, so a row that is a spell reads as one at a glance. It is the only italic in these name columns, and the level marker leading the Notes cell ("1°.") is too easy to miss on its own.
// - A multi-beam cantrip (Eldritch Blast ×2) keeps its count, upright and outside the emphasis: the count is a quantity, not part of the name. Same shape as the SPELLS table's SPELL cell, and the Damage cell beside it reads per beam.
#let spell-name-cell(s) = {
  let cnt = s.at("count", default: none)
  [#emph(s.name)#if cnt != none [$thin times #cnt$]]
}

// A spell's note for the card deck's action-economy tables (ATTACK / BONUS ACTION / REACTION).
// - Leads with an italic level marker — the word "Cantrip." for a cantrip, else the spell's level in degree notation: "1°."/"2°."/"5°.".
// - The digit is drawn from `text-font`, opting out of `body-font`'s Euler covers: Euler has no italic face, so a covered digit stays upright beside the italic "Cantrip.". ETBembo italic sets it as an old-style figure.
// - When `include-damage` is set (the 2-column Bonus Action / Reaction tables have no Damage column), the resolved damage or healing, then the spell's own `notes` prose.
// - The ATTACK table shows damage in its own column, so it calls with the default `include-damage: false` (marker + notes only).
// - When the spell is upcastable, the filled up-triangle ▲ trails the whole note (the mark only — the scaling prose stays in the SPELLS table; these rows are terse).
#let spell-action-note(s, include-damage: false) = {
  let mark = if s.level == 0 { [_Cantrip._] } else { [_#text(font: text-font)[#s.level]°._] }
  let parts = ()
  if include-damage {
    if s.at("healing", default: none) != none {
      parts.push[Heals #fmt-dice(s.healing).]
    } else if s.at("damage", default: none) != none {
      parts.push(fmt-spell-damage(
        s.damage,
        type: s.at("damage-type", default: none),
        label: s.at("damage-label", default: none),
      ))
    }
  }
  if s.at("notes", default: none) != none { parts.push[#s.notes] }
  [#mark#if parts.len() > 0 [ #parts.join[ ]]#if _upcastable(s) [ #_scaling-mark(0.9em)]]
}

// Area-of-effect glyphs, drawn (the sheet's ETBembo/Montserrat fonts lack unicode glyphs) so they render and scale with the surrounding text. Each is a small line-art icon in an `s`-square box: square/circle are the flat footprints; cube/sphere/cylinder add a 3-D cue (an isometric edge set, an equator, a capped body); line is a bar; cone a triangle emanating from a point. Used in the RANGE column as "«icon» 20 ft" beside a spell's range.
#let _aoe-icon(shape, s) = {
  let sw = 0.6pt + ink
  box(baseline: 0.15em, width: s, height: s)[
    #if shape == "square" {
      place(rect(width: s, height: s, stroke: sw))
    } else if shape == "circle" {
      place(circle(radius: s / 2, stroke: sw))
    } else if shape == "sphere" {
      place(circle(radius: s / 2, stroke: sw))
      place(center + horizon, ellipse(width: s, height: s * 0.42, stroke: sw))
    } else if shape == "cube" {
      let o = s * 0.32
      // Outer silhouette hexagon, then the three near-corner edges that read as a cube.
      place(polygon(stroke: sw, fill: none,
        (o, 0pt), (s, 0pt), (s, s - o), (s - o, s), (0pt, s), (0pt, o)))
      place(line(start: (0pt, o), end: (s - o, o), stroke: sw))
      place(line(start: (s - o, o), end: (s, 0pt), stroke: sw))
      place(line(start: (s - o, o), end: (s - o, s), stroke: sw))
    } else if shape == "cylinder" {
      let h = s * 0.34
      place(top, ellipse(width: s, height: h, stroke: sw))
      place(bottom, ellipse(width: s, height: h, stroke: sw))
      place(line(start: (0pt, h / 2), end: (0pt, s - h / 2), stroke: sw))
      place(line(start: (s, h / 2), end: (s, s - h / 2), stroke: sw))
    } else if shape == "line" {
      place(horizon, rect(width: s, height: s * 0.24, fill: ink, stroke: none))
    } else if shape == "cone" {
      place(polygon(stroke: sw, fill: none, (0pt, s / 2), (s, 0pt), (s, s)))
    }
  ]
}

// A spell's RANGE, with the area of effect (glyph + size) in parentheses. Shared by the SPELLS table and the ATTACK table's spell rows, so a spell's range reads the same on both.
#let _spell-range-cell(s, isize) = {
  let range = s.at("range", default: none)
  let range-cell = if range == none { [—] } else { [#range] }
  let area = s.at("area", default: none)
  if area != none {
    range-cell = [#range-cell (#_aoe-icon(area.shape, isize)#h(2pt)#area.size)]
  }
  range-cell
}

// A spell's HIT/SAVE: spell-attack bonus ("+5"), else save ("WIS 14"), else an em-dash. Shared by the SPELLS table and the ATTACK table's spell rows.
#let _spell-hit-cell(s) = if s.at("attack", default: false) {
  fmt-mod(s.attack-bonus)
} else if s.save != none {
  fmt-save(s.save, s.save-dc)
} else { [—] }

// A weapon attack's RANGE: the range the attack is made at — a melee weapon's reach, a ranged weapon's projectile range. A Thrown weapon adds its throw range after the reach; the Thrown property in the Notes cell is what names that second number, keeping this cell narrow enough that its `auto` column does not squeeze Notes on the letter's tight weapons box. A hand-rolled weapon may declare neither range.
#let _attack-range-cell(a) = {
  let r = a.at("range", default: none)
  let t = a.at("thrown-range", default: none)
  if t == none and r == none { [—] }
  else if t == none { [#r] }
  else if r == none { [#t] }
  else [#r · #t]
}

// Attack table: Name / Range / Hit / Damage & Type / Notes. Weapons first (from `attacks`), then any actionable spells (from `spells` — resolved spells-detail dicts, routed here by casting time + attack/save in card.typ). A spell's Hit cell is its attack bonus ("+5") or its save ("INT 14"), mirroring the spell table's HIT/SAVE column; its Notes cell is `spell-action-note` (damage lives in the Damage column, so it drops from the note).
#let attack-table(attacks, attacks-per-action: 1, spells: (), size: 8pt) = if attacks.len() > 0 or spells.len() > 0 {
  let weapon-rows = attacks.map(a => (
    {
      // A weapon-attack cantrip's line (True Strike / Booming Blade / Shillelagh) names the weapon, then the cantrip it is cast through — italic, the same mark a whole spell row wears, because casting that cantrip is what this row does.
      let via = a.at("via-spell", default: none)
      let eligible = attacks-per-action > 1 and a.at("extra-attack", default: true)
      [#a.name#if via != none [ (#emph(via))]#if eligible [$thin times #attacks-per-action$]]
    },
    _attack-range-cell(a),
    [#fmt-mod(a.bonus)],
    [#fmt-dice(a.damage)#if a.damage-type != none [ #a.damage-type]],
    {
      // An explicit `note` (a Booming Blade rider line) fills the whole cell; otherwise the Notes column is the weapon's properties, with any trained mastery property (its own resolved field) italicized at the end so it reads apart from the ordinary properties.
      // A Versatile weapon's entry (also a resolved field, for the same reason) gives the damage of the grip the character is not using — "Versatile (1d10+4 two-handed)" beside a one-handed 1d8+4 in the Damage column. It carries the ability modifier already, so a player switching grips mid-fight reads the number off the sheet.
      let n = a.at("note", default: none)
      if n != none { n } else {
        let vd = a.at("versatile-damage", default: none)
        let notes = a.properties.map(p => [#p])
        if vd != none {
          notes.push[Versatile (#fmt-dice(vd) #a.versatile-grip)]
        }
        let m = a.at("mastery", default: none)
        if notes.len() == 0 and m == none [—]
        else if m == none { notes.join(", ") }
        else if notes.len() == 0 { emph(m) }
        else [#notes.join(", "), #emph(m)]
      }
    },
  ))
  let spell-rows = spells.map(s => (
    spell-name-cell(s),
    _spell-range-cell(s, size * 0.9),
    _spell-hit-cell(s),
    if s.at("damage", default: none) != none {
      fmt-spell-damage(s.damage, type: s.at("damage-type", default: none), label: s.at("damage-label", default: none))
    } else { [—] },
    spell-action-note(s),
  ))
  sheet-table(
    (auto, auto, auto, auto, 1fr),
    ("Attack", "Range", "Hit", "Damage", "Notes"),
    weapon-rows + spell-rows,
    align: (left + top, left + top, center + top, left + top, left + top),
    size: size,
  )
}

// Cunning Strike table (2024 Rogue, level 5): the non-damage riders a Rogue can add to a Sneak Attack hit. Mirrors attack-table's shape and empty-list guard — renders nothing for a character without the feature. SAVE shows "DC <n> <ABBR>" (mathified like the spell table's HIT/SAVE cell) or an em-dash for a no-save option.
#let cunning-strike-table(cunning-strikes, size: 8pt) = if cunning-strikes.len() > 0 {
  sheet-table(
    (auto, auto, auto, 1fr),
    ("Cunning Strike", "Cost", "Save", "Effect"),
    cunning-strikes.map(cs => (
      [#cs.name],
      fmt-dice(cs.cost),
      if cs.save-ability != none { fmt-save(cs.save-ability, cs.save-dc) } else { [—] },
      [#cs.note],
    )),
    align: (left + top, center + top, center + top, left + top),
    size: size,
  )
}

// Metamagic table (2024 Sorcerer, level 2): the options a Sorcerer knows to
// temporarily modify spells as they cast them. Mirrors cunning-strike-table's
// shape and empty-list guard — renders nothing for a character without the
// feature. Cost is Sorcery Points ("1 SP"), not dice, so the Cost column is
// plain text rather than `fmt-dice`.
#let metamagic-table(metamagic, size: 8pt) = if metamagic.len() > 0 {
  sheet-table(
    (auto, auto, 1fr),
    ("Metamagic", "Cost", "Effect"),
    metamagic.map(m => (
      [#m.name],
      [#m.at("cost", default: "1 SP")],
      [#m.at("notes", default: none)],
    )),
    align: (left + top, center + top, left + top),
    size: size,
  )
}

// The Notes cell of an activated feature: its own `notes` prose, led by the spell it casts when it declares one (a wand's Magic Action — `casts:`, resolved to `cast` in resolve.typ).
// - The cast line names the spell, its beam count and its range, then the damage: the numbers come from the spell catalog, so an item's prose never restates them.
// - The spell's name is italic, the one mark these tables use for a spell (`spell-name-cell`): here the row is the item, so the italic is what says a spell is involved at all.
// - The name (`×N` count included) and the range reuse the attack table's and spell table's own cells (`spell-name-cell`, `_spell-range-cell` with its AoE glyph), so a spell reads alike wherever it appears.
// - No level marker (`spell-action-note`'s "1°."): that marker names the slot spent, and an item cast spends charges.
// - A spell with no damage (Detect Magic) is name and range alone.
#let item-action-note(t) = {
  let notes = t.at("notes", default: none)
  let s = t.at("cast", default: none)
  if s == none { return notes }
  let dmg = s.at("damage", default: none)
  [Cast #spell-name-cell(s) (#_spell-range-cell(s, 0.9em))#if dmg != none [: #fmt-spell-damage(dmg, type: s.at("damage-type", default: none), label: s.at("damage-label", default: none))].#if notes != none [ #notes]]
}

// The ACTION / BONUS ACTION / REACTION tables (card deck's Actions/Feats/Traits card): a feature/trait/feat's name plus its `notes` prose. All three tables share this one shape — only the title and item list differ — so one helper is called three times instead of three near-identical functions. Mirrors attack-table/cunning-strike-table's empty-list guard.
#let activation-table(title, items, size: 8pt) = if items.len() > 0 {
  sheet-table(
    (auto, 1fr),
    (title, "Notes"),
    items.map(t => ([#t.name], item-action-note(t))),
    align: (left + top, left + top),
    size: size,
  )
}

// A small clock face — circle plus hour/minute hands — drawn to match the AoE glyphs. Prefixes a spell's duration in the DAMAGE/EFFECT column.
#let _clock-icon(s) = box(baseline: 0.15em, width: s, height: s)[
  #place(circle(radius: s / 2, stroke: 0.6pt + ink))
  #place(line(start: (s / 2, s / 2), end: (s / 2, s * 0.22), stroke: 0.6pt + ink))
  #place(line(start: (s / 2, s / 2), end: (s * 0.74, s / 2), stroke: 0.6pt + ink))
]

// A small diamond checkbox — empty (printable) or filled. Diamonds mark resource tracking: the shield flag, death saves, heroic inspiration, magic-item attunement, and expended spell slots. (Proficiency/training uses circle marks instead — see `mark-*` and `armor-training`.)
#let checkbox(filled: false, size: 7pt) = box(baseline: 0.15em, polygon(
  fill: if filled { accent } else { white },
  stroke: 0.6pt + accent,
  (size / 2, 0pt), (size, size / 2), (size / 2, size), (0pt, size / 2),
))

// Recharge kinds whose rest column cannot state the whole rule, each with its own fixed footnote symbol and note.
// - Both sit in the Long Rest column: that column names the recharge that refills the pool, and each of these adds a partial refill on top of it.
// - A kind absent from this table needs no note: its column says everything.
// - Each symbol is fixed per kind, never sequential, so the same rule always reads with the same mark across every sheet.
#let _recharge-notes = (
  "long-short-regain": (symbol: [§], note: [Regain one expended use on a Short Rest.]),
  // Escape the asterisk: a lone `*` in markup opens strong emphasis.
  "dawn": (symbol: [\*], note: [Regain 1 expended charge at dawn.]),
)

// The superscript footnote marker for a pool whose recharge carries one of the notes above.
// - Returns `none` for every other pool, so callers attach it unconditionally.
//
// Uses a metadata anchor instead of a Typst `#footnote`.
// - Nested inside the card deck's `resource-tables`, itself wrapped in `keep-together` (the whole-group card-bump mechanism), Typst's measure/retry pass for a unit that does not fit the current card can realize a real footnote on the page the retry ran on while the actual marked row renders on the page before it — an "Actions (continued)" card with only the stranded footnote on it.
// - `school-notes-footer` hits the same failure mode for the same reason; this uses the identical fix: an invisible metadata anchor, read back by the page's own footer via `query()` after layout settles, in place of Typst's footnote engine.
// - A symbol rather than a digit: a footnote reference reads as none of the drawn-icon vocabulary shapes (circle = proficiency, diamond = resource tracking, hexagon = save advantage, triangle = upcast scaling).
// - `school-notes-footer` assigns its own symbols from the sequence `*`, `†`, `‡`, ..., so `*` is shared with a school-synergy note. Only a character carrying both a dawn-recharge item and a school-synergy feature (Psychic Spells, Beguiling Magic) can land both notes on one page; move the school sequence to start at `†` if that ever happens.
#let _recharge-mark(item) = {
  let n = _recharge-notes.at(item.recharge, default: none)
  if n != none [#super[#n.symbol]#metadata(item.recharge)<recharge-marker>]
}

// A resource pool's label, shared by both trackers — the card deck's `resource-tables` and the letter's `_limited-use-row` — so the two cannot drift.
// - A pool that tracks a free cast is labelled by the spell, so it is italic like every other spell name on the sheet (`eff-limited-use`'s spell-object form sets the flag).
// - Regular weight, matching every other name column on both sheets. It was bold: ETBembo ships no bold italic, so a bold label silently drops to regular the moment it goes italic, leaving the spell pools reading lighter than the features beside them — an accidental hierarchy where only a category difference was meant.
#let _pool-label(item, size) = text(font: body-font, size: size)[
  #if item.at("spell", default: false) { emph(item.name) } else { item.name }#_recharge-mark(item)
]

// The true page-bottom counterpart to `_recharge-mark`: every recharge note whose
// marker landed on this physical page, deduped by kind (several pools can share
// one note — a Fighter/Druid has both Second Wind and Wild Shape) and rendered in
// the table's own order so two notes on one page keep a stable reading order.
// Mirrors `school-notes-footer`'s "ask what's on this page once it's known"
// idiom — see that note for why a real footnote is unsafe here.
#let recharge-footer(size) = context {
  let cur = here().page()
  let kinds = query(<recharge-marker>).filter(m => m.location().page() == cur).map(m => m.value)
  let present = _recharge-notes.pairs().filter(((k, n)) => kinds.contains(k))
  if present.len() == 0 { return none }
  text(font: body-font, size: size, present.map(((k, n)) => [#super[#n.symbol] #n.note]).join(h(6pt)))
}
// The resource tables' Uses cell (`resource-tables`, card): a row of empty diamonds to check off in play (the resource-tracking marker), with the derivation label ("PB", "DEX mod") as a tiny eyebrow inline-left of the diamonds when the count is derived — smaller than the diamonds so its presence keeps the row height identical (rows with and without a label stay the same height).
#let _uses-cell(item, size) = {
  let diamonds = box[#for i in range(item.uses) [#h(if i > 0 { 3pt } else { 0pt })#checkbox(size: size * 0.82)]]
  if item.uses-label != none {
    grid(
      columns: (auto, auto),
      align: horizon,
      column-gutter: 4pt,
      eyebrow(item.uses-label, size: size * 0.58, tracking: 0.4pt),
      diamonds,
    )
  } else { diamonds }
}

// Split the limited-use pools into the two columns both layouts render: those regainable on a short rest, and everything else.
// - `short-or-long` recharges on a short rest, thus it groups with short.
// - `long-short-regain` and `dawn` do not, thus both group with long; a footnote carries the partial refill their column cannot state (see `_recharge-notes`).
// - The buckets are defined here once; the card's `resource-tables` and the letter's `limited-use-lines` both read them.
#let recharge-buckets(items) = {
  let is-short = it => ("short", "short-or-long").contains(it.recharge)
  (short: items.filter(is-short), long: items.filter(it => not is-short(it)))
}

// The limited-use resource tables (card deck's Actions card tail).
// - One table per recharge bucket — "Short Rest" (short or short-or-long pools) and "Long Rest" — each a 2-column `sheet-table` (Resource | Uses) whose Uses cell is the diamond tracker (`_uses-cell`: empty diamonds to check off in play, with any derivation label inline-left of the diamonds).
// - The title is the recharge period as the first-column header, mirroring `activation-table("Action", ...)` so the two read as the final peers in the action sequence (... → Other → Short Rest → Long Rest) — same chrome, same rhythm, no extra heading tier.
//
// When both buckets are non-empty the pair travels together inside one `keep-together` (side-by-side, the same 28pt gutter the tracker's columns use); a single non-empty bucket is wrapped the same way so its rows stay off a card break — resources are small trackers, they should stay together (and `keep-together`'s fallback still lets a genuinely card-tall table split between rows). Either way they bump intact to a continuation "Actions (continued)" card rather than landing at a foot.
// - Items arrive pre-sorted (short-rest recoverable first, then scarcest-first, then alphabetical — see resolve.typ `resolve-limited-uses`), so each bucket keeps that order. Empty → nothing.
//
// A pool whose recharge the column cannot fully state (`long-short-regain`, `dawn`) sits in the Long Rest column and gets a superscript marker on its row — see `_recharge-mark` — with the note rendered by the page's own footer (`recharge-footer`), a metadata anchor instead of a real Typst footnote (unsafe inside this `keep-together` — see that function's note).
#let resource-tables(items, size: 8pt) = if items.len() > 0 {
  let (short, long) = recharge-buckets(items)
  let _table(bucket, title) = if bucket.len() > 0 {
    sheet-table(
      (1fr, auto),
      (title, "Uses"),
      bucket.map(it => (
        _pool-label(it, size),
        _uses-cell(it, size),
      )),
      align: (left + top, right + top),
      size: size,
    )
  }
  let s = _table(short, "Short Rest")
  let l = _table(long, "Long Rest")
  let body = if s != none and l != none {
    grid(columns: (1fr, 1fr), column-gutter: 28pt, align: top, s, l)
  } else if s != none { s }
  else { l }
  keep-together(body)
}

// Every spell-detail row across the given spellcasting sources, flattened.
// - A feat-granted spell (Magic Initiate, Fey Touched) resolves to two rows: the feat's own pinned
//   free cast (`fixed-slot`) and the `eff-spell-any-slot` projection into a source that has slots.
// - Keep only the slot cast when both are present: it is the strictly more informative row (it alone
//   carries the ▲ upcast affordance), and the free cast is already tracked as its own pool in
//   Resources, so nothing is lost.
// - Both rows otherwise render identically whenever the spell has no upcast scaling (Misty Step).
// - Leave a group alone when its rows are all fixed-slot (a warlock's pact slots) or all slot casts:
//   those differ in cast level and each says something the other does not.
// - Feeds both the SPELLS tables and the card deck's action-economy routing.
#let all-spells(sources) = {
  let rows = sources.map(s => s.spells-detail).flatten()
  let key = s => str(s.level) + "/" + s.name
  let slot-cast = rows.filter(s => not s.fixed-slot).map(key)
  rows.filter(s => not (s.fixed-slot and slot-cast.contains(key(s))))
}

// Features that read "when you cast an Enchantment or Illusion spell..." (Great Old One's Psychic Spells, College of Glamour's Beguiling Magic) declare which schools they synergize with via a plain `spell-schools` field on the feature — a list of school-name strings, the same passthrough idiom as `activation`/`notes` (see the feature model in model.typ) — rather than tagging individual spells: the rule lives on the feature's own text, so every spell of a matching school earns the footnote automatically, on any character, with no per-spell or per-character authoring. Reads `c.traits`, so it must run after `resolve()`.
#let spell-school-notes(traits) = {
  traits
    .filter(t => t.at("spell-schools", default: ()).len() > 0)
    .map(t => (name: t.name, schools: t.spell-schools))
}

// The true page-bottom counterpart to `_spell-name-cell`'s marker.
// - Queries every `<school-note-marker>` metadata anchor placed on this physical page (a `location().page()` filter, answered only once layout has settled — no measurement-pass ambiguity), dedupes by note name (several spells on one page can share a note), and renders "SYMBOL Name" pairs on one line.
// - Returns `none` when the current page has no such marker, so callers can splice it into their own footer unconditionally.
// - A page template's `footer:` is itself `context`-evaluated per page already, so this needs its own `context` only when called from plain flow content.
#let school-notes-footer(size) = context {
  let cur = here().page()
  let marks = query(<school-note-marker>).filter(m => m.location().page() == cur)
  if marks.len() == 0 { return none }
  let notes = dedup-by(marks.map(m => m.value), n => n.name)
  text(font: body-font, size: size)[#notes.map(n => [#super[#n.symbol] #n.name]).join([  ])]
}

// The page footer's one line, shared by both layouts: any note anchored to this page on the left, the page number on the right.
// - Notes come from `school-notes-footer` / `recharge-footer`; both are `none` on a page carrying neither.
// - Two notes on one page join, thus each stays visible.
// - With no note the page number renders alone, exactly as it did before there were notes.
#let footer-line(page-number, note-size) = {
  let parts = (school-notes-footer(note-size), recharge-footer(note-size)).filter(p => p != none)
  if parts.len() == 0 { page-number } else {
    grid(
      columns: (1fr, auto),
      align: (left + horizon, right + horizon),
      parts.join([ ]), page-number,
    )
  }
}

// The union of every source's expendable slot table, as one level→count dict (feeds the slot diamonds — the card's level headings, the letter's Spell Slots box).
#let merge-slots(spellcasting) = {
  let slots = (:)
  for s in spellcasting { for (k, n) in s.slots { slots.insert(k, n) } }
  slots
}

// Convert merged spell slots (level→count dict) into resource-like items
// that can be passed to `resource-tables` or `limited-use-lines`.
// Spell slots recharge on a long rest; one line per level with non-zero slots.
#let slot-resource-items(slots) = {
  slots.pairs()
    .filter(p => p.at(1) > 0)
    .sorted(key: p => int(p.at(0)))
    .map(p => (
      name: ordinal(int(p.at(0))) + " Level Spells",
      uses: p.at(1),
      recharge: "long",
      uses-label: none,
      spell: false,
    ))
}

// --- The spell table's cells, one helper per column ------------------------

// SPELL name: grows the `auto` column to fit, but capped — past a max width the name wraps instead of pushing the other columns over. Cap is em-relative (scales with `size`); `measure` here inherits the cell's size, so the test is width-in-em: `Dissonant Whispers` (~8em) stays one line, `Tasha's Hideous Laughter` (~10.4em) breaks. The name cell is measured before the school-synergy marker (below) is appended, so the marker stays out of the wrap decision.
//
// `school-notes` (see `spell-school-notes`) and `note-symbols` (a note-name -> symbol map built once per table by `spell-table`, from the same *, †, ‡, ... sequence Typst's own footnotes use) drive the marker: a spell whose `school` matches a note gets that note's symbol as a plain superscript, plus an invisible `<school-note-marker>` metadata anchor carrying the note's name and symbol. Uses a metadata anchor instead of a real Typst `#footnote` — nested inside `spell-table`'s `keep-groups` per-level `keep-together`, a footnote gets mis-paginated or dropped outright (Typst's `measure()`/region-retry pass for a card-overflowing group can realize or silently swallow it) — the metadata anchor instead lets the true page footer look the note up after layout is finalized, via `query()` (see `school-notes-footer`), the same "ask what's on this page once it's known" idiom the card deck's own running header/footer already use.
#let _spell-name-cell(s, size, school-notes: (), note-symbols: (:)) = {
  let cnt = s.at("count", default: none)
  let nm = text(weight: "medium")[#s.name#if cnt != none [$thin times #cnt$]]
  let note = school-notes.find(n => n.schools.contains(s.at("school", default: none)))
  let marker = if note == none { [] } else {
    let sym = note-symbols.at(note.name)
    [#super(text(size: size * 0.75)[#sym])#metadata((name: note.name, symbol: sym))<school-note-marker>]
  }
  // The wrap decision measures `nm` alone (the marker stays out of it), but the box that enforces the wrap — when triggered — wraps `nm` with the marker: a box is one atomic inline unit, so a marker appended outside it does not wrap along with the text inside — it sits beside the whole (now two-line-tall) box, vertically centered next to it instead of trailing the wrapped last word.
  context {
    let max-w = size * 9.2
    if measure(nm).width > max-w { box(width: max-w, [#nm#marker]) } else { [#nm#marker] }
  }
}

// Components (V/S/M) are shown in full; Concentration and Ritual are spell properties, so they live in DAMAGE/EFFECT, separate from components. A material component that has a cost shows as "M$" instead of "M".
#let _spell-comp-cell(s) = if s.components != none {
  let c = s.components
  if s.at("material-cost", default: false) { c = c.replace("M", "M$") }
  c.replace(", ", "·")
} else { [—] }

// DAMAGE/EFFECT: casting note • tags • damage/healing • notes • check, then clock+duration (unless Instantaneous / 1 round), then upcast scaling. The casting note (Reaction/B.Action/...) and the tags (Concentration/Ritual) are italicized; a Reaction folds its trigger into the casting note ("Reaction: <trigger>", only "Reaction:" italic); other non-Action times just name the time. Parts join on a black bullet separator. Absent parts drop out.
#let _spell-effect-cell(s, isize) = {
  let parts = ()
  let cast = s.at("casting-time", default: none)
  let trigger = s.at("trigger", default: none)
  if cast == "Reaction" {
    parts.push(if trigger != none [#emph[Reaction:] #trigger] else [#emph[Reaction]])
  } else if cast != none and cast != "Action" {
    parts.push(emph(cast.replace("Bonus Action", "B.Action")))
  }
  let tags = ()
  if s.concentration { tags.push("Concentration") }
  if s.ritual { tags.push("Ritual") }
  if tags.len() > 0 { parts.push(emph(tags.join(", "))) }
  if s.at("healing", default: none) != none { parts.push[Heals #fmt-dice(s.healing).] }
  else if s.at("damage", default: none) != none {
    parts.push(fmt-spell-damage(
      s.damage,
      type: s.at("damage-type", default: none),
      label: s.at("damage-label", default: none),
    ))
  }
  if s.at("notes", default: none) != none { parts.push[#s.notes] }
  // A check-to-resist (a save uses the `save` field instead): the authored check prose followed by the resolved DC and a closing period — kept out of the HIT/SAVE column, which holds attack rolls and saving throws only (Minor Illusion's Investigation vs. your spell save DC). The `check` prose carries no trailing period of its own; the sentence terminator lives here so the DC always reads "... (DC 14)." across every check spell.
  if s.at("check", default: none) != none {
    parts.push[#s.check (DC $#s.save-dc$).]
  }
  let sep = [ • ]
  // Duration hangs off the end with its clock icon and no bullet — the clock is separator enough. It follows the bullet-joined parts with a space (or opens the cell alone when nothing precedes it).
  let dur = s.at("duration", default: none)
  let dur-cell = if dur != none and dur != "Instantaneous" and dur != "1 round" {
    [#if parts.len() > 0 [ ]#_clock-icon(isize) #dur]
  } else []
  // Per-slot upcast scaling trails everything — after the duration — and only here in the SPELLS table.
  // - For a chooseable slot it sits behind the filled up-triangle marker (its own separator, no bullet).
  // - For a fixed-slot cast (pact slots) the ▲ affordance ("you may upcast this") is always suppressed — there is no choice — and the per-slot delta prose is replaced by a computed effect at the effective slot (the spell's `at-level` function, evaluated by the resolver and flagged `scaling-computed`): bullet-joined, no ▲. When `at-level` instead overrides structured fields (duration/concentration/area) it returns `scaling: none`, so nothing renders here — the cells carry it.
  // - For a fixed-slot cast without `at-level` the per-slot prose still shows, bullet-joined, so info stays. The drop heuristics below suppress the per-slot prose when a computed cell already conveys it (damage/healing) or there is no headroom (cast at the spell's own level) — they skip when `scaling-computed`, since `at-level` authored the channel.
  let fixed = s.at("fixed-slot", default: false)
  let computed = s.at("scaling-computed", default: false)
  let scaling = s.at("scaling", default: none)
  if not computed and fixed and (
    s.at("cast-level", default: 0) <= s.at("level", default: 0)
      or s.at("damage", default: none) != none
      or s.at("healing", default: none) != none
  ) { scaling = none }
  let scaling-cell = if scaling == none { [] } else if fixed {
    [#if parts.len() > 0 or dur-cell != [] [#sep]#scaling]
  } else {
    [#if parts.len() > 0 or dur-cell != [] [ ]#_scaling-mark(isize) #scaling]
  }
  if parts.len() > 0 or dur-cell != [] or scaling-cell != [] {
    [#parts.join(sep)#dur-cell#scaling-cell]
  } else [—]
}

// Spell table grouped by level, drawn from resolved spellcasting sources.
// - Columns: SPELL / RANGE (with AoE glyph + size) / HIT·SAVE ("+5" or "WIS 14") / COMP (V·S·M) / DAMAGE·EFFECT.
// - When `slots` (a level→count dict) is given, each level heading carries its slot diamonds right-justified across from it (cantrips have no slots, so none appear).
// - `keep-groups` (set by the fixed-size card deck) wraps each level-group in `keep-together`, so a group bumps intact to the next card rather than orphaning a couple of rows; the page-flow letter leaves it off (splitting is fine there).
//
// `school-notes` (see `spell-school-notes`) marks any spell whose school matches — a Great Old One warlock's Enchantment/Illusion spells reading "*Psychic Spells", say — with a symbol drawn from Typst's own footnote sequence (*, †, ‡, ...), assigned once per table so the same note always carries the same symbol; the note text itself is rendered by the page template's true bottom-of-page footer (`school-notes-footer`), separate from here — see `_spell-name-cell` for why.
#let spell-table(sources, size: 8pt, keep-groups: false, atomic-rows: false, school-notes: ()) = {
  let all = all-spells(sources)
  if all.len() == 0 { return }
  let levels = all.map(s => s.cast-level).dedup().sorted()
  let note-symbols = (:)
  for (i, n) in school-notes.enumerate() { note-symbols.insert(n.name, numbering("*", i + 1)) }

  // One level group: its heading stacked directly onto its own table with a small, exact gap.
  let level-group(lv) = {
    let rows = all.filter(s => s.cast-level == lv)
    let heading = section-head(if lv == 0 { "Cantrips" } else { ordinal(lv) + " Level" })
    // `sticky-head` binds the heading to its table so it stays off a card/page foot when a too-tall group splits (see `sticky-head`).
    let group = sticky-head(
      heading,
      sheet-table(
        (auto, auto, auto, auto, 1fr),
        ("Spell", "Range", "Hit/Save", "Comp", "Damage/Effect"),
        rows.map(s => (
          _spell-name-cell(s, size, school-notes: school-notes, note-symbols: note-symbols),
          _spell-range-cell(s, size * 0.9),
          _spell-hit-cell(s),
          _spell-comp-cell(s),
          _spell-effect-cell(s, size * 0.9),
        )),
        align: (left + top, left + top, center + top, left + top, left + top),
        size: size,
        atomic-rows: atomic-rows,
      ),
    )
    if keep-groups { keep-together(group) } else { group }
  }

  // Groups are separated by section-gap, far larger than the heading→table gap (head-gap, inside each group), so each heading unambiguously belongs to the table beneath it. They are emitted as top-level flow blocks (a manual `v(section-gap)` between them) rather than wrapped in a `stack`, because `keep-together`'s `layout` only sees the full page region when its block is a direct flow child — inside a `stack` it sees a smaller region and would split a group that actually fits a card. The gap is identical either way.
  for (i, lv) in levels.enumerate() {
    if i > 0 { v(section-gap) }
    level-group(lv)
  }
}

// ---------------------------------------------------------------------------
// Official-sheet vocabulary: framed titled boxes, labelled stat fields, and the
// left ability rail (abilities with their governing skills grouped beneath).
// All in the dndist skin (ETBembo / Montserrat / maroon), no flourishes.
// ---------------------------------------------------------------------------

// The title bar of a framed box: full-width, centred uppercase Montserrat on a pale accent fill, closed off by a bottom rule. When `continued` it appends a "(continued)" tag so a box that spilled onto a later page reads as a carry-over rather than a new section.
#let _framed-title(title, continued: false) = block(
  width: 100%,
  inset: (x: 4pt, y: 3pt),
  stroke: (bottom: 0.6pt + rule-color),
  fill: accent.lighten(90%),
)[
  #set align(center)
  #text(font: label-font, size: 7.5pt, weight: "bold", fill: accent, tracking: 0.6pt)[
    #upper(title)#if continued [#text(weight: "regular", style: "italic")[ (continued)]]
  ]
]

// A bordered box with a centred uppercase title bar and arbitrary body — the workhorse for the official sheet's titled sections (Class Features, Species Traits, Feats, Proficiencies, the roleplay boxes on page 2).
//
// `repeat-header` (used by the letter's overflowing spell box) makes the title bar repeat at the top of every page the box spans, tagged "(continued)" past the first.
// - Typst repeats only a `table.header`, and re-realises it per page, so the box body is wrapped in a single-column table whose header is the title bar, and a `context` inside it compares `here().page()` against the box's start page (recovered by querying a marker dropped at the top of the body) to decide the "(continued)" tag.
// - The marker's label is derived from the title, so each repeat-header box scopes its own start-page lookup (give two such boxes distinct titles).
// - `min-height` is meaningless when a box is meant to break, so this mode ignores it.
#let framed-box(title, body, body-inset: 6pt, min-height: auto, repeat-header: false) = block(
  width: 100%,
  breakable: true,
  stroke: 0.6pt + rule-color,
  radius: 2pt,
  inset: 0pt,
)[
  #if repeat-header {
    // `std.label`, separate from this module's `label` text helper (which shadows the built-in label constructor).
    let key = std.label("framed-cont-" + lower(title).replace(regex("[^a-z0-9]+"), "-"))
    table(
      columns: (1fr,),
      stroke: none,
      inset: 0pt,
      table.header(context {
        let hits = query(key)
        let start = if hits.len() > 0 { hits.first().location().page() } else { here().page() }
        _framed-title(title, continued: here().page() > start)
      }),
      block(width: 100%, inset: body-inset, above: 0pt)[#[#metadata(none)#key]#body],
    )
  } else {
    _framed-title(title)
    let inner = block(width: 100%, inset: body-inset, above: 0pt)[#body]
    // `min-height` is a genuine minimum, separate from a fixed height: an empty printable box reserves the space, but real content taller than it grows the box instead of overflowing the border into the box below. Measured at the actual region width (a bare `measure` lays out at ~zero width and inflates the height — the same trap as `keep-together`).
    if min-height == auto {
      inner
    } else {
      layout(size => context {
        let h = measure(box(width: size.width, inner)).height
        block(width: 100%, height: calc.max(h, min-height))[#inner]
      })
    }
  }
]

// A short underline for hand-filled blanks.
#let blank-line(width) = box(width: width, height: 8pt, stroke: (bottom: 0.5pt + rule-color))

// Shared size for the standalone flag diamonds — Shield, Death Saves, Heroic Inspiration — so they all read as the same control at a glance.
#let flag-size = 8pt

// A bordered cell shell. `height: 100%` stretches it to a fixed grid-row height (header row); the default `auto` sizes to content (safe inside an unconstrained stack — otherwise 100% resolves to the whole page).
#let _cell(body, height: auto, inset: (x: 5pt, y: 4pt)) = box(
  width: 100%, height: height, inset: inset, stroke: 0.6pt + rule-color, radius: 2pt,
)[#body]

// A value sitting above a small uppercase label (left-aligned). When the value is absent (`none`) the field becomes a blank baseline rule to hand-fill; when a value is given it prints plainly, with no fill-in line.
#let labeled-field(name, value, value-size: 9pt) = stack(
  spacing: 4pt,
  box(
    width: 100%,
    stroke: if value == none { (bottom: 0.5pt + rule-color) } else { none },
    inset: (bottom: 1pt),
  )[#text(font: body-font, size: value-size)[#if value == none { hide[0] } else { value }]],
  eyebrow(name, size: 5pt, tracking: 0.3pt),
)

// One class line for the identity box: "Fighter 1", or "Warlock 9 · Fiend" when the class has a subclass. Pairs name + level + subclass on a single line so a multiclass character reads unambiguously (one line per class).
#let _class-entry(cls) = {
  let s = cls.name + " " + str(cls.level)
  if cls.at("subclass", default: none) != none { s += " · " + cls.subclass }
  s
}

// Identity box: character name on top, then Background | Species | Type, then the classes — one line per class, so a multiclass build (e.g. Fighter 1 / Warlock 9 · Fiend) keeps each class's level and subclass together. The LEVEL box (separate) shows the summed total. A flexible gap before and after the meta rows absorbs the cell's slack.
#let identity-box(name, background, species, creature-type, classes) = _cell(height: 100%, inset: (x: 6pt, y: 5pt))[
  #labeled-field("Character Name", text(size: 11.5pt, weight: "bold", fill: accent)[#name], value-size: 11.5pt)
  #v(1fr)
  #grid(
    columns: (1fr, 1fr, 1fr),
    column-gutter: grid-gutter,
    labeled-field("Background", background, value-size: 8.5pt),
    labeled-field("Species", species, value-size: 8.5pt),
    labeled-field("Type", creature-type, value-size: 8.5pt),
  )
  #v(1fr)
  #labeled-field(
    if classes.len() > 1 { "Classes" } else { "Class" },
    if classes.len() == 0 { none } else { stack(spacing: 2pt, ..classes.map(_class-entry)) },
    value-size: 8.5pt,
  )
]

// The shield flag row under Armor Class. Level reuses a hidden copy so both header boxes reserve the same footer height and keep their big numbers aligned.
#let _shield-row(filled) = [#checkbox(filled: filled, size: flag-size)#h(2pt)#label("Shield", size: 5pt, color: accent)]

// A header box with a centred big number: title at the top, the number centred in the space below, and a footer row at the bottom. Level and Armor Class share this so their numbers sit on the same baseline at the same size.
#let _header-number-box(name, value, footer) = _cell(height: 100%, inset: (x: 4pt, y: 3pt))[
  #set align(center)
  #label(name, size: 5pt, color: accent)
  #v(1fr)
  #big-num(value, 19pt)
  #v(1fr)
  #footer
]

// Total character level box.
#let level-box(level) = _header-number-box("Levels", level, hide(_shield-row(false)))

// Armor Class box with a shield checkbox (filled when a shield is equipped).
#let ac-box(ac, has-shield) = _header-number-box("Armor Class", ac, _shield-row(has-shield))

// Hit Points box: big Current (blank) on the left; Temp above Max on the right. Current and Max are bottom-aligned so their labels sit on the same line.
#let hp-box(max-hp, temp-hp) = _cell(height: 100%)[
  #set align(center)
  #label("Hit Points", size: 5pt, color: accent)
  #v(3pt)
  #grid(
    columns: (1.2fr, 1fr),
    column-gutter: 5pt,
    align: bottom,
    [#blank-line(34pt) #linebreak() #label("Current", size: 4.5pt)],
    stack(spacing: 4pt,
      [#if temp-hp > 0 [#big-num(temp-hp, 9pt)] else [#blank-line(18pt)] #linebreak() #label("Temp", size: 4.5pt)],
      [#big-num(max-hp, 11pt) #linebreak() #label("Max", size: 4.5pt)],
    ),
  )
]

// Hit Dice box: Spent (blank, hand-filled) above the computed Max pool.
#let hit-dice-box(max) = _cell(height: 100%)[
  #set align(center)
  #label("Hit Dice", size: 5pt, color: accent)
  #v(3pt)
  #stack(spacing: 6pt,
    [#blank-line(28pt) #linebreak() #label("Spent", size: 4.5pt)],
    [#big-num(max, 11pt) #linebreak() #label("Max", size: 4.5pt)],
  )
]

// Death Saves box: three success + three failure diamond checkboxes (empty, to fill in), drawn at the shared flag size. The row pair is centred in the space below the title.
#let death-saves-box() = _cell(height: 100%)[
  #set align(center)
  #label("Death Saves", size: 5pt, color: accent)
  #v(1fr)
  #let pip = checkbox(size: flag-size)
  #let pips = [#pip#h(3pt)#pip#h(3pt)#pip]
  #grid(
    columns: (auto, auto),
    column-gutter: 5pt,
    row-gutter: 5pt,
    align: (left + horizon, left + horizon),
    text(font: body-font, size: 8pt)[Successes], pips,
    text(font: body-font, size: 8pt)[Failures], pips,
  )
  #v(1fr)
]

// A row of coins (CP / SP / EP / GP / PP). `coins` is a denom->amount dict; a denomination with no amount stays a blank line for hand-fill.
#let coins-box(coins: (:)) = grid(
  columns: 5 * (1fr,),
  column-gutter: 4pt,
  align: center,
  ..(("PP", "pp"), ("GP", "gp"), ("EP", "ep"), ("SP", "sp"), ("CP", "cp")).map(((disp, key)) => {
    let v = coins.at(key, default: none)
    [
      #if v != none { big-num(v, 10pt) } else { blank-line(100%) }
      #linebreak() #label(disp, size: 5pt, color: accent)
    ]
  }),
)

// Spell-slots grid: all nine levels in a 3x3 layout. The number of slots is always known, so a level draws exactly that many (pen-markable) diamonds; levels with no slots are dimmed. Rows are a fixed height with their contents vertically centred, so the LEVEL labels sit on an even rhythm whether or not a level carries diamonds — the diamonds stay off their row's height.
#let slots-grid(slots) = {
  let cell(n) = {
    let total = slots.at(str(n), default: 0)
    grid(
      columns: (auto, 1fr),
      column-gutter: 6pt,
      align: (left + horizon, left + horizon),
      text(font: label-font, size: 6.5pt, fill: if total > 0 { accent } else { rule-color })[LEVEL #n],
      if total > 0 {
        box(baseline: 0.3em)[#for _ in range(total) [#checkbox(size: 11pt)#h(3pt)]]
      } else { [] },
    )
  }
  grid(
    columns: 3 * (1fr,),
    column-gutter: 10pt,
    rows: 3 * (16pt,),
    align: horizon,
    ..range(1, 10).map(n => cell(n)),
  )
}

// A single labelled stat box (value big, label below) that fills its grid cell —
// for the Initiative / Speed / Size / Passive Perception / Proficiency Bonus row.
#let stat-box(name, value, big: false, height: auto) = _cell(height: height, inset: (x: 3pt, y: 4pt))[
  #set align(center + horizon)
  #stack(
    spacing: 3pt,
    text(font: body-font, size: if big { 16pt } else { 13pt }, weight: "bold")[#num-value(value)],
    label(name, size: 5pt, color: accent),
  )
]

// Heroic Inspiration box: an empty checkbox with its label.
#let inspiration-box(height: auto) = _cell(height: height, inset: (x: 3pt, y: 4pt))[
  #set align(center + horizon)
  #stack(
    spacing: 3pt,
    checkbox(size: flag-size),
    label("Heroic Inspiration", size: 5pt, color: accent),
  )
]

// Armor training: Light / Medium / Heavy / Shields marks, ticked from the character's armor proficiencies (keys are lowercase: light/medium/heavy/shield). These are proficiency marks, so they use the circle vocabulary (filled ● / empty ○), separate from the diamond `checkbox` reserved for resource tracking.
#let armor-training(armor-profs) = {
  let norm = armor-profs.map(p => lower(p))
  let cats = (("Light", "light"), ("Medium", "medium"), ("Heavy", "heavy"), ("Shields", "shield"))
  grid(
    columns: 4 * (auto,),
    column-gutter: grid-gutter,
    align: horizon,
    ..cats.map(((label-text, key)) => [
      #box(baseline: 0.5pt, if norm.contains(key) { mark-full(prof-mark-size) } else { mark-empty(prof-mark-size) })#h(2pt)#text(font: body-font, size: 7.5pt)[#label-text]
    ]),
  )
}

// Ability score in a box; ability modifier in a (slightly larger) circle.
#let _score-box(score) = box(
  stroke: 0.7pt + rule-color, radius: 2pt, fill: white, inset: (x: 6pt, y: 3.5pt),
)[#big-num(score, 12.5pt)]

#let _mod-circle(mod) = circle(
  radius: 14.5pt, stroke: 0.9pt + accent, fill: white, inset: 0pt,
)[#align(center + horizon)[#text(font: body-font, size: 14pt, weight: "bold")[#fmt-mod(mod)]]]

// One entry in the left ability rail: ability abbreviation, score box + modifier circle, a Saving Throw row, then the skills governed by that ability (already rendered via `skill-row`). The official left-rail grouping in the dndist skin.
#let ability-rail-cell(abbr, score, mod, save, skill-rows) = block(
  width: 100%,
  breakable: false,
  stroke: 0.5pt + rule-color,
  radius: 2pt,
  inset: (x: 4pt, y: 4pt),
)[
  #grid(
    columns: (1fr, auto, auto),
    column-gutter: 5pt,
    align: (left + horizon, center + horizon, center + horizon),
    text(font: label-font, size: 8pt, weight: "bold", fill: accent)[#upper(abbr)],
    stack(spacing: 1.5pt, _score-box(score), label("Score", size: 4pt, color: accent)),
    stack(spacing: 1.5pt, _mod-circle(mod), label("Mod", size: 4pt, color: accent)),
  )
  #v(2pt)
  #grid(
    columns: (8pt, 1fr, auto),
    align: (center + horizon, left + horizon, right + horizon),
    gutter: 2pt,
    if save.proficient { mark-full(prof-mark-size) } else { mark-empty(prof-mark-size) },
    text(font: body-font, size: 7.5pt, weight: if save.proficient { "bold" } else { "regular" })[Saving Throw],
    text(font: body-font, size: 7.5pt, weight: if save.proficient { "bold" } else { "regular" })[#fmt-mod(save.bonus)],
  )
  #if skill-rows.len() > 0 {
    v(2pt)
    line(length: 100%, stroke: 0.3pt + rule-color)
    v(2pt)
    stack(spacing: 2.5pt, ..skill-rows)
  }
]

// One feature "name — desc" line: bold name, then any source tags (subclass / feat category / granter — see `feature-tags`) as a tiny accent eyebrow, sized well under the line so tagged and untagged rows keep identical height (the `_limited-use-row` label trick), then an em-dash and the optional description.
#let _feature-line(f, size: 8pt, tags: ()) = text(font: body-font, size: size)[
  #text(weight: "bold")[#f.name]#{
    if tags.len() > 0 {
      h(0.45em)
      // Multiple tags join on a middot separator; no leading dot — the size drop already sets the tag off from the name.
      eyebrow(tags.join(" · "), size: size * 0.62, tracking: 0.4pt)
    }
  }#if f.at("desc", default: none) != none [ — #f.desc]
]

// Fold each sub-ability into the entry of the feature that grants it (`subs`), keeping the rest in declaration order.
// - These lists enumerate features: a magic item, a feat, or a trait earns one entry, and a sub-ability declared under it (Regain Pact Slot under the Rod, Telekinetic Shove under Telekinetic, Emerge under Shell Defense, Divine Spark under Channel Divinity) is part of that entry, not a peer of it.
// - `via-name` is the immediate granter (resolve.typ `flatten-features`), matched against the entries of this same list, so a sub-ability whose granter is absent (no `desc`, or a different group — a feat granted by an invocation) stays a top-level entry with its granter tag.
// - Depth-first flattening puts a granter before what it grants, so a single pass over the entries already built finds it.
#let _fold-sub-features(items) = {
  let out = ()
  for f in items {
    let via = f.at("via-name", default: none)
    let i = if via == none { none } else { out.position(x => x.name == via) }
    if i == none {
      out.push(f)
    } else {
      let p = out.at(i)
      p.subs = p.at("subs", default: ()) + (f,)
      out.at(i) = p
    }
  }
  out
}

// One feature entry: its own line, then an indented line per sub-ability folded into it.
// - The sub-lines sit at the wrapped-line rhythm, so the entry reads as one unit against the wider gap between entries (the `stacked-lines` invariant).
// - A sub-line drops the granter tag: the line it is indented under is the granter.
#let feature-item(f, size: 8pt) = {
  let subs = f.at("subs", default: ())
  let line = _feature-line(f, size: size, tags: feature-tags(f))
  if subs.len() == 0 { return line }
  block(spacing: 0pt, {
    set par(spacing: dense-leading)
    set block(spacing: dense-leading)
    line
    for s in subs {
      pad(left: 1em, _feature-line(s, size: size, tags: feature-tags(s).filter(t => t != f.name)))
    }
  })
}

// A list of feature items. `keep-items` (fixed-size card deck) emits each item as a `keep-together` flow block so a multi-line feature skips a mid-sentence split across a card break — items must be direct flow children (a manual `v(row-gap)` between them), separate from a `stack`, or `keep-together`'s `layout` sees a shrunken region (see `spell-table`). The page-flow letter leaves it off and uses the plain `stacked-lines`.
//
// `head` (keep-items only) is a section heading bundled into the first item's keep-together block (heading + head-gap + first item as one atomic unit), so the heading stays off the foot of a card with its items bumped to the next — it bumps together with at least its first item. Later items stay their own keep-together blocks, so a long list still splits between items.
#let feature-lines(entries, size: 8pt, keep-items: false, head: none) = {
  // Every feature list — grouped or flat, both layouts — comes through here, so the one-entry-per-feature fold lives here too.
  let items = _fold-sub-features(entries)
  if not keep-items {
    stacked-lines(items.map(f => feature-item(f, size: size)))
  } else {
    set par(leading: dense-leading)
    for (i, f) in items.enumerate() {
      if i > 0 { v(row-gap) }
      if i == 0 and head != none {
        // Bind via a `stack` (separate from free-flow `head; v(head-gap); item`): a stack lays its children out with exactly `head-gap` between them, whereas free-flow lets the heading paragraph's block spacing sneak in on top of the `v()`, loosening the after-header gap. This mirrors the spell-group heading stack.
        keep-together(stack(spacing: head-gap, head, feature-item(f, size: size)))
      } else {
        keep-together(feature-item(f, size: size))
      }
    }
  }
}

// The limited-use resource tracker (letter sheet's Resources box). One row per resource: the feature name on the left (the feature itself is described in the traits/feats sections, so the name alone suffices here), the use count as empty diamonds on the right (the resource marker; the count is already resolved to a concrete int), with the uses-label ("PB") as a tiny eyebrow left of the diamonds only when the count is derived. The recharge period is conveyed by the column the row sits in (see `limited-use-lines` below), separate from a per-row label.
//
#let _limited-use-row(item, size) = grid(
  columns: (1fr, auto),
  align: (left + horizon, right + horizon),
  column-gutter: 5pt,
  _pool-label(item, size),
  _uses-cell(item, size),
)

// A titled column of resource rows (empty → nothing).
#let _limited-use-column(items, header, size) = if items.len() > 0 {
  set par(leading: dense-leading)
  stack(
    spacing: row-gap,
    eyebrow(header, size: size * 0.72, tracking: 0.6pt),
    ..items.map(it => _limited-use-row(it, size)),
  )
}

// Split the pools by recharge: those regainable on a short rest (short or short-or-long) and long-rest pools.
// - With `single-column: false` (the card deck), the two buckets sit side-by-side when both are non-empty (else a single full-width column).
// - With `single-column: true` (the letter's narrow Resources box, too tight for two columns), the two labelled buckets stack vertically instead.
// - Items arrive pre-sorted (scarcest first, then alphabetical), so each column keeps that order.
//
// A pool whose recharge the column cannot fully state (`long-short-regain`, `dawn`) sits in the Long Rest column and gets a superscript marker on its row — see `_recharge-mark` — with the note rendered by the page's own footer (`recharge-footer`).
#let limited-use-lines(items, size: 8pt, single-column: false) = {
  let (short, long) = recharge-buckets(items)
  if short.len() > 0 and long.len() > 0 {
    if single-column {
      stack(
        spacing: section-gap,
        _limited-use-column(short, "Short Rest", size),
        _limited-use-column(long, "Long Rest", size),
      )
    } else {
      grid(
        columns: (1fr, 1fr),
        column-gutter: 28pt,
        align: top,
        _limited-use-column(short, "Short Rest", size),
        _limited-use-column(long, "Long Rest", size),
      )
    }
  } else if short.len() > 0 {
    _limited-use-column(short, "Short Rest", size)
  } else {
    _limited-use-column(long, "Long Rest", size)
  }
}

// The Defenses & Senses footnote, rendered beneath the saves on both layouts.
// Three kinds of entry share the block's wrapping rhythm (one `stacked-lines` call, so the gap between entries is uniform across all kinds):
// - Conditional save advantages — an `adv-badge()` hexagon followed by the authored prose stating exactly when the advantage applies (the prose carries any "on Constitution saves..." wording itself; no ability parsing).
// - Damage responses — one plain-text line per kind (Resistance / Immunity / Vulnerability), the label followed by its damage types joined by ", ".
// - Senses (Darkvision, Blindsight, ...) — the sense name followed by its range ("60 ft") in plain body text.
// Order: save advantages first, then resistances (both are defenses — they sit closest to the saves they annotate), then senses. Only the badged advantages carry a marker glyph; resistances and senses are separate from proficiency and tracking, so none of the circle/diamond/hexagon vocabulary applies to them.
// Callers guard on a non-empty combined list; this renders nothing when all `()`.
#let _resist-labels = (resistance: "Resistance", immunity: "Immunity", vulnerability: "Vulnerability")
#let character-notes(senses: (), advs: (), resistances: (), size: 6.5pt) = stacked-lines(
  advs.map(a => text(font: body-font, size: size)[#adv-badge(size: size * 0.85) #a.note])
    + ("resistance", "immunity", "vulnerability").map(k => {
        let types = resistances.filter(r => r.kind == k).map(r => r.type)
        if types.len() > 0 {
          text(font: body-font, size: size)[#_resist-labels.at(k): #types.join(", ")]
        }
      }).filter(x => x != none)
    + senses.map(s => text(font: body-font, size: size)[#s.name#if s.range != none [ #s.range]]),
)

// Whether a resolved character has anything for the Defenses & Senses block — the guard both layouts share (the block renders only when non-empty).
#let has-defenses(c) = c.senses.len() > 0 or c.save-advantages.len() > 0 or c.resistances.len() > 0

// `character-notes` fed from a resolved character — the argument spread both layouts would otherwise repeat.
#let character-notes-for(c, size: 6.5pt) = character-notes(
  senses: c.senses, advs: c.save-advantages, resistances: c.resistances, size: size,
)

// A grouped feature list: each source group (see `trait-groups`) under its tiny eyebrow sub-header — the same two-tier vocabulary as the Resources tracker's recharge headers. `head` (a section heading) binds into the first group's eyebrow so the pair stays together at a break; a `label: none` group renders its lines bare. Groups are separated by `group-gap`; within a group the usual row rhythm applies (via `feature-lines`).
#let grouped-feature-lines(groups, size: 8pt, keep-items: false, head: none) = {
  for (i, g) in groups.enumerate() {
    if i > 0 { v(group-gap) }
    let gh = if g.label != none { eyebrow(g.label, size: size * 0.72, tracking: 0.6pt) }
    let bound = if i == 0 and head != none {
      if gh == none { head } else { stack(spacing: head-gap, head, gh) }
    } else { gh }
    if keep-items {
      // Card deck: the group header rides the first item's keep-together block (feature-lines' `head`), so it bumps to the next card with that item.
      feature-lines(g.items, size: size, keep-items: true, head: bound)
    } else if bound != none {
      // Page flow (letter): a sticky header carries to the next page with the top of its group instead of orphaning at a page foot.
      sticky-head(bound, feature-lines(g.items, size: size))
    } else {
      feature-lines(g.items, size: size)
    }
  }
}

// The grouped counterpart of `feature-box` below: one section head over source-grouped items (the card deck's Features & Traits section).
#let grouped-feature-box(title, groups, size: 8pt, keep-items: false) = if groups.len() > 0 {
  block(breakable: true, spacing: 0pt,
    grouped-feature-lines(groups, size: size, keep-items: keep-items, head: section-head(title)),
  )
}

// A box of named features with optional `desc` text — for traits / class features / feats. `items` are feature records.
#let feature-box(title, items, size: 8pt, keep-items: false) = if items.len() > 0 {
  // Heading + items are stacked (separate from loose markup with a #v()): a stack honours only its own spacing, so head-gap is the actual gap. Loose markup lets Typst's default paragraph spacing sneak in and swamp head-gap. With `keep-items` the items sit outside that stack (they must be flow-level for keep-together), so the heading is bundled into the first item's keep-together block (via `feature-lines`' `head`), which keeps the heading with at least its first item across a card break — it stays off a card foot.
  if not keep-items {
    block(breakable: true, spacing: 0pt, sticky-head(
      section-head(title),
      feature-lines(items, size: size),
    ))
  } else {
    block(breakable: true, spacing: 0pt,
      feature-lines(items, size: size, keep-items: true, head: section-head(title)),
    )
  }
}
