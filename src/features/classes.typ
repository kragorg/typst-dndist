// - Class catalog. Each class is a function of the level, and usually a subclass and chosen skills.
// - Each function returns a feature with the level, the hit die, the proficiencies, and named sub-features.
// - Import aliased: `#import "classes.typ" as class`, then `class.bard(level: 4, subclass: "College of Glamour")`.

#import "../model.typ": feature, limited-use-feature, eff-prof, eff-skill-rule, eff-ac-formula, eff-ac-bonus, eff-spellcasting, eff-skill-bonus, eff-weapon-mastery, eff-extra-attack, eff-cunning-strike, eff-limited-use
#import "../data/abilities.typ": ability
#import "../data/skills.typ": skill
#import "../data/tools.typ": tool
#import "spells.typ" as spell

#import "classes/common.typ": (
  _extra-attack, unarmored-defense, _fighting-style, _full-caster-feature,
  _subclass-grants, _spellcasting-feature, _class,
)
// - Primal Order is a Druid class choice, thus it stays on this namespace next to `class.druid(...)`.
// - Divine Order is the same shape for the Cleric.
// - Do not move either to a top-level `feature` namespace: that name shadows the public `feature()` constructor from model.typ.
#import "classes/cleric.typ": cleric, divine-order-thaumaturge, divine-order-protector
#import "classes/druid.typ": druid, primal-order-magician, primal-order-warden

// --- Named class features (objects that contribute effects) ----------------

#let jack-of-all-trades = feature(
  "Jack of All Trades",
  kind: "class-feature",
  source: "Bard",
  effects: (eff-skill-rule("jack-of-all-trades"),),
)

#let reliable-talent = feature(
  "Reliable Talent",
  kind: "class-feature",
  source: "Rogue",
  effects: (eff-skill-rule("reliable-talent"),),
)

// - Cunning Strike: 2024 Rogue, level 5.
// - The Rogue forgoes Sneak Attack dice to add a non-damage rider to a Sneak Attack hit.
// - One feature carries all three options. The player makes no choice, thus sub-features are not necessary.
// - Do not add a `desc`: the Cunning Strike table below the attack table shows these options.
#let cunning-strike = feature(
  "Cunning Strike",
  kind: "class-feature",
  source: "Rogue",
  effects: (
    eff-cunning-strike(
      "Poison",
      [Poisoned 1 min; needs a Poisoner's Kit.],
      save-ability: ability.con,
      source: "Rogue",
    ),
    eff-cunning-strike(
      "Trip",
      [Prone, if Large or smaller.],
      save-ability: ability.dex,
      source: "Rogue",
    ),
    eff-cunning-strike(
      "Withdraw",
      [Move half Speed, no Opportunity Attacks.],
      source: "Rogue",
    ),
  ),
)

// --- Classes ---------------------------------------------------------------

#let barbarian(level: 1, subclass: none, skills: (), mastery: ()) = _class(
  "Barbarian", level, subclass: subclass, hit-die: "d12",
  saves: ("str", "con"), armor: ("light", "medium", "shield"),
  weapons: ("simple", "martial"), skills: skills, mastery: mastery,
  features: (
    unarmored-defense("Barbarian", ability.con),
  ) + if level >= 5 { (_extra-attack(2, "Barbarian"),) } else { () },
)

// - Bard: a Charisma full caster.
// - Bardic Inspiration gives uses equal to the Charisma modifier, minimum 1.
// - Level 5 Font of Inspiration changes its recharge to a Short or Long Rest.
#let bard(level: 1, subclass: none, skills: (), expertise: (), cantrips: (), spells: ()) = _class(
  "Bard", level, subclass: subclass, hit-die: "d8",
  saves: ("dex", "cha"), armor: ("light",), weapons: ("simple",),
  tools: (tool.musical-instrument,), skills: skills, expertise: expertise,
  features: (
    _full-caster-feature("Bard", ability.cha, level, subclass, cantrips: cantrips, spells: spells),
    limited-use-feature(
      "Bardic Inspiration",
      ctx => calc.max(1, ctx.ability-mods.cha),
      uses-label: "CHA mod",
      recharge: if level >= 5 { "short-or-long" } else { "long" },
      kind: "class-feature",
      source: "Bard",
      activation: "Bonus Action",
      desc: [As a Bonus Action, inspire a creature within 60 ft that can see or hear you; it gains a Bardic Inspiration die ($1d 6$ at level 1) it can add to one failed d20 Test within the hour.],
      notes: [Give a creature within 60 ft a $1d 6$ Bardic Inspiration die (add to one d20 Test within 1 hour) (uses Bardic Inspiration).],
    ),
  ) + if level >= 2 { (jack-of-all-trades,) } else { () },
)

