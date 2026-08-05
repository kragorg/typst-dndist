#import "../../model.typ": feature, eff-prof, eff-ac-formula, eff-ac-bonus, eff-spellcasting, eff-extra-attack, eff-weapon-mastery
#import "../../data/abilities.typ": ability

// --- Shared class helper functions -----------------------------------------

#let _extra-attack(count, source) = feature(
  "Extra Attack",
  kind: "class-feature",
  source: source,
  effects: (eff-extra-attack(count),),
)

#let unarmored-defense(source, extra-ability) = feature(
  "Unarmored Defense",
  kind: "class-feature",
  source: source,
  effects: (eff-ac-formula(10, abilities: (ability.dex, extra-ability), source: "Unarmored Defense"),),
)

#let _fighting-styles = (
  "Defense": (
    effects: (eff-ac-bonus(1, source: "Defense"),),
    desc: [While you're wearing Light, Medium, or Heavy armor, you gain a $+1$ bonus to Armor Class.],
  ),
)

#let _fighting-style(name, source: "Fighter") = {
  let s = _fighting-styles.at(name, default: (effects: (), desc: [Fighting Style: #name.]))
  feature(
    "Fighting Style",
    kind: "class-feature", source: source,
    features: (feature(
      name,
      kind: "feat", source: "Fighting Style Feat",
      effects: s.effects, desc: s.desc,
    ),),
  )
}

// - Spell slot table for a full caster, levels 1 to 5.
// - A level above 5 uses the level-5 row.
#let _full-caster-slots(level) = {
  let rows = ((2,), (3,), (4, 2), (4, 3), (4, 3, 2))
  let r = if level <= rows.len() { rows.at(level - 1) } else { rows.last() }
  let d = (:)
  for (i, n) in r.enumerate() { d.insert(str(i + 1), n) }
  d
}

// - The sub-features a subclass grants at this class level.
// - A subclass's `features` is a function of the level; a plain list passes through.
// - A `none` or string subclass grants none.
#let _subclass-features(subclass, level) = {
  if type(subclass) != dictionary { return () }
  let f = subclass.at("features", default: ())
  if type(f) == function { f(level) } else { f }
}

// - Collects the always-prepared cantrips or spells of a subclass.
// - The class casts these spells, thus they fold into the class spellcasting source.
// - Do not let a subclass emit its own eff-spellcasting: it adds a duplicate row to the spellcasting header.
#let _subclass-grants(subclass, level, field) = {
  _subclass-features(subclass, level).map(s => s.at(field, default: ())).sum(default: ())
}

// - Builds the Spellcasting sub-feature of a caster class. It emits the class eff-spellcasting.
// - `name` and `prepared-at` support Pact Magic, which casts every spell at one slot level.
#let _spellcasting-feature(source, casting-ability, cantrips, spells, slots, name: "Spellcasting", prepared-at: none) = feature(
  name,
  kind: "class-feature",
  source: source,
  effects: (eff-spellcasting(
    source, casting-ability,
    cantrips: cantrips,
    spells: spells,
    slots: slots,
    kind: "class",
    prepared-at: prepared-at,
  ),),
)

// - The Spellcasting sub-feature of a full-caster class: the class's own spells plus the
//   subclass's always-prepared ones, over the shared full-caster slot table.
// - Folding `_subclass-grants` in here keeps a subclass's spells from being dropped by a
//   caller that folds only one of the two lists.
// - Pact Magic keeps its own `_spellcasting-feature` call: its slots, name, `prepared-at`
//   and invocation grants all differ.
#let _full-caster-feature(
  source,
  casting-ability,
  level,
  subclass,
  cantrips: (),
  spells: (),
) = _spellcasting-feature(
  source,
  casting-ability,
  cantrips + _subclass-grants(subclass, level, "cantrips"),
  spells + _subclass-grants(subclass, level, "spells"),
  _full-caster-slots(level),
)

#let _class(
  name,
  level,
  subclass: none,
  hit-die: "d8",
  saves: (),
  armor: (),
  weapons: (),
  tools: (),
  skills: (),
  expertise: (),
  mastery: (),
  features: (),
) = {
  let effects = ()
  effects += saves.map(s => eff-prof("save", s))
  effects += armor.map(a => eff-prof("armor", a))
  effects += weapons.map(w => eff-prof("weapon", w))
  effects += tools.map(t => eff-prof("tool", t))
  effects += skills.map(s => eff-prof("skill", s))
  effects += expertise.map(s => eff-prof("skill", s, level: "expertise"))
  
  let mastery-feature = if mastery.len() > 0 {
    let listed = if mastery.len() == 1 { mastery.at(0) } else if mastery.len() == 2 { mastery.join(" and ") } else { mastery.join(", ", last: ", and ") }
    (feature(
      "Weapon Mastery",
      kind: "class-feature", source: name,
      effects: (eff-weapon-mastery(..mastery),),
      desc: [You can use the mastery properties of the #listed. Whenever you finish a Long Rest, you can change one of those choices.],
    ),)
  } else { () }

  let sub-name = if type(subclass) == dictionary { subclass.name } else { subclass }
  let sub-features = _subclass-features(subclass, level)

  feature(
    name,
    kind: "class",
    source: name,
    subclass: sub-name,
    level: level,
    hit-die: hit-die,
    effects: effects,
    features: features + mastery-feature + sub-features,
  )
}
