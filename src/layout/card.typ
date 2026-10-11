// Index-card layout: a themed deck of dense 6in x 4in landscape cards.
// - Cards use native Typst grids and boxes. There is no background art.
// - Each card is its own page. A card is emitted only when it has content.
// - Card 0 Placard: a foldable table-tent on its own portrait 4x6 page, with no running masthead. Name/player and at-a-glance stats sit in the lower half.
// - Card 1 Core: identity, abilities, stats, skills, proficiencies.
// - Card 2 Actions: attacks, Mastery, Cunning Strike, Action / Bonus Action / Reaction / Other, then the Short Rest / Long Rest resource tables (on 5x8 those sit at the foot of the core card instead).
// - Card 3 Spells: spellcasting header, slots, spells by level; then the Item Spells card (stored casts, scrolls, charged items).
// - Card 4 Features & Traits: one source-grouped section. Species, classes, invocations, Feats and magic items are eyebrow subsections.
// - Card 5 Gear: currency, EQUIPPED (live gear: every non-carried, non-stowed modelled item) and INVENTORY (carried inert cargo, stowed live gear, and declared kit). Magic items are starred in both lists.
// - Takes a declared character. Resolves it internally.

#import "../resolve.typ": resolve, modifier
#import "../data/abilities.typ": ability-ids, ability-names
#import "../data/skills.typ": skill-list
#import "../data/constants.typ": weapon-mastery-descriptions
#import "layouts.typ": layouts, card-border, active-layout
#import "common.typ": *

// ---- Card masthead: ONE 4-area header, used by every card ------------------
// - Areas: TITLE (character name, big, left), SUBTITLE (small italic, below the title), NOTE1 (small, top-right), NOTE2 (small, below NOTE1).
// - Each card fills the areas it has. The rest stay blank. The section cards carry TITLE + NOTE1 (the section name) only.
// - All cards draw this header in the same place, so the masthead is positionally identical across the deck.
// - The running page header draws it, so it repeats on any page a card spills onto. NOTE2 becomes "(continued)" there.

// Gap below the header to the body. Used as `header-ascent` in `set page`.
#let _header-gap = 4 * u

#let _card-header(title, subtitle, note1, note2) = {
  grid(
    columns: (1fr, auto),
    column-gutter: grid-gutter,
    align: (left + top, right + top),
    {
      text(font: body-font, size: 15 * u, weight: "bold", fill: accent)[#title]
      linebreak()
      // Reserve the subtitle line (`hide` when empty) to keep the TITLE height constant.
      text(font: body-font, size: 8 * u, style: "italic")[#if subtitle != none { subtitle } else { hide[x] }]
    },
    {
      set align(right)
      // Both note rows share one base style; a note styles its own spans over it (the PB value, "(continued)").
      set text(font: label-font, size: 6.5 * u, weight: "medium")
      if note1 != none { note1 } else { hide[x] }
      if note2 != none { linebreak(); note2 }
    },
  )
}

// - Each card drops a marker that carries its four header areas.
// - The running header reads the active card's marker (the last one on a page ≤ this page) and redraws the masthead.
// - `numbered` tells whether the card, and any page it spills onto, counts in the page-number footer (see `_page-footer`).
// - The placard, gear and backstory cards are flavor. They stay un-numbered.
#let _card-marker(title, subtitle, note1, note2, numbered: true) = [#metadata((
  title: title, subtitle: subtitle, note1: note1, note2: note2, numbered: numbered,
))<card-marker>]

// Running header: redraws the active card's masthead on every page.
// - NOTE1 keeps the section name. Past the card's start page NOTE2 becomes "(continued)".
// - Uses location and page-counter queries instead of `state`, which gives a first-page off-by-one.
#let _running-head = context {
  let markers = query(<card-marker>)
  let cur = here().page()
  let active = markers.filter(m => counter(page).at(m.location()).first() <= cur)
  if active.len() == 0 { return }
  let m = active.last()
  let start = counter(page).at(m.location()).first()
  let a = m.value
  let note2 = if cur > start { text(font: body-font, size: 8 * u, style: "italic")[(continued)] } else { a.note2 }
  // - A content-sized header top-aligns at the page edge and clips the caps.
  // - Fill the region and push it down with `v(1fr)` to get headroom above the title.
  // - The gap below the rule to the body is `header-ascent` (`_header-gap`).
  block(height: 100%, { v(1fr); _card-header(a.title, a.subtitle, a.note1, note2) })
}

// Gap between the body's bottom edge and the footer's page number, set as `footer-descent` below. Keep it tiny so the number sits snug against the margin.
// - This is a gap from the BODY, separate from the physical edge. `footer-descent` trims the footer region's near side, and the region always extends down to the page's physical bottom edge.
// - A larger descent pushes the footer closer to that edge, and into the printer's clip band (see the margin comment on `card-sheet`).
#let _footer-gap = 0.5 * u

// Page-number footer "n/m". It counts only the numbered cards, per each marker's `numbered` flag.
// - A marker's page range is its own start page through the next marker's start page minus 1, or the document's last page for the final marker.
// - The range makes a card that spills onto continuation pages number every page it occupies, beyond its first.
#let _page-footer = context {
  let markers = query(<card-marker>)
  if markers.len() == 0 { return }
  let cur = here().page()
  let final = counter(page).final().first()
  let starts = markers.map(m => counter(page).at(m.location()).first())
  let ranges = range(markers.len()).map(i => (
    numbered: markers.at(i).value.at("numbered", default: true),
    start: starts.at(i),
    end: if i + 1 < markers.len() { starts.at(i + 1) - 1 } else { final },
  ))
  let active = ranges.filter(r => r.start <= cur and cur <= r.end)
  if active.len() == 0 or not active.last().numbered { return }
  let total = ranges.filter(r => r.numbered).map(r => r.end - r.start + 1).sum(default: 0)
  let n = ranges.filter(r => r.numbered and r.end < cur).map(r => r.end - r.start + 1).sum(default: 0) + (cur - active.last().start + 1)
  // A school-synergy or short-regain note anchored to this page shares the footer's one line with the page number (see `footer-line`).
  footer-line(page-number-footer(n, total, size: 5.5 * u), 5 * u)
}

