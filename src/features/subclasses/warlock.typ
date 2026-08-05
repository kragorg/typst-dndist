// Warlock subclasses (Patrons).
#import "common.typ": sub-feature as _sub-feature, subclass as _subclass
#import "../../model.typ": eff-limited-use, eff-resistance
#import "../spells.typ" as spell

// - The always-prepared spells ride as plain `spells:` fields on their granting sub-features.
// - The class builder folds them into its Pact Magic source (`_subclass-grants`, classes.typ).
// - Do not emit `eff-spellcasting` from a subclass: it duplicates the class spellcasting row.
// - Psychic Spells' `spell-schools:` names the schools its rule text calls out.
// - The SPELLS table footnotes each matching spell (`spell-school-notes`, layout/common.typ).
#let great-old-one = _subclass("Great Old One", level => {
  let fs = ()
  if level >= 3 {
    fs.push(_sub-feature(
      "Awakened Mind", "Great Old One",
      desc: [Bonus Action: choose one creature within 30 ft. You and it can communicate telepathically while within a number of miles equal to your CHA modifier (min 1), for a number of minutes equal to your Warlock level, or until used on a new target.],
      activation: "Bonus Action",
      notes: ctx => [Telepathic link with one creature within 30 ft (shared language), #calc.max(1, ctx.ability-mods.cha) mi, #level min.],
    ))
    // - The Great Old One Spells table (2024 PHB): always prepared, cast with Pact Magic.
    // - The feature has no `desc:`: the spell table is its display surface.
    fs.push(_sub-feature(
      "Great Old One Spells", "Great Old One",
      spells: (
        spell.detect-thoughts, spell.dissonant-whispers,
        spell.phantasmal-force, spell.tashas-hideous-laughter,
      )
        + if level >= 5 { (spell.clairvoyance, spell.hunger-of-hadar) } else { () }
        + if level >= 7 { (spell.confusion, spell.summon-aberration) } else { () }
        + if level >= 9 { (spell.modify-memory, spell.telekinesis) } else { () },
    ))
    fs.push(_sub-feature(
      "Psychic Spells", "Great Old One",
      desc: [When you cast a Warlock spell dealing damage, you can change its damage type to Psychic. When you cast a Warlock Enchantment or Illusion spell, you can omit Verbal and Somatic components.],
      spell-schools: ("Enchantment", "Illusion"),
    ))
  }
  if level >= 6 {
    fs.push(_sub-feature(
      "Clairvoyant Combatant", "Great Old One",
      desc: [When you form a telepathic bond with Awakened Mind, force that creature to make a Wisdom save against your spell save DC. On a failure it has Disadvantage on attack rolls against you and you have Advantage against it for the bond's duration. Once per Short/Long Rest (or expend a Pact Magic slot, no action, to restore).],
      effects: (eff-limited-use("Clairvoyant Combatant", 1, recharge: "short-or-long", source: "Great Old One"),),
    ))
  }
  if level >= 10 {
    fs.push(_sub-feature(
      "Eldritch Hex", "Great Old One",
      spells: (spell.hex,),
      desc: [You always have the _Hex_ spell prepared. When you cast _Hex_ and choose an ability, the target also has Disadvantage on saving throws of that ability for the spell's duration.],
    ))
    fs.push(_sub-feature(
      "Thought Shield", "Great Old One",
      desc: [Your thoughts can't be read by telepathy or other means unless you allow it. You have Resistance to Psychic damage, and a creature that deals Psychic damage to you takes the same amount.],
      effects: (eff-resistance("Psychic", source: "Great Old One"),),
    ))
  }
  fs
})
