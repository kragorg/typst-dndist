// Letter-sized sheet.
// - The arrangement follows the official 5.5e character sheet.
// - The skin is dndist: ETBembo, Montserrat, maroon; no flourishes.
// - Page 1 is the core: a left ability rail that groups each skill below its ability, boxed stat fields, and framed sections (weapons, class features, species traits, feats, proficiencies).
// - A hard pagebreak starts spellcasting and roleplay.
// - The roleplay pages keep printable blanks (death saves, hit dice, coins, appearance, backstory) for hand-filling.
// - Only the core is fixed at one page.
// - The roleplay section is page flow and runs as long as the spell tables and equipment need: 3 pages for a level-2 druid, 7 for a level-10 Fighter/Warlock.
// - Its boxes use the repeat-header "(continued)" treatment.
// - The components come from common.typ.

#import "../resolve.typ": resolve
#import "../data/abilities.typ": ability-ids
#import "../data/skills.typ": skill-list
#import "common.typ": *

// A labelled sub-block: a small accent label above its body.
// - `stack` sets the label-to-body space exactly, whatever the body's block defaults are.
// - So the armor icon row, the weapons list and the tools list stay at the same distance below their labels.
#let _labelled-block(name, body) = block(spacing: 7pt, stack(
  spacing: 2.5pt,
  eyebrow(name, size: 6.5pt),
  body,
))

// A proficiency sub-block: a small label and a comma-joined list; empty shows nothing.
#let _prof-block(name, items) = if items.len() > 0 {
  _labelled-block(name, text(font: body-font, size: 8.5pt)[#titly-list(items)])
}

// A body-only feature list (bold name — description), for use in a framed-box.
// - The items flow; in a repeat-header box an item can split across a page.
// - Keep items split here: a split fills the column tail and keeps a dense build's core on one page.
// - An empty list shows a quiet em dash.
//
// `grouped` puts the items in source groups below small eyebrow sub-headers (`trait-groups`, common.typ).
// - Class Features shows one group for each class, then the invocations.
// - Species Traits is one group; its header names the species.
// - Feats stays flat: its lines carry the category and granter tags.
#let _feature-list(items, size: 8pt, grouped: false) = if items.len() == 0 {
  text(size: size, fill: rule-color)[—]
} else if grouped {
  grouped-feature-lines(trait-groups(items), size: size)
} else {
  feature-lines(items, size: size)
}

// Stacked blank lines, for printable tables/boxes with no computed content.
#let _blank-rows(n) = stack(spacing: 7pt, ..range(n).map(_ => blank-line(100%)))

// Max hit-dice pool: each class gives (level) dice of its hit die.
// - The dice group by die type: "1d8", or "3d8 + 2d10" for a multiclass.
#let _hit-dice(classes) = {
  let by-die = (:)
  for cls in classes {
    let die = cls.at("hit-die", default: none)
    if die != none {
      by-die.insert(die, by-die.at(die, default: 0) + cls.at("level", default: 0))
    }
  }
  if by-die.len() == 0 { return [—] }
  by-die.pairs().map(((die, n)) => str(n) + die).join(" + ")
}

// Parse a currency string ("47 gp, 8 sp") into a denomination->amount dict.
// - The keys are cp, sp, ep, gp and pp.
// - Unknown parts are ignored.
// - A comma between two digits is a thousands separator ("1,026 gp"), thus it
//   is removed before the split. A separator comma always follows a
//   denomination, so the two never collide.
#let _parse-currency(s) = {
  let coins = (:)
  if s == none { return coins }
  let s = s.replace(regex("(\d),(\d)"), m => m.captures.at(0) + m.captures.at(1))
  for part in s.split(",") {
    let toks = part.trim().split(" ").filter(t => t != "")
    if toks.len() >= 2 and ("cp", "sp", "ep", "gp", "pp").contains(lower(toks.at(1))) {
      coins.insert(lower(toks.at(1)), toks.at(0))
    }
  }
  coins
}

