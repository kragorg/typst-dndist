// - Metamagic options are the Sorcerer's level-2 class feature (2024 PHB).
// - The number known grows with level (`_metamagic-known`, classes.typ).
// - `sorcerer()` validates the count and nests the chosen options under a
//   `Metamagic` parent feature, so they flatten into the trait list.
// - Each option spends Sorcery Points (the Font of Magic pool) to modify a
//   spell as it is cast; none carries its own limited-use tracker.
// - Import aliased: `#import "metamagic.typ" as metamagic`.

#import "../model.typ": feature

// - A Metamagic option is a Sorcerer class feature; `source` is display only.
// - `notes` (no `activation`) routes each option to the Metamagic table on the
//   actions card; `desc` also surfaces it in the Features & Traits list under
//   the parent. `cost` is the Sorcery Point spend shown in the table's Cost
//   column.
#let _option(name, ..rest) = feature(
  name, kind: "class-feature", source: "Sorcerer", ..rest.named(),
)
#let empowered-spell = _option(
  "Empowered Spell",
  cost: "1 SP",
  notes: [Spend 1 SP to reroll up to 3 damage dice of a spell; use the new rolls.],
  desc: [When you roll damage for a spell, you can spend 1 Sorcery Point to reroll up to 3 damage dice and you must use the new rolls. You can use Empowered Spell even if you've already used a different Metamagic option during the casting of the spell.],
)

#let seeking-spell = _option(
  "Seeking Spell",
  cost: "1 SP",
  notes: [Spend 1 SP to reroll a missed spell attack d20; use the new roll.],
  desc: [If you make an attack roll for a spell and miss, you can spend 1 Sorcery Point to reroll the d20, and you must use the new roll. You can use Seeking Spell even if you've already used a different Metamagic option during the casting of the spell.],
)