#let fighter(level: 1, subclass: none, skills: (), mastery: (), fighting-style: none) = _class(
  "Fighter", level, subclass: subclass, hit-die: "d10",
  saves: ("str", "con"), armor: ("light", "medium", "heavy", "shield"),
  weapons: ("simple", "martial"), skills: skills, mastery: mastery,
  features: (
    limited-use-feature(
      "Second Wind",
      if level >= 10 { 4 } else if level >= 4 { 3 } else { 2 },
      recharge: "long-short-regain",
      kind: "class-feature", source: "Fighter", activation: "Bonus Action",
      desc: [As a Bonus Action, draw on your stamina to regain $1d 10$ + your Fighter level in Hit Points.],
      notes: [Regain $1d 10 + #str(level)$ HP (uses Second Wind).],
    ),
  )
    + if fighting-style != none { (_fighting-style(fighting-style),) } else { () }
    + if level >= 5 {
      let count = if level >= 20 { 4 } else if level >= 11 { 3 } else { 2 }
      (_extra-attack(count, "Fighter"),)
    } else { () },
)

#let monk(level: 1, subclass: none, skills: ()) = _class(
  "Monk", level, subclass: subclass, hit-die: "d8",
  saves: ("str", "dex"), weapons: ("simple",), skills: skills,
  features: (
    unarmored-defense("Monk", ability.wis),
  ) + if level >= 5 { (_extra-attack(2, "Monk"),) } else { () },
)

