// - Fixture: a Fighter 1 / Wizard 9 (Evoker) multiclass.
// - It exercises the per-class rows in the letter-sheet identity box.
// - Each row shows its own class level and subclass.
// - Compile: `nix develop -c typst compile tests/multiclass.typ out.pdf`
#import "@preview/dndist:1.0.0": *

#let valda = character(
  name: "Valda Ironscript",
  alignment: "LN",
  abilities: (str: 14, dex: 12, con: 14, int: 16, wis: 10, cha: 8),
  features: (
    species.human(),
    background.entertainer(ability.dex, ability.cha),
    class.fighter(level: 1, skills: (skill.athletics, skill.intimidation), mastery: ("Dagger",)),
    class.wizard(level: 9, subclass: "Evoker", skills: (skill.arcana, skill.investigation)),
    weapon.dagger,
  ),
)

// Select the layout with `--input layout=card|letter`. Card is the default.
#sheet(valda)
