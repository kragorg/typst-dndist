// - Fixture: a Fighter 1 / Druid 2 with two `long-short-regain` pools.
// - Second Wind and Wild Shape both carry a footnote marker on their row.
// - It exercises the dedup: the page foot shows the note one time only.
// - Compile: `nix develop -c typst compile tests/longshort-dedup.typ out.pdf`
// - Add `--input layout=letter` for the letter sheet.
#import "@preview/dndist:1.0.0": *

#let test = character(
  name: "Dedup Test",
  player: "fixture",
  abilities: (str: 13, dex: 12, con: 14, int: 10, wis: 15, cha: 8),
  features: (
    species.elf(lineage: "wood-elf", skill: skill.perception, casting-ability: ability.wis),
    class.fighter(level: 1, skills: (skill.athletics, skill.intimidation)),
    class.druid(level: 2, skills: (skill.insight, skill.nature),
      cantrips: (spell.produce-flame, spell.guidance),
      prepared: (spell.detect-magic, spell.entangle, spell.healing-word)),
    weapon.quarterstaff,
  ),
)

#sheet(test)