// - Rogue: proficient with simple weapons, and with the martial Finesse or Light weapons.
// - Grant those martial weapons by name. The resolver then marks them proficient.
// - `language` is the extra language that Thieves' Cant lets the Rogue choose.
// - Omit `language` to keep that choice display-only.
#let rogue(level: 1, subclass: none, skills: (), expertise: (), mastery: (), language: none) = _class(
  "Rogue", level, subclass: subclass, hit-die: "d8",
  saves: ("dex", "int"), armor: ("light",),
  weapons: ("simple", "Hand Crossbow", "Rapier", "Scimitar", "Shortsword", "Whip"),
  tools: (tool.thieves-tools,),
  skills: skills, expertise: expertise, mastery: mastery,
  features: (
    feature(
      "Sneak Attack",
      kind: "class-feature",
      source: "Rogue",
      desc: [Once per turn, deal an extra $#{str(calc.ceil(level / 2))}d 6$ damage to one creature you hit with a Finesse or ranged weapon, if you have Advantage (or an ally is within 5 ft of the target, you don't have Disadvantage, and the ally isn't Incapacitated). Same type as the weapon.],
      notes: [$+#{str(calc.ceil(level / 2))}d 6$ once per turn if you have Advantage or an ally within 5 ft of the target.],
    ),
    feature(
      "Thieves’ Cant",
      kind: "class-feature",
      source: "Rogue",
      effects: (eff-prof("language", "Thieves' Cant"),)
        + if language != none { (eff-prof("language", language),) } else { () },
      desc: [You know Thieves' Cant, a secret mix of dialect, jargon, and code, plus one other language of your choice#if language != none [: #language].],
    ),
  )
    + if level >= 2 { (feature(
      "Cunning Action",
      kind: "class-feature",
      source: "Rogue",
      activation: "Bonus Action",
      desc: [As a Bonus Action, take the Dash, Disengage, or Hide action.],
      notes: [Dash, Disengage, or Hide.],
    ),) } else { () }
    + if level >= 3 { (feature(
      "Steady Aim",
      kind: "class-feature",
      source: "Rogue",
      activation: "Bonus Action",
      desc: [As a Bonus Action, give yourself Advantage on your next attack roll this turn, provided you haven't moved this turn. Your Speed is then 0 until the end of the turn.],
      notes: [Advantage on your next attack this turn if you haven't moved; Speed becomes $0$ until end of turn.],
    ),) } else { () }
    + if level >= 5 { (cunning-strike, feature(
      "Uncanny Dodge",
      kind: "class-feature",
      source: "Rogue",
      activation: "Reaction",
      desc: [When an attacker you can see hits you with an attack roll, you can take a Reaction to halve the attack's damage against you (round down).],
      notes: [Halve one attack's damage against you (round down).],
    ),) } else { () }
    + if level >= 7 { (reliable-talent,) } else { () },
)

#let wizard(level: 1, subclass: none, skills: ()) = _class(
  "Wizard", level, subclass: subclass, hit-die: "d6",
  saves: ("int", "wis"), weapons: ("simple",), skills: skills,
)

// Sorcerer: a Charisma full caster.
#let _metamagic-known(level) = if level >= 2 { 2 } else { 0 }

// - Font of Magic grants the Sorcery Points pool (a Long Rest resource) and the
//   ability to convert between spell slots and Sorcery Points. All three pieces
//   fold under the Font of Magic parent in the Features & Traits list.
// - Sorcery Points count equals the Sorcerer level.
#let _font-of-magic(level) = feature(
  "Font of Magic",
  kind: "class-feature",
  source: "Sorcerer",
  desc: [You tap into a wellspring of magic within yourself, represented by Sorcery Points. You have #level Sorcery Points and regain all expended points when you finish a Long Rest. You can also convert between spell slots and Sorcery Points.],
  features: (
    limited-use-feature(
      "Sorcery Points", level,
      recharge: "long",
      kind: "class-feature",
      source: "Sorcerer",
      desc: [You have #level Sorcery Points. You regain all expended Sorcery Points when you finish a Long Rest.],
    ),
    feature(
      "Convert Spell Slots",
      kind: "class-feature",
      source: "Sorcerer",
      notes: [Expend a spell slot, gain SP equal to its level. No action.],
      desc: [Expend a spell slot to gain a number of Sorcery Points equal to the slot's level. No action required.],
    ),
    feature(
      "Create Spell Slot",
      kind: "class-feature",
      source: "Sorcerer",
      activation: "Bonus Action",
      notes: [Transform 2 SP into a 1st-level spell slot; vanishes on Long Rest.],
      desc: [As a Bonus Action, transform unexpended Sorcery Points into a spell slot. The slot vanishes when you finish a Long Rest.],
    ),
  ),
)

#let sorcerer(level: 1, subclass: none, skills: (), cantrips: (), spells: (), metamagic: ()) = {
  let meta-known = _metamagic-known(level)
  assert(
    metamagic.len() == 0 or metamagic.len() == meta-known,
    message: "Sorcerer level " + str(level) + " knows " + str(meta-known)
      + " Metamagic option(s); got " + str(metamagic.len()),
  )
  _class(
    "Sorcerer", level, subclass: subclass, hit-die: "d6",
    saves: ("con", "cha"), weapons: ("simple",), skills: skills,
    features: (
      _full-caster-feature("Sorcerer", ability.cha, level, subclass, cantrips: cantrips, spells: spells),
      limited-use-feature(
        "Innate Sorcery", 2,
        kind: "class-feature",
        source: "Sorcerer",
        activation: "Bonus Action",
        desc: [Twice per Long Rest, as a Bonus Action, unleash your innate magic for 1 minute: your spell save DC increases by $1$ and you have Advantage on the attack rolls of your Sorcerer spells.],
        notes: [$+1$ to spell save DC; Advantage on Sorcerer spell attack rolls. 1 minute (2/Long Rest).],
      ),
    ) + if level >= 2 {
      (_font-of-magic(level), feature(
        "Metamagic",
        kind: "class-feature",
        source: "Sorcerer",
        desc: [You know #meta-known Metamagic options, which can be used to temporarily modify spells you cast.],
        features: metamagic,
      ),)
    } else { () },
  )
}

// - Warlock Pact Magic slot table.
// - All slots have the same level: half the character level, rounded up, with a maximum of 5th.
// - The count grows from 1 to 2, then to 3 at level 11.
#let _pact-slots(level) = {
  let spell-level = calc.min(5, int(calc.ceil(level / 2)))
  let count = if level >= 11 { 3 } else if level >= 2 { 2 } else { 1 }
  (str(spell-level): count)
}

// - Count of Eldritch Invocations a Warlock knows at a given level.
// - Source: 2024 PHB, Warlock Features table.
// - The count is 1 at level 1, then 3/5/6/7/8/9/10 across the higher tiers.
#let _invocations-known(level) = {
  if level >= 18 { 10 } else if level >= 15 { 9 } else if level >= 12 { 8 }
  else if level >= 9 { 7 } else if level >= 7 { 6 } else if level >= 5 { 5 }
  else if level >= 2 { 3 } else { 1 }
}

// - Warlock: a Charisma short-rest caster.
// - The Warlock knows all its spells. It does not prepare them.
// - `invocations` holds the chosen `invocation.*` objects. They nest under the Eldritch Invocations feature.
// - `saves` defaults to the single-class Warlock's Wisdom and Charisma.
// - Pass `saves: ()` when the Warlock is not the starting class: only the starting class grants saves.
#let warlock(level: 1, subclass: none, saves: ("wis", "cha"), skills: (), cantrips: (), spells: (), invocations: ()) = {
  let pact-slots = _pact-slots(level)
  // - The Warlock casts all pact spells at the same slot level.
  // - Take that level from the slot table, thus the per-spell damage display is correct.
  let pact-level = int(pact-slots.keys().first())
  // - Declared invocations must agree in count with the level progression.
  // - An empty list is also permitted, thus a focused test does not have to list the full set.
  let known = _invocations-known(level)
  assert(
    invocations.len() == 0 or invocations.len() == known,
    message: "Warlock level " + str(level) + " knows " + str(known)
      + " Eldritch Invocation(s); got " + str(invocations.len()),
  )
  // - Contact Patron: level 9.
  // - Contact Other Plane is always prepared, thus it folds into the class source.
  // - The Warlock also casts it free once per Long Rest, which is the pool on the Contact Patron feature.
  let contact-spells = if level >= 9 { (spell.contact-other-plane,) } else { () }
  // - An invocation grants its spells as plain `cantrips` and `spells` fields.
  // - The Warlock casts them with its own spellcasting, thus they fold into the Pact Magic source.
  // - Do not emit an eff-spellcasting per invocation: it adds a duplicate row to the spellcasting header.
  // - Pin each levelled spell to its own level: a ritual or a free cast has no slot to upcast with.
  let inv-cantrips = invocations.map(i => i.at("cantrips", default: ())).sum(default: ())
  let inv-spells = invocations
    .map(i => i.at("spells", default: ()))
    .sum(default: ())
    .map(s => (spell: s, slot: s.at("level", default: 1)))
  // Always-prepared subclass spells fold into the pact source in the same way. See `_subclass-grants`.
  let sub-cantrips = _subclass-grants(subclass, level, "cantrips")
  let sub-spells = _subclass-grants(subclass, level, "spells")
  _class(
    "Warlock", level, subclass: subclass, hit-die: "d8",
    saves: saves, armor: ("light",), weapons: ("simple",),
    skills: skills,
    features: (
      _spellcasting-feature("Warlock", ability.cha, cantrips + sub-cantrips + inv-cantrips,
        spells + sub-spells + contact-spells + inv-spells, pact-slots,
        name: "Pact Magic", prepared-at: pact-level),
      limited-use-feature(
        "Magical Cunning", 1,
        kind: "class-feature",
        source: "Warlock",
        desc: [Once per Long Rest, perform an esoteric rite for 1 minute to regain expended Pact Magic spell slots — up to half your maximum number of slots (rounded up).],
      ),
      // - Eldritch Invocations: level 1. The chosen invocations nest here and flatten into the trait list.
      // - Do not give the parent a `desc`: it must show no line of its own, only the invocations.
      feature(
        "Eldritch Invocations",
        kind: "class-feature",
        source: "Warlock",
        features: invocations,
      ),
    ) + if level >= 9 {
      (feature(
        "Contact Patron",
        kind: "class-feature",
        source: "Warlock",
        effects: (eff-limited-use(spell.contact-other-plane, 1, source: "Warlock"),),
        desc: [You always have _Contact Other Plane_ prepared, and can cast it without a spell slot once per Long Rest to contact your patron — automatically succeeding on the spell's saving throw.],
      ),)
    } else { () },
  )
}


