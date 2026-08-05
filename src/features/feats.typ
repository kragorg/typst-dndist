// - Feats are features that contribute effects, like species, classes, and items.
// - A background can nest a feat as its origin feat.
// - Import aliased: `#import "feats.typ" as feat`.

#import "../model.typ": feature, eff-ability, eff-prof, eff-spellcasting, eff-stat, eff-limited-use, eff-spell-any-slot, id-of
#import "../data/abilities.typ": ability
#import "../data/tools.typ": tool
#import "spells.typ" as spell

#let lucky = feature(
  "Lucky",
  kind: "feat",
  source: "Origin Feat",
  effects: (eff-limited-use("Luck Points", ctx => ctx.pb, uses-label: "PB", source: "Lucky"),),
  desc: [Luck Points (Proficiency Bonus/Long Rest). Spend 1 for Advantage on a D20 Test, or spend 1 to impose Disadvantage on an attack roll against you.],
)

// The "proficiency" kind makes the resolver add the Proficiency Bonus and ignore the value.
#let alert = feature(
  "Alert",
  kind: "feat",
  source: "Origin Feat",
  effects: (eff-stat("initiative", 0, kind: "proficiency"),),
  desc: [Add your Proficiency Bonus to your Initiative rolls. Immediately after rolling Initiative, you can swap it with the Initiative of one willing ally (neither of you Incapacitated).],
)

#let crossbow-expert = feature(
  "Crossbow Expert",
  kind: "feat",
  source: "Feat",
  effects: (eff-ability(ability.dex, 1),),
  desc: [$+1$ Dexterity. You ignore the Loading property of crossbows and can load one without a free hand. Being within 5 ft of an enemy doesn't impose Disadvantage on your crossbow attacks. When you make the extra attack of the Light property with a crossbow, you can add your ability modifier to its damage.],
)

// - The `eff-stat` value is a function of the computed context, so the bonus scales with level.
// - The bonus adds on top of the computed or declared maximum HP.
#let tough = feature(
  "Tough",
  kind: "feat",
  source: "Origin Feat",
  effects: (eff-stat("hp", ctx => 2 * ctx.level),),
  desc: [Your Hit Point maximum increases by an amount equal to twice your character level, and by 2 more each level you gain thereafter.],
)

// - Three instrument proficiencies model as the one Musical Instrument tool proficiency.
// - The Heroic Inspiration grant is not modelled: it changes no computed stat.
#let musician = feature(
  "Musician",
  kind: "feat",
  source: "Origin Feat",
  effects: (eff-prof("tool", tool.musical-instrument),),
)

#let resilient(abil) = feature(
  "Resilient (" + upper(id-of(abil)) + ")",
  kind: "feat",
  source: "Feat",
  effects: (eff-ability(abil, 1), eff-prof("save", abil)),
)

