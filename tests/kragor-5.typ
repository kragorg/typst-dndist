// - Fixture: Kragor, a Warlock at level 5 with Thirsting Blade.
// - It exercises the two-beam Eldritch Blast and the two attacks of Extra Attack.
#import "@preview/dndist:1.0.0": *

#let kragor = character(
  name: "Kragor Grimstride",
  alignment: "NN",
  abilities: (str: 10, dex: 14, con: 13, int: 8, wis: 10, cha: 18),
  features: (
    species.orc(),
    background.marked-wanderer(ability.dex, ability.cha),
    class.warlock(
      level: 5,
      subclass: subclass.warlock.great-old-one,
      skills: (skill.arcana, skill.deception),
      cantrips: (spell.booming-blade, spell.eldritch-blast, spell.mind-sliver),
      // - The Great Old One subclass supplies the always-prepared spells.
      // - Declare only the chosen spells here.
      spells: (
        spell.armor-of-agathys, spell.detect-magic, spell.hex,
        spell.cloud-of-daggers, spell.suggestion,
      ),
      // The class level sets the number of invocations. The builder asserts it.
      invocations: (
        invocation.pact-of-the-blade,
        invocation.agonizing-blast(spell.eldritch-blast),
        invocation.thirsting-blade,
        invocation.fiendish-vigor,
        invocation.eldritch-mind,
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
