// - Weapon features. A weapon gives one `eff-weapon`.
// - The resolver turns that effect into an attack line: bonus and damage.
// - Import aliased: `#import "weapons.typ" as weapon`, then
//   `weapon.quarterstaff`.
// - Each weapon carries its mastery property among its `properties`. The
//   resolver shows the mastery only for a weapon the character has mastered.
// - Source: SRD 5.2.1 §Equipment — Weapons.

#import "../model.typ": feature, eff-weapon
#import "../data/abilities.typ": ability

// - Range convention, following the weapon table's own columns: a melee weapon's
//   `range` is its reach — 5 ft, or 10 ft with the Reach property; a ranged weapon's
//   `range` is the range on its Ammunition property; `thrown-range` is the range on
//   the Thrown property, which a melee weapon carries alongside its reach.
// - `versatile` is the damage die the weapon deals in two hands — the value the
//   weapon table prints in parentheses after the Versatile property. The
//   assertion catches a weapon that declares one without the other: without the
//   die, a character wielding it two-handed would roll the one-handed damage.
#let _weapon(
  name,
  category: "simple",
  kind: "melee",
  ability: none,
  damage: "",
  damage-type: none,
  range: none,
  thrown-range: none,
  properties: (),
  true-strike: true,
  shillelagh: false,
  versatile: none,
) = {
  assert.eq(
    properties.contains("Versatile"), versatile != none,
    message: name + ": a Versatile weapon declares its two-handed damage die, and only a Versatile weapon may declare one",
  )
  feature(
    name,
    kind: "weapon",
    source: "Weapon",
    effects: (eff-weapon(
      name,
      category: category,
      kind: kind,
      ability: ability,
      damage: damage,
      damage-type: damage-type,
      range: range,
      thrown-range: thrown-range,
      properties: properties,
      true-strike: true-strike,
      shillelagh: shillelagh,
      versatile: versatile,
    ),),
  )
}

// - Build a +N version of a catalog weapon, for example
//   `magic-weapon(weapon.longsword, bonus: 1)`.
// - Rewrite the base feature's `eff-weapon` with the flat bonus. The resolver
//   adds the bonus to the attack and the damage.
// - A nonzero bonus marks the weapon magic for Pact of the Blade and for the
//   inventory `*`.
// - `name` overrides the display name. The default is "<Weapon> +N".
// - Keep `kind: "weapon"` so the layouts treat it like any other weapon.
#let magic-weapon(base, bonus: 1, name: none) = {
  let e = base.effects.first()
  let label = if name != none { name } else { base.name + " +" + str(bonus) }
  feature(
    label,
    kind: "weapon",
    source: base.source,
    effects: (e + (name: label, bonus: bonus),),
  )
}

// - Wield a Versatile weapon in two hands, for example
//   `two-handed(magic-weapon(weapon.longsword, bonus: 1))`.
// - Rewrite the base feature's `eff-weapon` with the grip. The resolver rolls
//   the weapon's `versatile` die instead of its one-handed die, and the attack
//   line states the other grip's damage.
// - A character holding a Shield has no hand free for the second grip. The
//   resolver still gives that character the shield's AC, so declaring both is
//   a way to sheet two fighting styles at once.
// - Composes with `magic-weapon` in either order: both rewrite fields of the
//   same effect, and only `magic-weapon` touches the display name.
#let two-handed(base) = {
  let e = base.effects.first()
  assert(
    e.at("versatile", default: none) != none,
    message: e.name + " is not Versatile; only a Versatile weapon deals a second damage die in two hands",
  )
  feature(
    base.name,
    kind: "weapon",
    source: base.source,
    effects: (e + (two-handed: true),),
  )
}

#let crossbow-light = _weapon(
  "Light Crossbow",
  category: "simple", kind: "ranged", ability: ability.dex,
  damage: "1d8", damage-type: "Piercing", range: "80/320 ft",
  properties: ("Ammunition", "Loading", "Two-Handed", "Slow"),
)

// The Shillelagh cantrip names the Club and the Quarterstaff, thus both carry the flag.
#let club = _weapon(
  "Club",
  category: "simple", kind: "melee", ability: ability.str,
  damage: "1d4", damage-type: "Bludgeoning", range: "5 ft",
  properties: ("Light", "Slow"),
  shillelagh: true,
)

#let quarterstaff = _weapon(
  "Quarterstaff",
  category: "simple", kind: "melee", ability: ability.str,
  damage: "1d6", damage-type: "Bludgeoning", range: "5 ft",
  properties: ("Versatile", "Topple"), versatile: "1d8",
  shillelagh: true,
)

#let mace = _weapon(
  "Mace",
  category: "simple", kind: "melee", ability: ability.str,
  damage: "1d6", damage-type: "Bludgeoning", range: "5 ft",
  properties: ("Sap",),
)

#let sickle = _weapon(
  "Sickle",
  category: "simple", kind: "melee", ability: ability.str,
  damage: "1d4", damage-type: "Slashing", range: "5 ft",
  properties: ("Light", "Nick"),
)

#let longsword = _weapon(
  "Longsword",
  category: "martial", kind: "melee", ability: ability.str,
  damage: "1d8", damage-type: "Slashing", range: "5 ft",
  properties: ("Versatile", "Sap"), versatile: "1d10",
)

#let dagger = _weapon(
  "Dagger",
  category: "simple", kind: "melee",
  damage: "1d4", damage-type: "Piercing", range: "5 ft", thrown-range: "20/60 ft",
  properties: ("Finesse", "Light", "Thrown", "Nick"),
)

#let battleaxe = _weapon(
  "Battleaxe",
  category: "martial", kind: "melee", ability: ability.str,
  damage: "1d8", damage-type: "Slashing", range: "5 ft",
  properties: ("Versatile", "Topple"), versatile: "1d10",
)

#let warhammer = _weapon(
  "Warhammer",
  category: "martial", kind: "melee", ability: ability.str,
  damage: "1d8", damage-type: "Bludgeoning", range: "5 ft",
  properties: ("Versatile", "Push"), versatile: "1d10",
)

// Give a Finesse weapon no explicit ability: the resolver picks the better of
// Str and Dex.
#let rapier = _weapon(
  "Rapier",
  category: "martial", kind: "melee",
  damage: "1d8", damage-type: "Piercing", range: "5 ft",
  properties: ("Finesse", "Vex"),
)

#let shortsword = _weapon(
  "Shortsword",
  category: "martial", kind: "melee",
  damage: "1d6", damage-type: "Piercing", range: "5 ft",
  properties: ("Finesse", "Light", "Vex"),
)

// A Rogue is proficient with this martial weapon by name. The resolver matches
// weapon proficiency by category or by name (see resolve-attacks).
#let scimitar = _weapon(
  "Scimitar",
  category: "martial", kind: "melee",
  damage: "1d6", damage-type: "Slashing", range: "5 ft",
  properties: ("Finesse", "Light", "Nick"),
)

#let shortbow = _weapon(
  "Shortbow",
  category: "simple", kind: "ranged", ability: ability.dex,
  damage: "1d6", damage-type: "Piercing", range: "80/320 ft",
  properties: ("Ammunition", "Two-Handed", "Vex"),
)

#let hand-crossbow = _weapon(
  "Hand Crossbow",
  category: "martial", kind: "ranged", ability: ability.dex,
  damage: "1d6", damage-type: "Piercing", range: "30/120 ft",
  properties: ("Ammunition", "Light", "Loading", "Vex"),
)
