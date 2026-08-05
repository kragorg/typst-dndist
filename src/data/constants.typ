// - This file holds static D&D 5.5e reference data: languages, tools, alignments,
//   weapon mastery, and armor.
// - The numbers come from the System Reference Document 5.2.1, §Equipment — Armor
//   and §Equipment — Weapons (the mastery property names).
// - The document is available at https://www.dndbeyond.com/srd.

#let standard-languages = (
  "Common", "Common Sign Language", "Draconic", "Dwarvish", "Elvish",
  "Giant", "Gnomish", "Goblin", "Halfling", "Orc",
)

#let rare-languages = (
  "Abyssal", "Celestial", "Deep Speech", "Druidic", "Infernal",
  "Primordial", "Sylvan", "Thieves' Cant", "Undercommon",
)

// Write each tool name with a real ’ (U+2019): the layouts show the name as authored.
#let artisans-tools = (
  "Alchemist’s Supplies", "Brewer’s Supplies", "Calligrapher’s Supplies",
  "Carpenter’s Tools", "Cartographer’s Tools", "Cobbler’s Tools",
  "Cook’s Utensils", "Glassblower’s Tools", "Jeweler’s Tools",
  "Leatherworker’s Tools", "Mason’s Tools", "Painter’s Supplies",
  "Potter’s Tools", "Smith’s Tools", "Tattooist’s Tools", "Tinker’s Tools",
  "Weaver’s Tools", "Woodcarver’s Tools",
)

#let other-tools = (
  "Disguise Kit", "Forgery Kit", "Gaming Set", "Herbalism Kit",
  "Musical Instrument", "Navigator’s Tools", "Poisoner’s Kit", "Thieves’ Tools",
)

// Map each two-letter alignment code to its long name.
#let alignment-names = (
  LG: "Lawful Good", NG: "Neutral Good", CG: "Chaotic Good",
  LN: "Lawful Neutral", NN: "True Neutral", CN: "Chaotic Neutral",
  LE: "Lawful Evil", NE: "Neutral Evil", CE: "Chaotic Evil",
)

// - A weapon lists its mastery property among its `properties`.
// - The resolver shows the property on an attack line only when the character has
//   trained mastery with that weapon (see `eff-weapon-mastery`).
#let weapon-mastery-names = ("Cleave", "Graze", "Nick", "Push", "Sap", "Slow", "Topple", "Vex")

// - The MASTERY table on the Actions card shows one row per trained mastery property.
// - The row prose stays terse: the player reads the rider next to the attack table.
// - Write the prose as markup content `[…]`, with dice and numbers as inline math.
// - Topple's save DC changes with the character: $8 +$ PB $+$ the weapon's ability
//   mod, without any magic bonus.
// - Topple is thus a function of the DC. The MASTERY-table builder in `card.typ`
//   computes the DC and calls it.
#let weapon-mastery-descriptions = (
  Cleave: [Melee attack a second creature within $5$ ft of the first; on a hit it takes the weapon's damage (no ability mod). Once per turn.],
  Graze: [On a miss, deal damage equal to your ability modifier.],
  Nick: [Light weapon extra attack becomes part of the Attack action.],
  Push: [Push a Large or smaller creature up to $10$ ft away on a hit.],
  Sap: [Target has Disadvantage on its next attack roll before the start of your next turn.],
  Slow: [Reduce the target's Speed by $10$ ft until the start of your next turn.],
  Topple: dc => [On a hit, target makes a CON save (DC #dc) or has the Prone condition.],
  Vex: [Advantage on your next attack roll against that creature before EoYN.],
)

// Maximum Dex contribution by armor category; none = no limit.
#let armor-dex-cap = (light: none, medium: 2, heavy: 0)

// `base` includes the "10 +": the rules show studded leather as "12 + Dex".
#let armor-table = (
  "padded": (name: "Padded", category: "light", base: 11),
  "leather": (name: "Leather", category: "light", base: 11),
  "studded-leather": (name: "Studded Leather", category: "light", base: 12),
  "hide": (name: "Hide", category: "medium", base: 12),
  "chain-shirt": (name: "Chain Shirt", category: "medium", base: 13),
  "scale-mail": (name: "Scale Mail", category: "medium", base: 14),
  "breastplate": (name: "Breastplate", category: "medium", base: 14),
  "half-plate": (name: "Half Plate", category: "medium", base: 15),
  "ring-mail": (name: "Ring Mail", category: "heavy", base: 14),
  "chain-mail": (name: "Chain Mail", category: "heavy", base: 16),
  "splint": (name: "Splint", category: "heavy", base: 17),
  "plate": (name: "Plate", category: "heavy", base: 18),
)
