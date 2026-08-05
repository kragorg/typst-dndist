// - Fixture: a Sage-background wizard.
// - It exercises the Magic Initiate origin feat and the first slice of spellcasting.
// - Compile: `nix develop -c typst compile tests/sage.typ sage.pdf`
#import "@preview/dndist:1.0.0": *

#let mira = character(
  name: "Mira Quillsworth",
  alignment: "NG",
  abilities: (str: 8, dex: 14, con: 13, int: 14, wis: 12, cha: 10),
  features: (
    species.human(),
    background.sage(
      ability.int, ability.con,
      origin-feat: feat.magic-initiate(
        "Wizard",
        cantrips: (spell.fire-bolt, spell.mage-hand),
        spell: spell.detect-magic,
      ),
    ),
    class.wizard(level: 1, skills: (skill.investigation, skill.insight)),
  ),
)

#sheet(mira)
