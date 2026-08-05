#import "../../model.typ": feature, limited-use-feature, eff-prof, eff-skill-bonus
#import "../../data/abilities.typ": ability
#import "../../data/skills.typ": skill

#import "common.typ": _class, _full-caster-feature

// A dice roll plus an ability modifier, as math; a negative modifier reads as a subtraction.
#let _roll(count, die, m) = if m < 0 {
  $#{str(count)}d #{die} - #{calc.abs(m)}$
} else {
  $#{str(count)}d #{die} + #m$
}

#let divine-order-thaumaturge(cantrip) = feature(
  "Divine Order (Thaumaturge)",
  kind: "class-feature",
  source: "Cleric",
  cantrips: (cantrip,),
  effects: (
    eff-skill-bonus(skill.arcana, ability: ability.wis, min-value: 1, source: "Divine Order"),
    eff-skill-bonus(skill.religion, ability: ability.wis, min-value: 1, source: "Divine Order"),
  ),
  desc: [Thaumaturge: you know one extra Cleric cantrip, and add your Wisdom modifier (minimum $+1$) to Intelligence (Arcana) and Intelligence (Religion) checks.],
)

#let divine-order-protector = feature(
  "Divine Order (Protector)",
  kind: "class-feature",
  source: "Cleric",
  effects: (
    eff-prof("weapon", "martial"),
    eff-prof("armor", "heavy"),
  ),
  desc: [Protector: you gain proficiency with Martial weapons and training with Heavy armor.],
)

// - Divine Order used when the character declares no choice.
// - This form grants no extra cantrip, because the character chose none.
#let default-thaumaturge = feature(
  "Divine Order (Thaumaturge)",
  kind: "class-feature",
  source: "Cleric",
  effects: (
    eff-skill-bonus(skill.arcana, ability: ability.wis, min-value: 1, source: "Divine Order"),
    eff-skill-bonus(skill.religion, ability: ability.wis, min-value: 1, source: "Divine Order"),
  ),
  desc: [Thaumaturge: you know one extra Cleric cantrip, and add your Wisdom modifier (minimum $+1$) to Intelligence (Arcana) and Intelligence (Religion) checks.],
)

#let get-divine-order-feature(order) = {
  if type(order) == dictionary {
    order
  } else if order == "protector" {
    divine-order-protector
  } else {
    default-thaumaturge
  }
}

// - Channel Divinity: 2024 Cleric, level 2.
// - The uses come from the class table; the effects are nested children that spend this pool.
// - The parent carries no `notes`: its children hold the action rows, so a note here would add a second row for the same feature.
#let channel-divinity(level) = {
  let uses = if level >= 18 { 4 } else if level >= 6 { 3 } else { 2 }
  let dice = if level >= 18 { 4 } else if level >= 13 { 3 } else if level >= 7 { 2 } else { 1 }
  limited-use-feature(
    "Channel Divinity",
    uses,
    recharge: "long-short-regain",
    kind: "class-feature",
    source: "Cleric",
    desc: ctx => [Channel divine energy from the Outer Planes: each time you use it, choose one of this class's Channel Divinity effects. One that requires a saving throw uses your Cleric spell save DC (DC $#{8 + ctx.pb + ctx.ability-mods.wis}$).],
    features: (
      feature(
        "Divine Spark",
        kind: "class-feature",
        source: "Cleric",
        activation: "Action",
        desc: ctx => [As a Magic Action, point your Holy Symbol at another creature you can see within 30 ft and roll #_roll(dice, 8, ctx.ability-mods.wis). Either restore that many Hit Points to it, or deal that much Necrotic or Radiant damage (your choice) on a failed Constitution saving throw (DC $#{8 + ctx.pb + ctx.ability-mods.wis}$), half as much on a success.],
        notes: ctx => [Restore #_roll(dice, 8, ctx.ability-mods.wis) HP to a creature within 30 ft, or deal that much Necrotic or Radiant damage on a failed CON $#{8 + ctx.pb + ctx.ability-mods.wis}$ save (half on a success).],
      ),
      feature(
        "Turn Undead",
        kind: "class-feature",
        source: "Cleric",
        activation: "Action",
        desc: ctx => [As a Magic Action, present your Holy Symbol and censure Undead. Each Undead of your choice within 30 ft makes a Wisdom saving throw (DC $#{8 + ctx.pb + ctx.ability-mods.wis}$). On a failure it has the Frightened and Incapacitated conditions for 1 minute and moves as far from you as it can on its turns, ending early if it takes damage or if you have the Incapacitated condition or die.],
        notes: ctx => [Each Undead of your choice within 30 ft is Frightened and Incapacitated for 1 min on a failed WIS $#{8 + ctx.pb + ctx.ability-mods.wis}$ save, and flees you.],
      ),
    ),
  )
}

#let cleric(
  level: 1,
  subclass: none,
  skills: (),
  divine-order: "thaumaturge",
  cantrips: (),
  prepared: (),
) = {
  let order-feature = get-divine-order-feature(divine-order)
  let extra-cantrips = order-feature.at("cantrips", default: ())

  _class(
    "Cleric", level, subclass: subclass, hit-die: "d8",
    saves: ("wis", "cha"), armor: ("light", "medium", "shield"),
    weapons: ("simple",), skills: skills,
    features: (
      _full-caster-feature("Cleric", ability.wis, level, subclass,
        cantrips: cantrips + extra-cantrips, spells: prepared),
      order-feature,
    ) + if level >= 2 { (channel-divinity(level),) } else { () },
  )
}
