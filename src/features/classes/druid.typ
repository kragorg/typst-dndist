#import "../../model.typ": feature, limited-use-feature, eff-prof, eff-skill-bonus, eff-spellcasting
#import "../../data/abilities.typ": ability
#import "../../data/skills.typ": skill
#import "../../data/tools.typ": tool
#import "../spells.typ" as spell

#import "common.typ": _class, _full-caster-feature

#let primal-order-magician(cantrip) = feature(
  "Primal Order (Magician)",
  kind: "class-feature",
  source: "Druid",
  cantrips: (cantrip,),
  effects: (
    eff-skill-bonus(skill.arcana, ability: ability.wis, min-value: 1, source: "Primal Order"),
    eff-skill-bonus(skill.nature, ability: ability.wis, min-value: 1, source: "Primal Order"),
  ),
  desc: [Magician: you know one extra Druid cantrip, and add your Wisdom modifier (minimum $+1$) to Intelligence (Arcana) and Intelligence (Nature) checks.],
)

#let primal-order-warden = feature(
  "Primal Order (Warden)",
  kind: "class-feature",
  source: "Druid",
  effects: (
    eff-prof("armor", "medium"),
    eff-prof("weapon", "martial"),
  ),
  desc: [Warden: you gain proficiency with Medium armor and Martial weapons.],
)

// - Primal Order used when the character declares no choice.
// - This form grants no extra cantrip, because the character chose none.
#let default-magician = feature(
  "Primal Order (Magician)",
  kind: "class-feature",
  source: "Druid",
  effects: (
    eff-skill-bonus(skill.arcana, ability: ability.wis, min-value: 1, source: "Primal Order"),
    eff-skill-bonus(skill.nature, ability: ability.wis, min-value: 1, source: "Primal Order"),
  ),
  desc: [Magician: you know one extra Druid cantrip, and add your Wisdom modifier (minimum $+1$) to Intelligence (Arcana) and Intelligence (Nature) checks.],
)

#let get-primal-order-feature(po) = {
  if type(po) == dictionary {
    po
  } else if po == "warden" {
    primal-order-warden
  } else {
    default-magician
  }
}

// - Wild Shape: 2024 Druid, level 2.
// - The uses, the known form count, the Challenge Rating cap, and the Fly Speed permission scale with the level.
#let wild-shape(level) = {
  let uses = if level >= 17 { 4 } else if level >= 6 { 3 } else { 2 }
  let known = if level >= 8 { "eight" } else if level >= 4 { "six" } else { "four" }
  let cr = if level >= 8 { "1" } else if level >= 4 { "½" } else { "¼" }
  let fly = if level >= 8 { "forms may have a Fly Speed" } else { "forms can't have a Fly Speed" }
  let hours = calc.floor(level / 2)
  let hours-word = if hours == 1 { "hour" } else { "hours" }
  limited-use-feature(
    "Wild Shape",
    uses,
    recharge: "long-short-regain",
    kind: "class-feature",
    source: "Druid",
    activation: "Bonus Action",
    desc: [As a Bonus Action, shape-shift into a Beast form you know for this feature. You stay in that form for #hours #hours-word, or until you use Wild Shape again, have the Incapacitated condition, or die; you can also leave the form early as a Bonus Action. You know #known Beast forms (Challenge Rating #cr or lower); #fly. You can replace one known form on a Long Rest. While shape-shifted, you gain Temporary Hit Points equal to your Druid level, your game statistics are replaced by the Beast's (you retain your creature type; Hit Points; Hit Dice; Intelligence, Wisdom, and Charisma; class features; languages; and feats), and you can't cast spells.],
    notes: [Shape-shift into a known Beast form; gain $#level$ THP. Lasts #hours #hours-word (_B.Action_ to leave early) (uses Wild Shape).],
  )
}

// - Wild Companion: 2024 Druid, level 2.
// - It spends a spell slot or a Wild Shape use, thus it has no pool of its own.
#let wild-companion = feature(
  "Wild Companion",
  kind: "class-feature",
  source: "Druid",
  activation: "Action",
  desc: [As a Magic Action, expend a spell slot or a use of Wild Shape to cast the _Find Familiar_ spell without Material components. The familiar is Fey rather than a normal animal, and it disappears when you finish a Long Rest.],
  notes: [Cast _Find Familiar_ (no Material components) (uses Wild Shape or spell slot).],
)

#let druid(
  level: 1,
  subclass: none,
  skills: (),
  primal-order: "magician",
  cantrips: (),
  prepared: (),
) = {
  let po-feature = get-primal-order-feature(primal-order)
  let extra-cantrips = po-feature.at("cantrips", default: ())
  
  _class(
    "Druid", level, subclass: subclass, hit-die: "d8",
    saves: ("int", "wis"), armor: ("light", "shield"),
    weapons: ("simple",), tools: (tool.herbalism-kit,), skills: skills,
    features: (
      // Speak with Animals is always prepared, thus it joins the Druid's own list.
      _full-caster-feature("Druid", ability.wis, level, subclass,
        cantrips: cantrips + extra-cantrips,
        spells: prepared + (spell.speak-with-animals,)),
      feature(
        "Druidic",
        kind: "class-feature",
        source: "Druid",
        effects: (eff-prof("language", "Druidic"),),
        desc: [You know Druidic, the secret language of druids, and always have _Speak with Animals_ prepared.],
      ),
      po-feature,
    ) + if level >= 2 { (wild-shape(level), wild-companion,) } else { () },
  )
}
