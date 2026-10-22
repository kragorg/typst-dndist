// - Wild Magic Sorcery: 2024 PHB Sorcerer subclass.
// - The subclass's in-play reference — the PHB's d100 Wild Magic Surge table —
//   is data (data/wild-magic-surge.typ), not prose: the card deck renders it on
//   its own card after the Spells card, keyed off a resolved class whose
//   `subclass` is "Wild Magic Sorcery" (see card.typ). The features below only
//   name the table.
// - Wild Magic Surge and Tides of Chaos carry `notes` but no `activation`, so
//   the card deck routes both to the OTHER table; Tides of Chaos also pools as
//   a Long Rest resource, with a `note` footnoting its slot-cast regain beside
//   the pool's tracker (see `_pool-note-mark`).

#import "../../model.typ": feature, limited-use-feature
#import "common.typ": sub-feature, subclass

#let wild-magic-sorcery = subclass("Wild Magic Sorcery", level => {
  let fs = ()
  if level >= 3 {
    fs.push(sub-feature(
      "Wild Magic Surge", "Wild Magic Sorcery",
      desc: [Your spellcasting can unleash surges of untamed magic. Once per turn, you can roll $1d 20$ immediately after you cast a Sorcerer spell with a spell slot. If you roll a 20, roll on the Wild Magic Surge table to create a magical effect. If the magical effect is a spell, it is too wild to be affected by your Metamagic.],
      notes: [After casting a Sorcerer spell with a slot, roll $1d 20$; on a 20, roll on the Wild Magic Surge table (1/turn).],
    ))
    fs.push(limited-use-feature(
      "Tides of Chaos", 1,
      kind: "subclass-feature", source: "Wild Magic Sorcery",
      note: [Regain one use by casting a Sorcerer spell with a spell slot; this roll is made on the Wild Magic Surge table.],
      desc: [You can manipulate chaos itself to give yourself Advantage on one D20 Test before you roll the d20. Once you do so, you must cast a Sorcerer spell with a spell slot or finish a Long Rest before you can use this feature again. If you do cast a Sorcerer spell with a spell slot before you finish a Long Rest, you automatically roll on the Wild Magic Surge table.],
      notes: [Advantage on one d20 Test; casting a Sorcerer spell with a slot afterward rolls on the Wild Magic Surge table.],
    ))
  }
  if level >= 6 {
    fs.push(sub-feature(
      "Bend Luck", "Wild Magic Sorcery",
      activation: "Reaction",
      desc: [You have the ability to twist fate using your wild magic. Immediately after another creature you can see rolls the d20 for a D20 Test, you can take a Reaction and spend 1 Sorcery Point to roll $1d 4$ and apply the number rolled as a bonus or penalty (your choice) to the d20 roll.],
      notes: [Spend 1 SP: apply $+1d 4$ or $-1d 4$ to a creature's d20 roll.],
    ))
  }
  if level >= 14 {
    fs.push(sub-feature(
      "Controlled Chaos", "Wild Magic Sorcery",
      desc: [You gain a modicum of control over the surges of your wild magic. Whenever you roll on the Wild Magic Surge table, you can roll twice and use either number.],
      notes: [On the Wild Magic Surge table, roll twice and use either number.],
    ))
  }
  if level >= 18 {
    fs.push(limited-use-feature(
      "Tamed Surge", 1,
      kind: "subclass-feature", source: "Wild Magic Sorcery",
      desc: [Immediately after you cast a Sorcerer spell with a spell slot, you can create an effect of your choice from the Wild Magic Surge table instead of rolling on that table. You can choose any effect in the table except for the final row, and if the chosen effect involves a roll, you must make it. Once you use this feature, you can't do so again until you finish a Long Rest.],
      notes: [Choose a Wild Magic Surge effect instead of rolling (not the final row).],
    ))
  }
  fs
})
