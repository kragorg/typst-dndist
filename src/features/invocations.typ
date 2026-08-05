// - Eldritch Invocations are the Warlock's level-1 class feature (2024 PHB).
// - The number known grows with level (`_invocations-known`, classes.typ).
// - `warlock()` validates the count and nests the chosen invocations, so they flatten into the trait list.
// - Entries with a player choice are functions; entries without one are plain values.
// - Comments record the prerequisites; only the per-level count is enforced.
// - Import aliased: `#import "invocations.typ" as invocation`.

#import "../model.typ": feature, eff-pact-blade, eff-spell-damage-bonus, eff-extra-attack, eff-save-advantage
#import "../data/abilities.typ": ability
#import "spells.typ" as spell

// - An invocation is a Warlock class feature, but carries its own `kind: "invocation"`.
// - The layouts group the invocations under an ELDRITCH INVOCATIONS eyebrow off that kind.
// - Do not group off the `source` display string: it is brittle.
// - The shared predicates (`is-trait-kind`, `is-class-feature-kind`, common.typ) include the kind,
//   so an invocation renders like any other class feature, keyed off `desc` and `activation`.
// - `source` is display metadata only.
#let _invocation(name, ..rest) = feature(
  name, kind: "invocation", source: "Eldritch Invocation", ..rest.named(),
)

// - The bonded weapon can change turn to turn, so this invocation names no weapon.
// - `eff-pact-blade` makes the resolver treat every melee or magic weapon as proficient and CHA-based.
#let pact-of-the-blade = _invocation(
  "Pact of the Blade",
  activation: "Bonus Action",
  effects: (eff-pact-blade(ability.cha),),
  desc: [Bonus Action: conjure a Simple or Martial melee weapon, or bond with a magic weapon you touch. While bonded: proficiency with it; use CHA for attack and damage rolls; can deal Necrotic, Psychic, or Radiant damage instead of its normal type.],
  notes: [Conjure a weapon or bond with one you touch; proficiency, CHA for attack/damage, Necrotic/Psychic/Radiant option while bonded.],
)

// - `cantrip` is a spell object or a display name.
// - Prerequisite: level 2+, a Warlock cantrip that deals damage.
// - Repeatable: choose a different cantrip each time.
#let agonizing-blast(cantrip) = {
  let cname = if type(cantrip) == str { cantrip } else { cantrip.name }
  _invocation(
    "Agonizing Blast",
    effects: (eff-spell-damage-bonus(cname, ability: "cha"),),
    desc: [Add your Charisma modifier to #emph(cname)'s damage rolls.],
  )
}

// - Prerequisite: level 2+.
// - The activation is an Action, the casting time of False Life.
// - The at-will cast is display-only: it has no limited-use pool.
#let fiendish-vigor = _invocation(
  "Fiendish Vigor",
  activation: "Action",
  desc: [Cast _False Life_ on yourself at will without expending a spell slot; you automatically take the maximum Temporary HP ($2d 4 + 4$ → 12 THP).],
  notes: [Cast _False Life_ at will; automatic max roll, 12 THP.],
)

// Prerequisite: level 5+, Pact of the Blade.
#let thirsting-blade = _invocation(
  "Thirsting Blade",
  effects: (eff-extra-attack(2),),
  desc: [Attack twice, instead of once, whenever you take the Attack action with your pact weapon on your turn.],
)

// - No prerequisite.
// - The save advantage is display-only: it changes no number, and it is badged beneath the saves.
#let eldritch-mind = _invocation(
  "Eldritch Mind",
  effects: (eff-save-advantage([on Constitution saves to maintain Concentration], source: "Eldritch Mind"),),
  desc: [You have Advantage on Constitution saving throws that you make to maintain Concentration.],
)

// - The book's spells count as prepared Warlock spells, cast with the Warlock's own spellcasting.
// - They ride as plain `cantrips`/`spells` fields; `warlock()` folds them into the Pact Magic source.
// - Do not emit `eff-spellcasting` here: it adds a redundant spellcasting-header row.
#let pact-of-the-tome(cantrips: (), spells: ()) = _invocation(
  "Pact of the Tome",
  cantrips: cantrips,
  spells: spells,
  desc: [Conjure a Book of Shadows at the end of a rest. It holds three cantrips and two level-1 Ritual spells of your choice (any class list), which you have prepared as Warlock spells while it's on you. It's a Spellcasting Focus.],
)

// - `cantrip` is a spell object or a display name.
// - The push is display-only: this engine models no forced movement.
// - Prerequisite: level 2+, a Warlock cantrip that deals damage with an attack roll.
// - Repeatable.
#let repelling-blast(cantrip) = {
  let cname = if type(cantrip) == str { cantrip } else { cantrip.name }
  _invocation(
    "Repelling Blast",
    desc: [When you hit a Large or smaller creature with #emph(cname), you can push it up to 10 ft straight away from you.],
  )
}

// - `origin-feat` is a feat feature, for example `feat.tough`.
// - The nested feat flattens into the trait list and contributes its effects.
// - Prerequisite: level 2+.
// - Repeatable.
#let lessons-of-the-first-ones(origin-feat) = _invocation(
  "Lessons of the First Ones",
  desc: [You have received knowledge from an elder entity of the multiverse, gaining one Origin feat of your choice: #origin-feat.name.],
  features: (origin-feat,),
)

// - The spell rides in the `spells` field; `warlock()` folds it into the Pact Magic source.
// - `warlock()` pins it to its own level: a slotless cast cannot upcast, so no ▲/scaling prose shows.
// - Prerequisite: level 5+.
#let one-with-shadows = _invocation(
  "One with Shadows",
  spells: (spell.invisibility,),
  desc: [While you're in an area of Dim Light or Darkness, you can cast _Invisibility_ on yourself without expending a spell slot.],
)

// Prerequisite: level 9+.
#let visions-of-distant-realms = _invocation(
  "Visions of Distant Realms",
  spells: (spell.arcane-eye,),
  desc: [You can cast _Arcane Eye_ without expending a spell slot.],
)