#let letter-sheet(char) = {
  let c = resolve(char)

  set page(
    paper: "us-letter", margin: 0.5in, fill: white,
    footer-descent: 6pt,
    // A school-synergy note or a short-regain note on this page shares the line with the page number (see `footer-line`).
    footer: context footer-line(
      page-number-footer(counter(page).get().first(), counter(page).final().first(), size: 7.5pt),
      7.5pt,
    ),
  )
  set text(font: body-font, size: 9.5pt, fill: ink)
  // - Explicit math (`$…$` in prose, `fmt-*` in structured cells) shows in the Euler math font, for a LaTeX look.
  // - This rule supplies that font only.
  show math.equation: math-styled

  // --- Header row ----------------------------------------------------------
  let has-shield = char.features.any(f => feature-kind(f) == "shield")
  grid(
    columns: (2.7fr, 0.9fr, 1fr, 1.5fr, 1.1fr, 1.3fr),
    column-gutter: 5pt,
    rows: 78pt,
    identity-box(
      c.name,
      c.background,
      if c.species != none { c.species.name } else { none },
      c.creature-type,
      c.classes,
    ),
    level-box(c.level),
    ac-box(c.ac, has-shield),
    hp-box(c.max-hp, c.temp-hp),
    hit-dice-box(fmt-dice(_hit-dice(c.classes))),
    death-saves-box(),
  )
  v(letter-section-gap)

  // An ability cell: a large modifier, a small score, the save, then its skills.
  let ability-cell-for(id) = ability-rail-cell(
    upper(id), c.abilities.at(id), c.ability-mods.at(id), c.saves.at(id),
    skill-list.filter(s => s.ability == id).map(sk => skill-row(sk, c.skills.at(sk.id))),
  )

  let class-feats = c.traits.filter(t =>
    is-class-feature-kind(t) and t.at("desc", default: none) != none)
  let species-traits = c.traits.filter(t => feature-kind(t) == "trait")
  let feats = c.traits.filter(is-feat-kind)

  // --- Body: left (abilities + proficiencies) | right (stats + features) ----
  grid(
    columns: (0.92fr, 1.4fr),
    column-gutter: grid-gutter,
    align: top,

    // LEFT macro-column.
    {
      // Two ability sub-columns: STR/DEX/CON (with Prof Bonus, Inspiration) | INT/WIS/CHA.
      grid(
        columns: (1fr, 1fr),
        column-gutter: 5pt,
        align: top,
        stack(
          spacing: 5pt,
          stat-box("Proficiency Bonus", fmt-mod(c.proficiency-bonus), big: true),
          ability-cell-for("str"),
          ability-cell-for("dex"),
          ability-cell-for("con"),
          inspiration-box(),
        ),
        stack(
          spacing: 5pt,
          ability-cell-for("int"),
          ability-cell-for("wis"),
          ability-cell-for("cha"),
        ),
      )
      v(letter-section-gap)
      framed-box("Equipment Training & Proficiencies", {
        _labelled-block("Armor", armor-training(c.proficiencies.armor))
        _prof-block("Weapons", c.proficiencies.weapon)
        _prof-block("Tools", c.proficiencies.tool.map(tool-label))
      })
      // - A framed box of the conditional save advantages, the damage responses and the senses.
      // - It goes below the saves; each save is in its ability rail cell above.
      // - The bottom of the left column has slack below the full-height ability rail.
      // - Render it only when the character has one of these.
      if has-defenses(c) {
        v(letter-section-gap)
        framed-box("Defenses & Senses", character-notes-for(c, size: 8pt))
      }
    },

    // RIGHT macro-column.
    {
      // Stat row: Initiative / Speed / Size / Passive Perception.
      grid(
        columns: 4 * (1fr,),
        column-gutter: 5pt,
        rows: 38pt,
        stat-box("Initiative", fmt-mod(c.initiative), height: 100%),
        stat-box("Speed", [#bold-num(c.speed)#text(size: 6pt)[ ft]], height: 100%),
        stat-box("Size", or-dash(c.size), height: 100%),
        stat-box("Passive Perception", c.passives.perception, height: 100%),
      )
      v(letter-section-gap)

      // - Show the computed attacks.
      // - Show blank rows for hand-filling when there are no attacks.
      // - Skip blank rows after the attacks: they distract.
      // - Render at 8pt, the size of the page-1 right column's other dense boxes: the attack table's five columns leave the Notes column about 13 characters at this width, and 8.5pt wraps most weapons' properties onto a second line.
      framed-box("Weapons & Damage Cantrips", {
        if c.attacks.len() > 0 { attack-table(c.attacks, attacks-per-action: c.attacks-per-action, size: 8pt) } else { _blank-rows(3) }
        if c.cunning-strikes.len() > 0 {
          // - This gap is table-to-table, separate from heading-to-content.
          // - Use the loose gap between blocks, as the card deck does between the attack table and the Cunning Strike table.
          // - Use the section gap, separate from the head gap.
          v(letter-section-gap)
          cunning-strike-table(c.cunning-strikes, size: 8pt)
        }
        if c.metamagic.len() > 0 {
          v(letter-section-gap)
          metamagic-table(c.metamagic, size: 8pt)
        }
      })
      v(letter-section-gap)

      // - Stack class features, then species traits, then feats.
      // - Each box uses the full width of the right macro-column.
      // - The ability rail fixes the height of the left column, so the right column is the taller one and takes this content.
      // - The full width makes the wrapped height approximately one half, so a trait-heavy and feat-heavy build (a Bugbear rogue) stays on the one page the core gets before the hard pagebreak.
      // - Each box can overflow, so each uses the repeat-header "(continued)" treatment.
      // - Class Features and Species Traits group by source; Feats stays flat (see `_feature-list`).
      framed-box("Class Features", _feature-list(class-feats, grouped: true), repeat-header: true)
      v(letter-section-gap)
      framed-box("Species Traits", _feature-list(species-traits, grouped: true), repeat-header: true)
      v(letter-section-gap)
      framed-box("Feats", _feature-list(feats), repeat-header: true)
    },
  )

  // --- Page 2: spellcasting | roleplay -------------------------------------
  pagebreak()

  grid(
    columns: (1.45fr, 1fr),
    column-gutter: 12pt,
    align: top,

    // Left: spellcasting stats, then the spells table.
    {
      if c.spellcasting.len() > 0 {
        // - The card's own header, at the letter's size: one row per distinct set of numbers, sources sharing a row joined by "/".
        framed-box("Spellcasting", spellcasting-head(
          c.spellcasting, size: 9pt, source-label: "Source",
        ))
        v(letter-section-gap)

        framed-box(
          "Cantrips & Prepared Spells",
          spell-table(c.spellcasting, size: 8.5pt, atomic-rows: true, school-notes: spell-school-notes(c.traits)),
          repeat-header: true,
        )
      } else {
        framed-box("Cantrips & Prepared Spells", _blank-rows(12))
      }
    },

    // Right: roleplay + equipment.
    stack(
      spacing: letter-section-gap,
      framed-box("Appearance", [], min-height: 80pt),
      framed-box(
        "Backstory & Personality",
        if c.backstory != none {
          set par(justify: true, leading: 0.5em, spacing: 0.7em)
          text(font: body-font, size: 8.5pt)[#c.backstory]
        } else { [] },
        min-height: 110pt,
      ),
      framed-box("Alignment", text(font: body-font, size: 9pt)[#or-dash(alignment-name(c.alignment))]),
      framed-box(
        "Languages",
        if c.proficiencies.language.len() > 0 {
          text(font: body-font, size: 8.5pt)[#titly-list(c.proficiencies.language.sorted())]
        } else { text(fill: rule-color)[—] },
      ),
      framed-box("Equipment", {
        // - Two labelled groups, stacked as the Resources box stacks its recharge groups.
        // - EQUIPPED (`c.equipped`) is live gear; INVENTORY (`c.equipment`) is inert cargo.
        // - Keep the two lists separate: the split carries meaning.
        if c.equipped.len() > 0 {
          eyebrow([Equipped], size: 6pt)
          v(3pt)
          bullet-lines(c.equipped, size: 8.5pt)
        }
        if c.equipment.len() > 0 {
          if c.equipped.len() > 0 { v(6pt) }
          eyebrow([Inventory], size: 6pt)
          v(3pt)
          bullet-lines(c.equipment, size: 8.5pt)
        }
        if c.equipped.len() == 0 and c.equipment.len() == 0 { _blank-rows(4) }
        v(5pt)
        line(length: 100%, stroke: 0.3pt + rule-color)
        v(3pt)
        eyebrow([Magic Item Attunement], size: 6pt)
        v(4pt)
        stack(
          spacing: 7pt,
          ..range(3).map(_ => grid(
            columns: (auto, 1fr),
            column-gutter: 4pt,
            align: horizon,
            checkbox(size: 6pt),
            blank-line(100%),
          )),
        )
      }),
      framed-box("Coins", coins-box(coins: _parse-currency(c.currency))),
      // - Show a diamond tracker for each limited-use resource pool (Innate Sorcery, Lucky, Wails from the Grave, ...), plus spell slot levels.
      // - Include a spell-slot line per level even when there are no limited-use pools.
      // - Keep the box on this page with the other tracking boxes (attunement, coins): the ability rail fixes the height of page 1's grid, which has no reliable slack.
      {
        let resources = if c.spellcasting.len() > 0 {
          slot-resource-items(merge-slots(c.spellcasting)) + c.limited-uses
        } else { c.limited-uses }
        if resources.len() > 0 {
          framed-box("Resources", limited-use-lines(resources, size: 8.5pt, single-column: true))
        }
      },
    ),
  )
}
