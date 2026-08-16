// A dndist character sheet.
//
// - This template is a complete level-10 multiclass character, not a blank form.
// - Delete the parts you do not need: this is easier than to find what exists.
// - It shows most of the DSL: two classes, a subclass, Eldritch Invocations, a
//   custom background with an origin feat, an ASI, magic armor, weapon mastery,
//   a magic item with a scoped spellcasting bonus, a spell list and a backstory.
// - Select the layout on the command line; the default is card (card, card-lg,
//   card-5x8 and letter are the four):
//     typst compile --root . main.typ sheet.pdf --input layout=card
//     typst compile --root . main.typ sheet-5x8.pdf --input layout=card-5x8
//     typst compile --root . main.typ letter.pdf --input layout=letter
//     typst watch --root . main.typ
// - Make the three fonts available: ETBembo, Montserrat, Euler Math.
// - Install them, or point TYPST_FONT_PATHS at a directory that holds them.
// - The layout is calibrated to these faces; see the project README.

#import "@preview/dndist:1.0.0": *

#let my-character = character(
  name: "Nameless One",
  player: "Player One",
  alignment: "NN", // LG NG CG LN NN CN LE NE CE
  // - Max HP is computed from the hit dice and Con (the 5.5e fixed rule).
  // - Give `max-hp: 74` only to replace it with a rolled total.
  abilities: (str: 10, dex: 12, con: 14, int: 8, wis: 12, cha: 16),
  features: (
    species.orc(),

    // - This is a one-off background.
    // - The catalog backgrounds — background.sage(...), background.criminal(...),
    //   background.entertainer(...) — take the same ability allocation.
    // - Each catalog background also checks the allocation against its own trio.
    background.custom(
      "Faction Agent",
      abilities: (ability.dex, ability.cha), // +2 to the first, +1 to the second
      skills: (skill.arcana, skill.stealth),
      languages: ("Undercommon",),
      origin-feat: feat.lucky,
    ),

    // - The declaration order is important: the first class is the starting class.
    // - The starting class grants the saving-throw proficiencies.
    // - The starting class grants the maximum-roll first hit die.
    class.fighter(
      level: 1,
      skills: (skill.persuasion, skill.perception),
      mastery: ("Battleaxe", "Rapier", "Warhammer"),
      fighting-style: "Defense",
    ),
    class.warlock(
      level: 9,
      subclass: subclass.warlock.great-old-one,
      saves: (), // empty: only the starting class grants save proficiencies
      cantrips: (spell.eldritch-blast, spell.mind-sliver, spell.true-strike),
      spells: (
        spell.cloud-of-daggers, spell.suggestion,
        spell.dispel-magic, spell.fly, spell.major-image, spell.remove-curse,
        spell.summon-fey,
        spell.banishment, spell.dimension-door,
        spell.synaptic-static,
      ),
      // The builder checks the count against the 2024 Warlock progression.
      invocations: (
        invocation.pact-of-the-tome(
          cantrips: (spell.guidance, spell.shape-water),
          spells: (spell.comprehend-languages, spell.detect-magic),
        ),
        invocation.agonizing-blast(spell.eldritch-blast),
        invocation.repelling-blast(spell.eldritch-blast),
        invocation.lessons-of-the-first-ones(feat.tough),
        invocation.eldritch-mind,
        invocation.one-with-shadows,
        invocation.visions-of-distant-realms,
      ),
    ),

    feat.telekinetic(ability.cha),
    asi(ability.cha, 2), // an Ability Score Improvement

    // - Gear declared as a feature is EQUIPPED: its effects are live.
    // - Put gear in carried(...) to move it to the pack: inert, INVENTORY.
    weapon.battleaxe,
    weapon.rapier,
    weapon.warhammer,
    weapon.dagger,
    item.magic-armor("half-plate", bonus: 1, name: "Do-Maru Half Plate +1"),
    item.shield,
    item.cloak-of-protection,
    item.rod-of-the-pact-keeper(2),
  ),
  // - Every character knows Common automatically.
  // - Select two more languages here.
  // - A feature that grants a language (Thieves' Cant, a background) adds to these.
  languages: ("Orc", "Draconic"),
  currency: "723 gp / 9 sp / 6 cp",
  // List unmodelled kit only: put a modelled item in `features` above.
  equipment: (
    "Traveler’s Clothes", "Potion of Healing (Greater) ×5", "Bedroll",
    "Caltrops ×20", "Crowbar", "Rations ×5", "Rope (50 ft)", "Tinderbox",
    "Waterskin", "Tinker’s Tools",
  ),
)[
  Backstory and personality go in this trailing content block — it accepts ordinary
  markup, so *emphasis*, lists, and inline math all work. Delete the block entirely
  for a character with no backstory and the sheet leaves the space blank for
  handwriting.

  - What they want.
  - What they fear.
  - Who they owe.
]

#sheet(my-character)
