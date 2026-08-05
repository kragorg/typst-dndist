// - Fixture: a level-5 Wizard with no `prepared-at`.
// - It exercises a flexible caster. Each spell shows at its own base level.
// - Magic Missile therefore shows at its base slot.
#import "@preview/dndist:1.0.0": *

#let ariel = character(
  name: "Ariel",
  abilities: (str: 8, dex: 14, con: 14, int: 17, wis: 12, cha: 10),
  features: (
    class.wizard(level: 5),
    item.studded-leather,
  ),
  effects: (
    eff-spellcasting(
      "Wizard", ability.int,
      cantrips: (spell.fire-bolt, spell.mage-hand, spell.light),
      spells: (
        spell.magic-missile,
        spell.detect-magic,
        spell.mage-armor,
        spell.shield,
        spell.suggestion,
        spell.phantasmal-force,
      ),
      slots: ("1": 4, "2": 3, "3": 2),
      kind: "class",
    ),
  ),
)

#sheet(ariel)
