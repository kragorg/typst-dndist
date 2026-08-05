// dndist — D&D 5.5e character sheets in Typst.
//
// - This is the public API.
// - Import all of it with `#import "@preview/dndist:1.0.0": *`.
// - It gives character(), feature(), id-of() and the eff-* effect constructors.
// - It gives resolve(), modifier() and prof-bonus().
// - It gives the renderers card-sheet() and letter-sheet().
// - It gives sheet(), which selects a renderer from `--input layout=…`.
// - It gives the game-object namespaces: ability, skill, tool.
// - It gives the feature namespaces: species, class, subclass, invocation,
//   background, item, spell, feat.

#import "src/model.typ": (
  character, feature, limited-use-feature, asi, carried, id-of,
  eff-ability, eff-ac-base, eff-ac-formula, eff-ac-bonus, eff-ac-set,
  eff-prof, eff-save-advantage, eff-check-advantage, eff-save-bonus, eff-resistance, eff-sense, eff-limited-use, eff-skill-rule, eff-skill-bonus, eff-stat, eff-spellcasting,
  eff-spellcasting-bonus, eff-weapon, eff-weapon-mastery, eff-pact-blade,
  eff-extra-attack, eff-spell-damage-bonus, eff-reach, eff-cunning-strike,
  eff-unarmed, eff-spell-any-slot,
)
#import "src/resolve.typ": resolve, modifier, prof-bonus
#import "src/layout/card.typ": card-sheet
#import "src/layout/letter.typ": letter-sheet

// - Render a declared character in the selected layout.
// - The layout comes from `sys.inputs.layout` (`--input layout=card|letter`).
// - End a character file with one `#sheet(char)`.
// - Do not select a renderer in a character file: this function does it.
// - Give `layout:` to override the input.
#let sheet(char, layout: sys.inputs.at("layout", default: "card")) = {
  if layout == "letter" {
    letter-sheet(char)
  } else if layout == "card" {
    card-sheet(char)
  } else {
    panic("unknown layout '" + layout + "'; expected 'card' or 'letter'")
  }
}

#import "src/features/species.typ" as species
#import "src/features/classes.typ" as class
#import "src/features/subclasses.typ" as subclass
#import "src/features/invocations.typ" as invocation
#import "src/features/backgrounds.typ" as background
#import "src/features/items.typ" as item
#import "src/features/weapons.typ" as weapon
#import "src/features/weapons.typ": magic-weapon, two-handed
#import "src/features/spells.typ" as spell
#import "src/features/feats.typ" as feat

// Game objects for direct use in the DSL.
#import "src/data/abilities.typ": ability
#import "src/data/skills.typ": skill
#import "src/data/tools.typ": tool
