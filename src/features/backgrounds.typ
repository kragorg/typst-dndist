// - A 5.5e background grants ability increases, two skills, a tool, and an origin feat.
// - The increases come from a fixed trio: +2/+1 across two, or +1/+1/+1 across all three.
// - Import aliased: `#import "backgrounds.typ" as background`, then `background.entertainer("cha", "dex")`.

#import "../model.typ": feature, eff-ability, eff-prof, id-of
#import "../data/abilities.typ": ability
#import "../data/skills.typ": skill
#import "../data/tools.typ": tool
#import "feats.typ" as feat

// - `allowed` is the background's fixed trio of abilities.
// - The chosen `abilities` are 2 or 3 objects or ids, and must be a subset of the trio.
#let _background(name, allowed, skills: (), tools: (), languages: (), origin-feat: none, abilities: ()) = {
  let allow = allowed.map(id-of)
  let chosen = abilities.map(id-of)
  assert(
    chosen.len() == 2 or chosen.len() == 3,
    message: name + " background: choose 2 abilities (+2/+1) or 3 (+1/+1/+1), got " + str(chosen.len()),
  )
  for a in chosen {
    assert(
      allow.contains(a),
      message: name + " background can only increase " + allow.join(", ") + "; got '" + a + "'",
    )
  }

  // Two chosen give +2/+1, with the +2 on the first; three chosen give +1/+1/+1.
  let ability-effects = if chosen.len() == 2 {
    (
      eff-ability(chosen.at(0), 2, kind: "background"),
      eff-ability(chosen.at(1), 1, kind: "background"),
    )
  } else {
    chosen.map(a => eff-ability(a, 1, kind: "background"))
  }

  feature(
    name,
    kind: "background",
    source: "Background",
    effects: ability-effects
      + skills.map(s => eff-prof("skill", s))
      + tools.map(t => eff-prof("tool", t))
      + languages.map(l => eff-prof("language", l)),
    features: if origin-feat != none { (origin-feat,) } else { () },
  )
}

// - Declares a homebrew or setting background used by one character.
// - `abilities` are the chosen increases: 2 for +2/+1, or 3 for +1/+1/+1.
// - There is no fixed trio to validate against.
// - A background used by more than one character must graduate to a catalog entry below.
// - `languages` is an escape hatch the catalog backgrounds lack: in 2024 rules,
//   languages are a character-creation step, so no standard background grants one.
// - A setting background that does grant a language declares it here.
#let custom(name, abilities: (), skills: (), tools: (), languages: (), origin-feat: none) = _background(
  name,
  abilities,
  skills: skills,
  tools: tools,
  languages: languages,
  origin-feat: origin-feat,
  abilities: abilities,
)

// The origin feat is Magic Initiate (Cleric); its cantrips and spell are the player's choices, thus the caller builds it.
#let acolyte(..abilities, origin-feat: none) = _background(
  "Acolyte",
  (ability.int, ability.wis, ability.cha),
  skills: (skill.insight, skill.religion),
  tools: (tool.calligraphers-supplies,),
  origin-feat: origin-feat,
  abilities: abilities.pos(),
)

#let entertainer(..abilities) = _background(
  "Entertainer",
  (ability.dex, ability.wis, ability.cha),
  skills: (skill.acrobatics, skill.performance),
  tools: (tool.musical-instrument,),
  origin-feat: feat.musician,
  abilities: abilities.pos(),
)

// Exandria setting background.
#let marked-wanderer(..abilities) = _background(
  "Marked Wanderer",
  (ability.dex, ability.con, ability.cha),
  skills: (skill.insight, skill.sleight-of-hand),
  tools: (tool.cooks-utensils, tool.tattooists-tools),
  origin-feat: feat.lucky,
  abilities: abilities.pos(),
)

// Feywild-genie origin background.
#let genie-touched(..abilities, origin-feat: none) = _background(
  "Genie Touched",
  (ability.dex, ability.con, ability.cha),
  skills: (skill.deception, skill.perception),
  tools: (tool.glassblowers-tools,),
  origin-feat: origin-feat,
  abilities: abilities.pos(),
)

#let farmer(..abilities) = _background(
  "Farmer",
  (ability.str, ability.con, ability.wis),
  skills: (skill.animal-handling, skill.nature),
  tools: (tool.carpenters-tools,),
  origin-feat: feat.tough,
  abilities: abilities.pos(),
)

#let criminal(..abilities) = _background(
  "Criminal",
  (ability.dex, ability.con, ability.int),
  skills: (skill.sleight-of-hand, skill.stealth),
  tools: (tool.thieves-tools,),
  origin-feat: feat.alert,
  abilities: abilities.pos(),
)

#let sage(..abilities, origin-feat: none) = _background(
  "Sage",
  (ability.con, ability.int, ability.wis),
  skills: (skill.arcana, skill.history),
  tools: (tool.calligraphers-supplies,),
  origin-feat: origin-feat,
  abilities: abilities.pos(),
)
