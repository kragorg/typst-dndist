// - Bard subclasses (Colleges).
// - An entry without a player choice is a value; an entry with one is a function.

#import "../../model.typ": eff-prof, eff-limited-use
#import "common.typ": sub-feature as _sub-feature, subclass as _subclass
#import "../spells.typ" as spell

// - College of Glamour (2024 rules).
// - Beguiling Magic's always-prepared spells are Bard spells, cast with Bard spellcasting.
// - They ride as a plain `spells:` field; the class builder folds them into its own source
//   (`_subclass-grants`, classes.typ).
// - Do not emit `eff-spellcasting` here: it duplicates the Bard source in the spellcasting header.
// - `spell-schools:` names the schools the rider triggers on.
// - The SPELLS table footnotes each matching spell (`spell-school-notes`, layout/common.typ).
#let glamour = _subclass("College of Glamour", level => {
  let fs = ()
  if level >= 3 {
    fs.push(_sub-feature(
      "Beguiling Magic", "College of Glamour",
      spells: (spell.charm-person, spell.mirror-image),
      effects: (eff-limited-use("Beguiling Magic", 1, source: "College of Glamour"),),
      desc: [You always have _Charm Person_ and _Mirror Image_ prepared. Once per Long Rest, immediately after you cast an Enchantment or Illusion spell with a slot, one creature you can see within 60 ft makes a Wisdom save or has the Charmed or Frightened condition (your choice) for 1 minute, repeating the save at the end of each of its turns. You can also restore this use by expending a Bardic Inspiration use.],
      spell-schools: ("Enchantment", "Illusion"),
    ))
    fs.push(_sub-feature(
      "Mantle of Inspiration", "College of Glamour",
      activation: "Bonus Action",
      desc: [As a Bonus Action, expend a use of Bardic Inspiration to grant up to your Charisma-modifier creatures within 60 ft Temporary HP equal to twice the die roll, and each can immediately use its Reaction to move up to its Speed without provoking Opportunity Attacks.],
      notes: [Expend a Bardic Inspiration use: allies within 60 ft gain THP ($2 times$ the die) and can use their Reaction to move up to their Speed without provoking Opportunity Attacks.],
    ))
  }
  fs
})

// - Bonus Proficiencies grants three skills of the player's choice.
// - The builder does not enforce the count.
#let lore(..skills) = _subclass("College of Lore", level => {
  let fs = ()
  if level >= 3 {
    fs.push(_sub-feature(
      "Bonus Proficiencies", "College of Lore",
      effects: skills.pos().map(s => eff-prof("skill", s)),
    ))
    fs.push(_sub-feature("Cutting Words", "College of Lore"))
  }
  fs
})
