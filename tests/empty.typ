// - Copy this file. Fill in your character.
// - Compile it with the dndist fonts available. See the README.
// - Select the layout with `--input layout=card|letter`. Card is the default.
#import "@preview/dndist:1.0.0": *

#let my-character = character(
  name: "Name Here",
  alignment: "NN",        // LG NG CG LN NN CN LE NE CE
  background: "Acolyte",
  // - The resolver computes max HP.
  // - Give `max-hp:` only for rolled HP.
  abilities: (str: 10, dex: 10, con: 10, int: 10, wis: 10, cha: 10),
  features: (
    // Skillful picks one skill; Versatile picks one Origin feat.
    species.human(skill: skill.perception, origin-feat: feat.lucky),
    class.fighter(level: 1, skills: ("athletics", "perception")),
    // item.chain-mail,
    // item.shield,
    // spell.mage-armor,
  ),
  // languages: ("Elvish",),      // Your two chosen languages. Common is automatic.
  // tools: (tool.gaming-set,),   // Your extra tool proficiencies.
)

#sheet(my-character)