// A footer section header: the tier-1 eyebrow above the Defenses & Senses and Training blocks. It mirrors the letter's `_framed-title`.
// - Bold and tracked, so it out-ranks the plainer item labels below it.
// - The hierarchy is weight and tracking, separate from colour. Both stay accent.
#let _foot-head(title) = eyebrow(title, size: 5.5 * u, weight: "bold", tracking: 0.6 * u)

// A proficiency line: a quiet accent label plus the comma-joined value.
// - Regular weight, a touch smaller than `_foot-head`, so it reads as tier-2.
#let _prof-line(name, items) = if items.len() > 0 {
  [#eyebrow([#name: ], size: 5 * u)#text(font: body-font, size: 6.5 * u)[#titly-list(items)]]
}

// --- Card bodies -----------------------------------------------------------

// The placard's stat block: the left group (AC/HP/PPer) and the right group (Initiative/Spell ...) in ONE grid — L-label · L-value · spacer · R-label · R-value.
// - One grid keeps the two vertical rules, between the right-aligned accent small-caps labels and the ink values, column-aligned by construction.
// - The optional `span` row (Faction) hangs its value across cols 1–4 with a colspan. Its rule aligns with the left group's, because it is the same column.
// - Row spacing comes from cell inset, separate from row-gutter, so the rules stay unbroken.
// - Labels are mixed-case ("PPer", "Spell DC"), so small caps marks the capitals.
#let _pl-stats(left-rows, right-rows, span: none, size: 14 * u) = {
  let lab(l) = text(font: body-font, size: size, fill: accent)[#small-caps(l)]
  let val(v) = text(font: body-font, size: size, fill: ink)[#v]
  let n = calc.max(left-rows.len(), right-rows.len())
  let cells = ()
  for i in range(n) {
    let (ll, lv) = if i < left-rows.len() { left-rows.at(i) } else { ("", "") }
    cells += (lab(ll), val(lv), [])          // L-label · L-value · spacer
    if i < right-rows.len() {
      let (rl, rv) = right-rows.at(i)
      cells += (lab(rl), val(rv))            // R-label · R-value
    } else {
      cells += ([], [])                      // pad the shorter (non-caster) side
    }
  }
  if span != none {
    let (sl, sv) = span
    cells += (lab(sl), grid.cell(colspan: 4, val(sv)))  // Faction value spans the block
  }
  grid(
    columns: (auto, auto, 0.3in * scale, auto, auto),
    align: (right + horizon, left + horizon, center, right + horizon, left + horizon),
    inset: (x, y) => (top: 4.5 * u, bottom: 4.5 * u) + (
      if x == 0 or x == 3 { (right: 8 * u) }        // labels
      else if x == 1 or x == 4 { (left: 8 * u) }    // values (incl. the colspan value, origin x=1)
      else { (:) }                                // spacer
    ),
    // - Left rule on every row, Faction included, so it aligns.
    // - Right rule only on rows the right group fills, so it stays off the space below Initiative for a non-caster.
    stroke: (x, y) => {
      if x == 1 { (left: 0.7 * u + rule-color) }
      else if x == 4 and y < right-rows.len() { (left: 0.7 * u + rule-color) }
      else { none }
    },
    ..cells,
  )
}

// Placard body: the foldable table-tent (card #1).
// - Name (accent small-caps) and player (ink italic) sit over a rule, then the creature/class line and two stat groups.
#let _placard-card(c) = {
  // A break at a separator reads better than a wrap inside a part, so pack the identity parts into lines greedily against the region width.
  // - The divider stays at the end of a broken line, marking the line as continued.
  let placard-line = layout(region => {
    let styled = s => text(font: body-font, size: 16 * u, fill: ink)[#s]
    let lines = ()
    let cur = none
    for p in identity-parts(c) {
      if cur == none { cur = p }
      else if measure(styled(cur + meta-sep + p)).width <= region.width { cur += meta-sep + p }
      else { lines.push(cur + meta-sep.trim(at: end)); cur = p }
    }
    if cur != none { lines.push(cur) }
    styled(lines.map(l => [#l]).join(linebreak()))
  })

  let left-rows = (
    ("AC", [#str(c.ac)#_ac-note-mark(c)]),
    ("HP", if c.temp-hp > 0 { str(c.max-hp) + [$+$] + str(c.temp-hp) } else { str(c.max-hp) }),
    ("PPer", str(c.passives.perception)),
  )
  let faction-span = if c.faction != none { ("Faction", c.faction) } else { none }
  let right-rows = (("Initiative", fmt-mod(c.initiative)),)
  if c.spellcasting.len() > 0 {
    let s = c.spellcasting.first()
    right-rows.push(("Spell Attack", fmt-mod(s.attack)))
    right-rows.push(("Spell DC", $#s.save-dc$))
  }

  // - Zero the default block and paragraph spacing, so the only gaps are the explicit `v()`s below.
  // - Typst spacing otherwise stacks on top and balloons the space around the class line.
  // - The page's top margin is the fold line, so this body is already in the card's lower half. The `v(fr)`s centre it with a slight downward bias.
  set block(spacing: 0 * u)
  set par(spacing: 0 * u)

  v(1fr)
  grid(
    columns: (1fr, auto),
    column-gutter: 10 * u,
    align: (left + bottom, right + bottom),
    text(font: body-font, size: 17 * u, weight: "bold", fill: accent)[#small-caps(c.name)],
    if c.player != none { text(font: body-font, size: 15 * u, style: "italic", fill: ink)[#c.player] } else { [] },
  )
  v(14 * u)
  line(length: 100%, stroke: 0.7 * u + rule-color)
  v(14 * u)
  placard-line
  v(14 * u)
  align(center, _pl-stats(left-rows, right-rows, span: faction-span))
  v(0.7fr)
  // The placard page is a fold-out cover with `footer: none` — no footer
  // region for `ac-note-footer` to render into. The AC note therefore sits at
  // the card's bottom edge, left-justified where a page footer would be, in
  // place of the page footer the other AC sites use.
  if c.at("ac-source", default: none) != none {
    align(left, text(font: body-font, size: 6.5 * u, fill: ink)[#super[†] #emph(c.ac-source)])
  }
}

// Limited-use resource pools; spell slots (one row per level) join the Long Rest column, before the other pools.
#let _all-resources(c) = if c.spellcasting.len() > 0 {
  slot-resource-items(merge-slots(c.spellcasting)) + c.limited-uses
} else { c.limited-uses }

// The 5x8 core card has room below the footer for the resource tables; every other layout keeps them on the Actions card.
#let _resources-on-core = active-layout == "5x8"

#let _core-card(c, is-portrait: false) = {
  if is-portrait {
    grid(
      columns: 3 * (1fr,),
      gutter: 3 * u,
      ..ability-ids.map(id => ability-cell(
        id, c.abilities.at(id), c.ability-mods.at(id), c.saves.at(id),
      )),
    )
    v(4 * u)

    let hp-cell = {
      set text(weight: "bold")
      text(size: card-stat-size)[#bold-num(c.max-hp)]
    }
    grid(
      columns: 3 * (1fr,),
      rows: (28 * u, 28 * u),
      gutter: 3 * u,
      stat-cell([#str(c.ac)#_ac-note-mark(c)], "Armor Class", big: true, width: 100%),
      stat-cell(hp-cell, "Hit Points", big: true, width: 100%),
      stat-cell(fmt-mod(c.initiative), "Initiative", width: 100%),
      stat-cell([#bold-num(c.speed)#text(size: 8 * u)[ ft#if c.at("fly-speed", default: none) != none [, Fly #bold-num(c.at("fly-speed")) ft]]], "Speed", width: 100%),
      stat-cell(c.passives.perception, "Passive Perception", width: 100%),
      stat-cell(checkbox(size: 9 * u), "Heroic Inspiration", width: 100%),
    )
    v(5 * u)

    let num-cols = 2
    let rows-per-col = calc.ceil(skill-list.len() / num-cols)
    let cols = range(num-cols).map(ci => skill-list.slice(
      ci * rows-per-col, calc.min((ci + 1) * rows-per-col, skill-list.len()),
    ))
    grid(
      columns: num-cols * (1fr,),
      column-gutter: 36 * u,
      ..cols.map(col => stack(
        spacing: 2 * u,
        ..col.map(sk => skill-row(sk, c.skills.at(sk.id))),
      )),
    )
    v(5 * u)

    let foot-items = ()
    if has-defenses(c) {
      foot-items.push(stack(
        spacing: 3 * u,
        _foot-head[DEFENSES & SENSES],
        character-notes-for(c, size: 6.5 * u),
      ))
    }
    foot-items.push(stack(
      spacing: 3 * u,
      _foot-head[TRAINING & PROFICIENCIES],
      stacked-lines((
        _prof-line("Armor", c.proficiencies.armor),
        _prof-line("Weapons", c.proficiencies.weapon),
        _prof-line("Tools", c.proficiencies.tool.map(tool-label)),
        _prof-line("Languages", c.proficiencies.language.sorted()),
      ).filter(x => x != none)),
    ))
    grid(
      columns: foot-items.len() * (1fr,),
      column-gutter: grid-gutter,
      ..foot-items,
    )
    if _resources-on-core and _all-resources(c).len() > 0 {
      v(section-gap)
      resource-tables(_all-resources(c), size: 7.5 * u)
    }
  } else {
    grid(
      columns: 6 * (1fr,),
      gutter: 3 * u,
      ..ability-ids.map(id => ability-cell(
        id, c.abilities.at(id), c.ability-mods.at(id), c.saves.at(id),
      )),
    )
    v(3 * u)

    // HP shows the computed maximum only: blanks for current and temp HP are not useful at the card's at-a-glance size.
    let hp-cell = {
      set text(weight: "bold")
      text(size: card-stat-size)[#bold-num(c.max-hp)]
    }
    grid(
      // - Six equal boxes, each filling its column, line up under the six ability columns above.
      // - An explicit row height is required: `stat-cell` uses `height: 100%` to fill the row, and `100%` in an auto-sized grid row resolves to the whole page.
      columns: 6 * (1fr,),
      rows: 32 * u,
      gutter: 3 * u,
      stat-cell([#str(c.ac)#_ac-note-mark(c)], "AC", big: true, width: 100%),
      stat-cell(hp-cell, "HP", big: true, width: 100%),
      stat-cell(fmt-mod(c.initiative), "Init", width: 100%),
      stat-cell([#bold-num(c.speed)#text(size: 8 * u)[ ft#if c.at("fly-speed", default: none) != none [, Fly #bold-num(c.at("fly-speed")) ft]]], "Speed", width: 100%),
      stat-cell(c.passives.perception, "Pas. Per", width: 100%),
      // The diamond marks resource tracking. Check it off in play.
      stat-cell(checkbox(size: 10 * u), "Heroic Insp.", width: 100%),
    )
    v(4 * u)

    let rows-per-col = calc.ceil(skill-list.len() / 3)
    let cols = range(3).map(ci => skill-list.slice(
      ci * rows-per-col, calc.min((ci + 1) * rows-per-col, skill-list.len()),
    ))
    grid(
      columns: 3 * (1fr,),
      column-gutter: grid-gutter,
      ..cols.map(col => stack(
        spacing: 1.5 * u,
        ..col.map(sk => skill-row(sk, c.skills.at(sk.id))),
      )),
    )
    v(4 * u)

    // - The footer splits in two: Defenses & Senses on the left, proficiency training on the right.
    // - The left box lists save advantages, then damage responses, then senses. Its header shows only when there is at least one of them.
    grid(
      columns: (1fr, 1fr),
      column-gutter: grid-gutter,
      if has-defenses(c) {
        stack(
          spacing: 3 * u,
          _foot-head[DEFENSES & SENSES],
          character-notes-for(c, size: 6.5 * u),
        )
      } else { [] },
      stack(
        spacing: 3 * u,
        _foot-head[TRAINING & PROFICIENCIES],
        stacked-lines((
          _prof-line("Armor", c.proficiencies.armor),
          _prof-line("Weapons", c.proficiencies.weapon),
          _prof-line("Tools", c.proficiencies.tool.map(tool-label)),
          _prof-line("Languages", c.proficiencies.language.sorted()),
        ).filter(x => x != none)),
      ),
    )
  }
}


#let _spells-card(c) = {
  spellcasting-head(c.spellcasting)
  v(section-gap)
  spell-table(
    c.spellcasting, size: 7.5 * u, keep-groups: true,
    atomic-rows: true, school-notes: spell-school-notes(c.traits),
  )
}

// Bucket the resolved character into the card deck's sections.
// - `activation` ("Action" / "Bonus Action" / "Reaction" / none) moves an activated ability out of the passive lists into an action-economy table, whatever its `kind`.
// - A `magic-item` follows the same trait-kind path: activated goes to an action table, passive to the Traits list.
// - Actionable spells route into the same tables, keyed off casting time. Every spell declares one — `_spell` asserts it.
// - Only cantrips (level-0 spells) join the action-economy tables. A leveled spell lives on the Spells card alone, keeping the action tables tight.
// - A cantrip Action spell that makes an attack roll, or does damage and forces a save, joins the ATTACK table with the weapons.
// - Every Bonus Action / Reaction spell joins its table as a name+notes pseudo-item, the shape `activation-table` renders.
// - A utility Action spell (no attack, no damage+save) shows on the Spells card only.
// - Spells sort by level, then name.
#let _partition-features(c) = {
  // - Features & Traits lists every trait/feat that has descriptive prose, whatever its activation. The letter sheet follows the same rule.
  // - An activated one also gets a terse note in its action table. The duplication is deliberate: full reference vs. quick in-play lookup.
  let traits = c.traits.filter(t =>
    is-trait-kind(t) and t.at("desc", default: none) != none)
  let feats = c.traits.filter(t => is-feat-kind(t))

  let activated = c.traits.filter(t => (is-trait-kind(t) or is-feat-kind(t)) and activation-of(t) != none)
  let actions = activated.filter(t => activation-of(t) == "Action")
  let bonus-actions = activated.filter(t => activation-of(t) == "Bonus Action")
  let reactions = activated.filter(t => activation-of(t) == "Reaction")

  // - OTHER table: a combat-related feature that skips an activated action. A feature with terse `notes` but no `activation` routes here (Sneak Attack, Surprise Attack, Long-Limbed, Wails from the Grave).
  // - Features & Traits shows the same feature with its full `desc`. The duplication is deliberate: quick combat lookup vs. reference.
  let other = c.traits.filter(t =>
    (is-trait-kind(t) or is-feat-kind(t)) and activation-of(t) == none
    and t.at("notes", default: none) != none
    and t.at("via-name", default: none) != "Metamagic")

  // - MASTERY table: one row per distinct trained mastery property among the resolved attack lines. An attack carries `mastery` only when the weapon is mastered (see resolve.typ).
  // - The rider's effect prose comes from `weapon-mastery-descriptions`.
  // - Topple's prose is a function of its save DC (= $8 +$ PB $+$ the weapon's ability mod, magic bonus excluded), computed from the first mastered weapon of that property.
  // - Mastery requires proficiency, so PB and the weapon's `ability` suffice.
  // - The table is empty without Weapon Mastery.
  let mastery-names = ()
  for a in c.attacks {
    let m = a.at("mastery", default: none)
    if m != none and not mastery-names.contains(m) { mastery-names.push(m) }
  }
  let masteries = mastery-names.map(m => {
    let desc = weapon-mastery-descriptions.at(m)
    let notes = desc
    if type(desc) == function {
      let a = c.attacks.find(a => a.at("mastery", default: none) == m)
      let dc = 8 + c.proficiency-bonus + c.ability-mods.at(a.ability)
      notes = desc(dc)
    }
    (name: m, notes: notes)
  })

  // - A weapon-attack cantrip (True Strike, Booming Blade) is already expanded into per-weapon lines in c.attacks, each labelled "<weapon> (<Spell>)" by attack-table off its `via-spell`.
  // - It carries `attack: false` and no damage here, so it skips the ATTACK-table filter. No guard against a duplicate is necessary.
  let spells-all = all-spells(c.spellcasting)
  let spell-key = s => str(s.level) + s.name
  let spell-attacks = spells-all.filter(s =>
    s.level == 0
    and s.casting-time == "Action"
    and (s.at("attack", default: false)
      or (s.at("damage", default: none) != none and s.save != none))).sorted(key: spell-key)
  let as-item = s => (name: spell-name-cell(s), notes: spell-action-note(s, include-damage: true))
  let spell-bonus-items = spells-all.filter(s => s.level == 0 and s.casting-time == "Bonus Action").sorted(key: spell-key).map(as-item)
  let spell-reaction-items = spells-all.filter(s => s.level == 0 and s.casting-time == "Reaction").sorted(key: spell-key).map(as-item)

  (
    // - Passive traits and feats, partitioned into source groups: species, each class, invocations, Feats, magic items (`trait-groups`, common.typ).
    // - On the card the feats are one more subsection, separate from their own section head.
    trait-groups: trait-groups(traits + feats),
    actions: actions,
    bonus-actions: bonus-actions,
    reactions: reactions,
    spell-attacks: spell-attacks,
    spell-bonus-items: spell-bonus-items,
    spell-reaction-items: spell-reaction-items,
    masteries: masteries,
    other: other,
    // - Flags which optional cards have content.
    // - The Actions card holds the action-economy tables plus (off the 5x8 core card) the limited-use resource tables, so it also emits for a resources-only character.
    // - The Features & Traits card holds the grouped passive list.
    // - The Gear card holds the EQUIPPED and INVENTORY lists.
    has-actions: (c.attacks, actions, bonus-actions, reactions,
      c.cunning-strikes, c.metamagic, spell-attacks, spell-bonus-items,
      spell-reaction-items, masteries, other).any(l => l.len() > 0)
      or (not _resources-on-core and _all-resources(c).len() > 0),
    has-features: (traits, feats).any(l => l.len() > 0),
    has-gear: c.equipped.len() > 0 or c.equipment.len() > 0 or c.currency != none,
  )
}

// Sections are (rendered, content) pairs. Only the rendered ones join.
// - A `v(section-gap)` goes strictly between two sections that render, so no stray gap appears above or below.
// - Each section stays a direct flow child of the returned content, separate from a stack: feature-box's internal keep-together must measure it.
#let _card-sections(sections) = {
  let rendered = sections.filter(s => s.at(0)).map(s => s.at(1))
  for (i, body) in rendered.enumerate() {
    if i > 0 { v(section-gap) }
    body
  }
}

// `b` is `_partition-features`' bucket dict.
#let _actions-card(c, b) = {
  // - Actionable spells join the weapon ATTACK table and the Bonus Action and Reaction tables.
  // - Each table lists the features first, then the spells.
  let bonus-all = b.bonus-actions + b.spell-bonus-items
  let reaction-all = b.reactions + b.spell-reaction-items
  let resources = if _resources-on-core { () } else { _all-resources(c) }
  // - Every action-economy table is one atomic unit: a table that fits a whole card
  //   bumps intact to a continuation card rather than stranding its header and a row
  //   at a card foot, and one taller than a card still splits, between its rows
  //   (`atomic-rows`) rather than mid-cell. Spell tables are exempt on purpose —
  //   they get long, and their level-groups split cleanly (`spell-table`'s own
  //   keep-groups + atomic-rows).
  let keep = body => keep-together(body)
  _card-sections((
    (c.attacks.len() > 0 or b.spell-attacks.len() > 0, keep(attack-table(c.attacks, attacks-per-action: c.attacks-per-action, spells: b.spell-attacks, size: 7.5 * u, atomic-rows: true))),
    (b.masteries.len() > 0, keep(activation-table("Mastery", b.masteries, size: 7.5 * u, atomic-rows: true))),
    (c.cunning-strikes.len() > 0, keep(cunning-strike-table(c.cunning-strikes, size: 7.5 * u, atomic-rows: true))),
    (b.actions.len() > 0, keep(activation-table("Action", b.actions, size: 7.5 * u, atomic-rows: true))),
    (bonus-all.len() > 0, keep(activation-table("Bonus Action", bonus-all, size: 7.5 * u, atomic-rows: true))),
    (reaction-all.len() > 0, keep(activation-table("Reaction", reaction-all, size: 7.5 * u, atomic-rows: true))),
    (b.other.len() > 0, keep(activation-table("Other", b.other, size: 7.5 * u, atomic-rows: true))),
    (c.metamagic.len() > 0, keep(metamagic-table(c.metamagic, size: 7.5 * u, atomic-rows: true))),
    // - Limited-use resource pools form the tail: two side-by-side tables of diamonds, Short Rest and Long Rest.
    // - The pair travels together, so neither bucket orphans at a card break.
    // - A character with resources but no actions still emits this card, titled "Actions": `has-actions` above counts the resources.
    (resources.len() > 0, resource-tables(resources, size: 7.5 * u)),
  ))
}

// Item spells: one table per item. Single-use items (stored casts, Spell Scrolls) come first and travel as one unit; charged items (staffs) follow.
#let _item-spells(c) = c.at("item-spells", default: ()).filter(item => item.spells.len() > 0)

#let _item-spells-card(c) = {
  let items = _item-spells(c)
  let keep = body => keep-together(body)
  let table = item => item-spell-table(item.name, item.spells, size: 7.5 * u, atomic-rows: true, stored: item.stored, consumable: item.consumable)
  let single = items.filter(item => item.stored or item.consumable)
  let charged = items.filter(item => not (item.stored or item.consumable))
  _card-sections((
    (single.len() > 0, keep(single.map(table).join(v(section-gap)))),
    ..charged.map(item => (true, keep(table(item)))),
  ))
}

// Backstory: the character's authored roleplay prose on its own card.
// - It reads at a larger size than the mechanical cards' 8pt, with justified paragraphs.
// - The content is markup (`[…]`), so lists, emphasis and inline math carry through.
// - Emitted only when a backstory is declared.
#let _backstory-card(c) = {
  set par(justify: true, leading: 0.6em, spacing: 1em)
  set text(size: 9.5 * u)
  c.backstory
}

#let _gear-card(c) = {
  if c.currency != none {
    block(spacing: 0 * u)[#eyebrow([Currency: ], size: 6 * u)#text(font: body-font, size: 8 * u)[#c.currency]]
    v(section-gap)
  }
  // - Two lists with different meanings. Keep them separate.
  // - EQUIPPED (`c.equipped`) is the gear whose effects are live on this sheet: every non-`carried`, non-`stowed` weapon/armor/shield/magic-item feature.
  // - INVENTORY (`c.equipment`) is stowed gear (live, `stowed(...)`) or inert cargo (`carried(...)` gear plus the declared strings).
  // - Magic gear is starred in both lists.
  // - Each heading stays sticky to its list, so neither orphans at a card foot.
  if c.equipped.len() > 0 {
    sticky-head(
      section-head("Equipped"),
      bullet-lines(c.equipped, size: 7.5 * u, columns: 2),
    )
  }
  if c.equipment.len() > 0 {
    if c.equipped.len() > 0 { v(section-gap) }
    sticky-head(
      section-head("Inventory"),
      bullet-lines(c.equipment, size: 7.5 * u, columns: 2),
    )
  }
}

#let _monster-card(m) = {
  // Speed presentation. The stat cell carries the PRIMARY speed: the walk
  // speed when the monster has one, else its main special speed with the mode
  // named ("60 ft Swim" for a dolphin). The Speeds meta line lists every
  // speed — the walk value first, then each special speed with its mode
  // capitalized and qualifiers restated: "40 ft; Fly 30 ft, hover
  // (Flyer only); Swim 30 ft".
  let cap = s => upper(s.first()) + s.slice(1)
  let parsed = m.speed.split(", ").map(seg => {
    // A segment is "<mode words> <value>" with an optional "(...)" note.
    let body = seg
    let note = none
    if "(" in body {
      let halves = body.split("(")
      body = halves.first().trim()
      note = halves.last().trim(")").trim()
    }
    let words = body.split(" ")
    // The value is the "N ft" tail; the mode is the words before it, if any.
    let value = words.at(-2) + " " + words.last()
    let mode = if words.len() > 2 { words.slice(0, words.len() - 2).join(" ") } else { none }
    // "hover" reads plain; other qualifiers keep their parentheses
    // ("Fly 30 ft, hover (Flyer only)", "Fly 30 ft (Flyer only)").
    let note-out = if note == none { "" } else {
      let qual = note.split(";").map(q => q.trim())
      let hover = qual.find(q => lower(q) == "hover")
      let rest = qual.filter(q => lower(q) != "hover")
      if hover != none and rest.len() == 0 { "hover" }
      else if hover != none { "hover (" + rest.join("; ") + ")" }
      else if rest.len() > 0 { "(" + rest.join("; ") + ")" }
      else { "" }
    }
    (mode: mode, value: value, note: note-out)
  })
  let walk = parsed.find(p => p.mode == none)
  let specials = parsed.filter(p => p.mode != none and p.value != "0 ft")
  // Primary: walk when present and non-zero, else the first special speed.
  let speed-main = if walk != none and walk.value != "0 ft" { walk.value }
    else if specials.len() > 0 { specials.first().value + " " + cap(specials.first().mode) }
    else if walk != none { walk.value }
    else { m.speed }
  // All speeds, walk first; shown whenever the monster has more than one.
  let speed-rest = if parsed.len() > 1 {
    let items = ()
    if walk != none and walk.value != "0 ft" { items.push(walk.value) }
    for p in specials {
      items.push(cap(p.mode) + " " + p.value + if p.note != "" { ", " + p.note } else { "" })
    }
    items.join("; ")
  } else { none }
  grid(
    columns: 4 * (1fr,),
    rows: 25 * u,
    gutter: 2.5 * u,
    stat-cell(str(m.ac), "AC", width: 100%),
    stat-cell(
      if m.hit-dice != none { [#bold-num(m.hp)#text(size: 6.5 * u, weight: "regular")[ (#m.hit-dice)]] } else { [#bold-num(m.hp)] },
      "HP", width: 100%
    ),
    stat-cell(fmt-mod(m.initiative), "Init", width: 100%),
    stat-cell(text(size: 7.5 * u, weight: "bold")[#speed-main], "Speed", width: 100%),
  )
  v(2.5 * u)

  grid(
    columns: 6 * (1fr,),
    gutter: 2.5 * u,
    ..ability-ids.map(id => {
      let score = m.abilities.at(id, default: 10)
      let mod = m.ability-mods.at(id, default: 0)
      let save = m.saves.at(id)
      box(
        width: 100%,
        stroke: 0.5 * u + rule-color,
        radius: 2 * u,
        inset: (x: 2 * u, y: 3.5 * u),
        align(center + horizon, stack(
          spacing: 1.5 * u,
          text(font: label-font, size: 5 * u, weight: "bold", fill: accent)[#upper(id)],
          text(font: body-font, fill: ink)[#text(size: 7.5 * u)[#bold-num(score)] #text(size: 6 * u, weight: "regular")[(#fmt-mod(mod))]],
          [
            #text(font: label-font, size: 4.5 * u, weight: "regular", fill: accent, tracking: 0.4 * u)[SAVE ]
            #text(font: body-font, size: 6 * u, weight: if save.proficient { "bold" } else { "regular" }, fill: ink)[#fmt-mod(save.bonus)]
          ],
        ))
      )
    })
  )
  v(2 * u)

  let sec-lines = ()
  if speed-rest != none {
    sec-lines.push([#eyebrow([Speeds: ], size: 5 * u)#text(font: body-font, size: 7 * u)[#speed-rest]])
  }
  if m.skills != none and m.skills.len() > 0 {
    let skill-strs = if type(m.skills) == dictionary {
      m.skills.pairs().map(((k, v)) => titly(k) + " " + fmt-mod(v))
    } else {
      m.skills.map(s => if type(s) == str { s } else { str(s) })
    }
    sec-lines.push([#eyebrow([Skills: ], size: 5 * u)#text(font: body-font, size: 7 * u)[#skill-strs.join(", ")]])
  }
  if m.vulnerabilities != none and m.vulnerabilities.len() > 0 {
    sec-lines.push([#eyebrow([Damage Vulnerabilities: ], size: 5 * u)#text(font: body-font, size: 7 * u)[#m.vulnerabilities.join(", ")]])
  }
  if m.resistances != none and m.resistances.len() > 0 {
    sec-lines.push([#eyebrow([Damage Resistances: ], size: 5 * u)#text(font: body-font, size: 7 * u)[#m.resistances.join(", ")]])
  }
  if m.immunities != none and m.immunities.len() > 0 {
    sec-lines.push([#eyebrow([Damage Immunities: ], size: 5 * u)#text(font: body-font, size: 7 * u)[#m.immunities.join(", ")]])
  }
  if m.condition-immunities != none and m.condition-immunities.len() > 0 {
    sec-lines.push([#eyebrow([Condition Immunities: ], size: 5 * u)#text(font: body-font, size: 7 * u)[#m.condition-immunities.join(", ")]])
  }
  if m.senses != none and (type(m.senses) == str or m.senses.len() > 0) {
    let sense-str = if type(m.senses) == str { m.senses } else { m.senses.join(", ") }
    sec-lines.push([#eyebrow([Senses: ], size: 5 * u)#text(font: body-font, size: 7 * u)[#sense-str]])
  }
  if m.languages != none and m.languages != "" {
    sec-lines.push([#eyebrow([Languages: ], size: 5 * u)#text(font: body-font, size: 7 * u)[#m.languages]])
  }
  if sec-lines.len() > 0 {
    stacked-lines(sec-lines)
    v(2 * u)
  }

  line(length: 100%, stroke: 0.4 * u + rule-color)

  if m.traits.len() > 0 {
    v(5 * u)
    sticky-head(
      section-head("Traits"),
      stacked-lines(m.traits.map(t => [
        #text(font: body-font, size: 7.5 * u)[#text(weight: "bold")[#t.name.] #t.desc]
      ])),
    )
  }

  if m.actions.len() > 0 {
    v(if m.traits.len() > 0 { 6 * u } else { 5 * u })
    sticky-head(
      section-head("Actions"),
      stacked-lines(m.actions.map(a => [
        #text(font: body-font, size: 7.5 * u)[#text(weight: "bold")[#a.name.] #a.desc]
      ])),
    )
  }

  if m.bonus-actions.len() > 0 {
    v(6 * u)
    sticky-head(
      section-head("Bonus Actions"),
      stacked-lines(m.bonus-actions.map(ba => [
        #text(font: body-font, size: 7.5 * u)[#text(weight: "bold")[#ba.name.] #ba.desc]
      ])),
    )
  }

  if m.reactions.len() > 0 {
    v(6 * u)
    sticky-head(
      section-head("Reactions"),
      stacked-lines(m.reactions.map(r => [
        #text(font: body-font, size: 7.5 * u)[#text(weight: "bold")[#r.name.] #r.desc]
      ])),
    )
  }
  if m.desc != none {
    v(5 * u)
    text(font: body-font, size: 6.5 * u)[#m.desc]
  }
}

// A monster's identity line: size, type, alignment — the single-card masthead
// subtitle, shared with the packed-card column header.
#let _monster-sub(m) = m.size + " " + m.creature-type + if m.alignment != none { ", " + m.alignment } else { "" }

// A monster's CR/PB masthead note. A summon without a CR (`cr: none`) carries
// neither: both numbers derive from the CR, and a spell summon has none.
#let _monster-cr-note(m) = if m.cr != none { [CR #m.cr] } else { none }
#let _monster-pb-note(m) = if m.cr != none { [PB #fmt-mod(m.pb)] } else { none }

// A monster column: the stat block under its own compact header (name, type
// line, CR/PB) for cards that pack two stat blocks side by side.
#let _monster-column(m) = {
  block(breakable: false, {
    grid(
      columns: (1fr, auto),
      column-gutter: grid-gutter,
      align: (left + bottom, right + bottom),
      {
        text(font: body-font, size: 10 * u, weight: "bold", fill: accent)[#m.name]
        linebreak()
        text(font: body-font, size: 6.5 * u, style: "italic")[#_monster-sub(m)]
      },
      if m.cr != none {
        text(font: label-font, size: 5.5 * u, weight: "medium")[CR #m.cr, PB #fmt-mod(m.pb)]
      },
    )
  })
  v(4 * u)
  line(length: 100%, stroke: 0.4 * u + rule-color)
  v(4 * u)
  _monster-card(m)
}

// Two stat blocks on one card, side by side, with a rule between them.
// - The first column carries the separator as its right stroke, inset so its
//   text keeps off the rule; the fit measurement charges both columns that
//   width (see the deck's monster section).
#let _monster-pair(a, b) = grid(
  columns: (1fr, 1fr),
  column-gutter: grid-gutter,
  align: top,
  box(width: 100%, stroke: (right: 0.4 * u + rule-color), inset: (right: 8 * u), _monster-column(a)),
  _monster-column(b),
)

// --- Deck assembly ---------------------------------------------------------

#let card-sheet(char) = {
  let c = resolve(char)
  let L = layouts.at(active-layout)
  let is-portrait = L.width < L.height
  let landscape-w = calc.max(L.width, L.height)
  let landscape-h = calc.min(L.width, L.height)
  let portrait-w = calc.min(L.width, L.height)
  let portrait-h = calc.max(L.width, L.height)

  // - Each edge margin is the registry's scale-1 margin plus the design border's
  //   growth: `L.margin.at(e) + card-border.at(e) * (L.scale - 1)`. The printer
  //   clip is fixed (a physical property of the printer); the border grows with
  set page(
    width: L.width, height: L.height,
    margin: (
      left: L.margin.at("left") + card-border.at("left") * (L.scale - 1),
      right: L.margin.at("right") + card-border.at("right") * (L.scale - 1),
      top: L.margin.at("top") + card-border.at("top") * (L.scale - 1),
      bottom: L.margin.at("bottom") + card-border.at("bottom") * (L.scale - 1),
    ),
    fill: white,
    header-ascent: _header-gap,
    header: _running-head,
    footer-descent: _footer-gap,
    footer: _page-footer,
  )
  set text(font: body-font, size: 8 * u, fill: ink)
  // Explicit math (`$…$` in prose, `fmt-*` on structured cells) renders in the Euler math font (LaTeX look); this rule just supplies that font.
  show math.equation: math-styled

  // Bucket the traits and actionable spells into the deck's sections (see `_partition-features` for the routing rules).
  let b = _partition-features(c)

  // The core card fills all four masthead areas; the section cards fill TITLE + NOTE1 (the section) and leave the rest blank.
  // The background sits with the creature facts in NOTE1, so the subtitle carries species and classes only — the same identity line the placard packs, on one line here.
  let core-subtitle = identity-line(c)
  let cl = meta-line(c)
  let core-note1 = if cl != "" { cl } else { none }
  // NOTE2 pairs the alignment with the proficiency bonus on the masthead's lower meta row.
  let pb = [#text(font: label-font, size: 5.5 * u)[PB ]#text(font: body-font, size: 8 * u, weight: "bold")[#fmt-mod(c.proficiency-bonus)]]
  let al = alignment-name(c.alignment)
  let core-note2 = if al == none { pb } else { [#al#meta-sep#pb] }

  // The placard's content is authored at its own unit (`fixed-scale`): the
  // foldable tent and the core card are the deck's two fixed compositions, tuned
  // to fill a card exactly, so they only grow when the card itself does.
  let fixed = L.fixed-scale / L.scale

  // Placard (card #1): always portrait, with no running header — its masthead lives in the body's lower half so the blank top folds back and the card stands up.
  page(
    width: portrait-w, height: portrait-h, fill: white,
    // Top margin = the horizontal fold line (half of the portrait card's height).
    margin: (x: 0.3in * L.fixed-scale, top: portrait-h / 2, bottom: 0.45in * L.fixed-scale),
    header: none, footer: none,
  )[#at-scale(fixed, _placard-card(c))]

  // Core stats card (card #2): portrait on portrait stock (5x8, 5x8L), landscape on landscape (6x4, 6x4L, 8x5).
  _card-marker(c.name, core-subtitle, core-note1, core-note2)
  if is-portrait {
    _core-card(c, is-portrait: true)
  } else {
    at-scale(fixed, _core-card(c, is-portrait: false))
  }
  if b.has-actions {
    pagebreak(); _card-marker(c.name, none, [Actions], none)
    _actions-card(c, b)
  }
  if c.spellcasting.len() > 0 { pagebreak(); _card-marker(c.name, none, [Spells], none); _spells-card(c) }
  // - Wild Magic Sorcery carries the PHB's d100 Wild Magic Surge table as an
  //   in-play reference; it follows the Spells card. The subclass's features
  //   only name the table — the sheet itself lives in data/wild-magic-surge.typ.
  if c.classes.any(cl => cl.at("subclass", default: none) == "Wild Magic Sorcery") {
    pagebreak(); _card-marker(c.name, none, [Wild Magic Surge], none)
    wild-magic-surge-table(size: 7.5 * u, atomic-rows: true)
  }
  if _item-spells(c).len() > 0 {
    pagebreak(); _card-marker(c.name, none, [Item Spells], none)
    _item-spells-card(c)
  }
  if b.has-features {
    pagebreak(); _card-marker(c.name, none, [Features & Traits], none)
    grouped-feature-box("Features & Traits", b.trait-groups, size: 7.5 * u, keep-items: true)
  }
  if b.has-gear { pagebreak(); _card-marker(c.name, none, [Gear], none, numbered: false); _gear-card(c) }
  if c.monsters.len() > 0 {
    // Monster stat blocks pack adaptively: two share one card when both fit
    // measured side by side at half the card's body width (a summon beside a
    // companion beast, the tiny Wild Shape forms); anything too tall for a
    // column keeps one-per-card, spilling across pages as before.
    // - On portrait decks each monster card is its own landscape page; on
    //   landscape decks it uses the page as set.
    // - The whole section runs in one `context`: the fit decision reads
    //   `measure`, which needs layout styles, and the pages it emits stay in
    //   flow order.
    context {
      let mpage-w = if is-portrait { landscape-w } else { L.width }
      let mpage-h = if is-portrait { landscape-h } else { L.height }
      let mmargin(e) = L.margin.at(e) + card-border.at(e) * (L.scale - 1)
      let mbody-h = mpage-h - mmargin("top") - mmargin("bottom")
      // Column a's inset shaves its width, so measure both columns there.
      let col-w = (mpage-w - mmargin("left") - mmargin("right") - grid-gutter) / 2
      let col-h(m) = measure(width: col-w - 8 * u, block(_monster-column(m))).height
      // Fit-or-shrink: pair at natural size when both columns fit the body
      // height, else scale the whole pair by just enough to make the taller
      // column fit (a wider reflow layout is what a smaller type size buys).
      // Never below 80% — under that the stat text turns to dust and the
      // blocks fall back to one per card.
      let pair-scale(a, b) = calc.min(1.0, (mbody-h - 4 * u) / calc.max(col-h(a), col-h(b)))

      let mpage(body) = page(
        width: landscape-w, height: landscape-h,
        margin: (
          left: L.margin.at("left") + card-border.at("left") * (L.scale - 1),
          right: L.margin.at("right") + card-border.at("right") * (L.scale - 1),
          top: L.margin.at("top") + card-border.at("top") * (L.scale - 1),
          bottom: L.margin.at("bottom") + card-border.at("bottom") * (L.scale - 1),
        ),
        fill: white,
        header-ascent: _header-gap,
        header: _running-head,
        footer-descent: _footer-gap,
        footer: _page-footer,
        body,
      )
      let single(m) = if is-portrait {
        mpage[
          #_card-marker(m.name, _monster-sub(m), _monster-cr-note(m), _monster-pb-note(m), numbered: false)
          #_monster-card(m)
        ]
      } else {
        pagebreak()
        _card-marker(m.name, _monster-sub(m), _monster-cr-note(m), _monster-pb-note(m), numbered: false)
        _monster-card(m)
      }
      let pair(a, b, f) = if is-portrait {
        mpage[
          #_card-marker("Creatures", none, none, none, numbered: false)
          #if f == 1.0 { _monster-pair(a, b) } else {
            std.scale(x: f * 100%, y: f * 100%, origin: top + left, reflow: true,
              box(width: (2 * col-w) / f, _monster-pair(a, b)))
          }
        ]
      } else {
        pagebreak()
        _card-marker("Creatures", none, none, none, numbered: false)
        if f == 1.0 { _monster-pair(a, b) } else {
          std.scale(x: f * 100%, y: f * 100%, origin: top + left, reflow: true,
            box(width: (2 * col-w) / f, _monster-pair(a, b)))
        }
      }

      let i = 0
      while i < c.monsters.len() {
        let m = c.monsters.at(i)
        let nxt = if i + 1 < c.monsters.len() { c.monsters.at(i + 1) } else { none }
        if nxt != none and pair-scale(m, nxt) >= 0.8 {
          pair(m, nxt, pair-scale(m, nxt))
          i += 2
        } else {
          single(m)
          i += 1
        }
      }
    }
  }
  if c.backstory != none { pagebreak(); _card-marker(c.name, none, [Backstory], none, numbered: false); _backstory-card(c) }
}
