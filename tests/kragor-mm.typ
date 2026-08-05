// - Fixture: Kragor, a Warlock at level 4 who knows Magic Missile.
// - It exercises a spell cast at a fixed pact slot above its base level.
// - `class.warlock` derives `prepared-at: 2`, so the dart count follows.
#import "@preview/dndist:1.0.0": *

#let kragor = character(
  name: "Kragor Grimstride",
  alignment: "NN",
  abilities: (str: 10, dex: 14, con: 13, int: 8, wis: 10, cha: 18),
  features: (
    species.orc(),
    background.marked-wanderer(ability.dex, ability.cha),
    class.warlock(
      level: 4,
      subclass: subclass.warlock.great-old-one,
      skills: (skill.arcana, skill.deception),
      cantrips: (spell.booming-blade, spell.eldritch-blast, spell.mind-sliver),
      // - The Great Old One subclass supplies the always-prepared spells.
      // - Declare only the chosen spells here.
      spells: (
        spell.armor-of-agathys, spell.detect-magic, spell.hex,
        spell.magic-missile, spell.suggestion,
      ),
      // The class level sets the number of invocations. The builder asserts it.
      invocations: (
        invocation.pact-of-the-blade,
        invocation.agonizing-blast(spell.eldritch-blast),
        invocation.fiendish-vigor,
      ),
    ),
    feat.telekinetic(ability.cha),
    magic-weapon(weapon.longsword, bonus: 1), // The pact weapon.
    weapon.crossbow-light,
    item.studded-leather,
  ),
  languages: ("Orc", "Dwarvish"),
)

#sheet(kragor)