// - A General feat: `abil` is Strength or Dexterity.
// - Enhanced Dual Wielding is a nested feature, so it goes in the card deck's Bonus Action table.
// - Quick Draw modifies the free object interaction, thus it stays on the passive parent.
#let dual-wielder(abil) = feature(
  "Dual Wielder",
  kind: "feat",
  source: "Feat",
  effects: (eff-ability(abil, 1),),
  desc: [$+1$ to #ability.at(id-of(abil)).name. You can draw or stow two weapons that lack the Two-Handed property when you would normally draw or stow only one.],
  features: (
    feature(
      "Enhanced Dual Wielding",
      kind: "feat",
      source: "Feat",
      activation: "Bonus Action",
      desc: [When you take the Attack action with a weapon that has the Light property, you can make one extra attack as a Bonus Action later on the same turn with a different Melee weapon that lacks the Two-Handed property. You add your ability modifier to that attack's damage only if the modifier is negative.],
      notes: [After an Attack action with a Light weapon, one extra attack with a different one-handed Melee weapon; no ability modifier to its damage.],
    ),
  ),
)

// - The granted Mage Hand is a customized variant of the catalog spell.
// - Do not change `spell.mage-hand` itself: it must stay feat-free for other casters.
// - Its note appends to the catalog's; the range and component changes have their own columns.
// - The shove is a nested feature, so it goes in the card deck's Bonus Action table.
// - `casting-ability` defaults to the boosted ability; pass it only when the two differ.
#let telekinetic(abil, casting-ability: auto) = {
  let casting-ability = if casting-ability == auto { abil } else { casting-ability }
  feature(
    "Telekinetic",
    kind: "feat",
    source: "Feat",
    effects: (
      eff-ability(abil, 1),
      eff-spellcasting("Telekinetic", casting-ability, cantrips: (
        spell.mage-hand + (
          range: "60 ft",
          components: none,
          notes: [#spell.mage-hand.notes The hand can be Invisible.],
        ),
      )),
    ),
    desc: [$+1$ to #ability.at(id-of(abil)).name. You know the _Mage Hand_ cantrip: no Verbal or Somatic components, $+30$ ft to its range and to how far the hand can stray, and the hand can be Invisible.],
    features: (
      feature(
        "Telekinetic Shove",
        kind: "feat",
        source: "Feat",
        activation: "Bonus Action",
        desc: [As a Bonus Action, telekinetically shove one creature you can see within 30 ft (Str. save DC = 8 + PB + casting mod) 5 ft toward or away from you.],
        notes: ctx => {
          let dc = 8 + ctx.pb + ctx.ability-mods.at(id-of(casting-ability))
          [Shove a creature 5 ft toward/away (STR #dc save), range 30 ft.]
        },
      ),
    ),
  )
}

// - Grants Misty Step and one chosen 1st-level Divination or Enchantment spell, always prepared.
// - `eff-spell-any-slot` projects each spell into every other spellcasting source (resolve.typ).
// - `casting-ability` defaults to the boosted ability; pass it only when the two differ.
// - The parameter is `chosen-spell`, not `spell`: `spell` is the imported spells module.
#let fey-touched(abil, casting-ability: auto, chosen-spell: none) = {
  assert(chosen-spell != none, message: "Fey Touched grants one 1st-level Divination or Enchantment spell")
  let casting-ability = if casting-ability == auto { abil } else { casting-ability }
  feature(
    "Fey Touched",
    kind: "feat",
    source: "Feat",
    effects: (
      eff-ability(abil, 1),
      // - Each spell pins to its own base level.
      // - A free slotless cast cannot upcast, so `fixed-slot` must suppress the ▲/scaling prose.
      eff-spellcasting("Fey Touched", casting-ability, spells: (
        (spell: chosen-spell, slot: chosen-spell.at("level", default: 1)),
        (spell: spell.misty-step, slot: spell.misty-step.at("level", default: 1)),
      )),
      eff-limited-use(chosen-spell, 1, source: "Fey Touched"),
      eff-limited-use(spell.misty-step, 1, source: "Fey Touched"),
      eff-spell-any-slot(chosen-spell, casting-ability, "Fey Touched"),
      eff-spell-any-slot(spell.misty-step, casting-ability, "Fey Touched"),
    ),
    desc: [$+1$ to #ability.at(id-of(abil)).name. You always have _Misty Step_ and #emph(chosen-spell.name) (a 1st-level Divination/Enchantment spell) prepared, and can cast each once per Long Rest without a spell slot. Ability: #ability.at(id-of(casting-ability)).name.],
  )
}

// - Choose a spell list, a casting ability (Int/Wis/Cha), two cantrips, and one 1st-level spell.
// - The feat grants one spellcasting source.
// - `eff-spell-any-slot` projects the 1st-level spell into every other spellcasting source (resolve.typ).
#let magic-initiate(spell-list, casting-ability: ability.int, cantrips: (), spell: none) = {
  let ab = id-of(casting-ability)
  assert(
    ("int", "wis", "cha").contains(ab),
    message: "Magic Initiate spellcasting ability must be Int, Wis, or Cha",
  )
  assert(
    cantrips.len() == 2,
    message: "Magic Initiate grants exactly 2 cantrips; got " + str(cantrips.len()),
  )
  assert(spell != none, message: "Magic Initiate grants one 1st-level spell")

  let name = "Magic Initiate (" + spell-list + ")"
  // Markup, not a joined string: the spell names carry emphasis like every other spell name on the sheet.
  let desc = [Cantrips: #cantrips.map(c => emph(c.name)).join(", "). 1st-level spell: #emph(spell.name). Ability: #ability.at(ab).name.]
  feature(
    name,
    kind: "feat",
    source: "Origin Feat",
    desc: desc,
    effects: (
      // - The spell pins to its own base level.
      // - A free slotless cast cannot upcast, so `fixed-slot` must suppress the ▲/scaling prose.
      eff-spellcasting(name, casting-ability, cantrips: cantrips,
        spells: ((spell: spell, slot: spell.at("level", default: 1)),)),
      // The pool tracks the free once-per-Long-Rest cast of the granted spell.
      eff-limited-use(spell, 1, source: name),
      eff-spell-any-slot(spell, casting-ability, name),
    ),
  )
}
