// - Fixture: the worked example character, a simplified Elara.
// - It exercises a level-4 Bard whose subclass grants always-prepared spells.
// - Compile: `nix develop -c typst compile tests/example.typ example.pdf`
#import "@preview/dndist:1.0.0": *

#let elara = character(
  name: "Elara Starglimmer",
  player: "Player One",
  alignment: "CG",
  abilities: (str: 9, dex: 15, con: 12, int: 10, wis: 10, cha: 16),
  features: (
    species.aasimar(),
    background.entertainer(ability.cha, ability.dex),
    class.bard(
      level: 4,
      subclass: subclass.bard.glamour,
      skills: (skill.deception, skill.persuasion),
      expertise: (skill.persuasion, skill.deception),
      // - The Glamour subclass supplies Charm Person and Mirror Image.
      // - Thus this character declares no chosen spells.
    ),
    item.studded-leather,
    item.shield,
  ),
)

#sheet(elara)
