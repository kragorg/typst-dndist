// Druid subclasses (Circles).
#import "common.typ": sub-feature as _sub-feature, subclass as _subclass
#import "../../model.typ": eff-limited-use
#import "../spells.typ" as spell

// - The always-prepared spells ride as plain `cantrips:`/`spells:` fields on their granting sub-feature.
// - The class builder folds them into its Druid spellcasting source (`_subclass-grants`, classes.typ).
// - Do not emit `eff-spellcasting` from a subclass: it duplicates the class spellcasting row.
// - Circle Forms carries no `activation`: it riders on Wild Shape rather than costing its own action.
// - Its three numbers scale with the Druid level, so `desc` and `notes` are functions of the context.
#let circle-of-the-moon = _subclass("Circle of the Moon", level => {
  let fs = ()
  if level >= 3 {
    let cr = calc.floor(level / 3)
    let thp = 3 * level
    fs.push(_sub-feature(
      "Circle Forms", "Circle of the Moon",
      desc: ctx => [When you assume a Wild Shape form, the maximum Challenge Rating for the form is #cr (your Druid level divided by 3, rounded down), your AC is $#{13 + ctx.ability-mods.wis}$ ($13$ + your Wisdom modifier) if that is higher than the Beast's, and you gain $#thp$ Temporary Hit Points ($3 times$ your Druid level).],
      notes: ctx => [Wild Shape up to CR $#cr$; AC $#{13 + ctx.ability-mods.wis}$ if higher than the Beast's; $#thp$ THP.],
    ))
    // The feature has no `desc:`: the spell table is its display surface.
    fs.push(_sub-feature(
      "Circle of the Moon Spells", "Circle of the Moon",
      cantrips: (spell.starry-wisp,),
      spells: (spell.cure-wounds, spell.moonbeam)
        + if level >= 5 { (spell.conjure-animals,) } else { () }
        + if level >= 7 { (spell.fount-of-moonlight,) } else { () }
        + if level >= 9 { (spell.mass-cure-wounds,) } else { () },
    ))
  }
  if level >= 6 {
    fs.push(_sub-feature(
      "Improved Circle Forms", "Circle of the Moon",
      desc: [*Lunar Radiance.* Each of your attacks in a Wild Shape form can deal Radiant damage instead of its normal type. *Increased Toughness.* You can add your Wisdom modifier to your Constitution saving throws.],
      notes: [In Wild Shape, attacks can deal Radiant damage; add your Wisdom modifier to CON saves.],
    ))
  }
  if level >= 10 {
    fs.push(_sub-feature(
      "Moonlight Step", "Circle of the Moon",
      desc: [As a Bonus Action, you teleport up to 30 ft to an unoccupied space you can see, and you have Advantage on your next attack roll this turn. You regain one expended use by expending a spell slot of level 2 or higher (no action required).],
      effects: (eff-limited-use("Moonlight Step", ctx => calc.max(1, ctx.ability-mods.wis), uses-label: "WIS mod", source: "Circle of the Moon"),),
      activation: "Bonus Action",
      notes: ctx => [Teleport up to 30 ft; Advantage on your next attack roll this turn (#calc.max(1, ctx.ability-mods.wis)/Long Rest).],
    ))
  }
  if level >= 14 {
    fs.push(_sub-feature(
      "Lunar Form", "Circle of the Moon",
      desc: [*Improved Lunar Radiance.* Once per turn in a Wild Shape form, one of your attacks deals an extra $2d 10$ Radiant damage on a hit. *Shared Moonlight.* When you use Moonlight Step, you can also teleport one willing creature within 10 ft of yourself to a space within 10 ft of your destination.],
      notes: [In Wild Shape, $+2d 10$ Radiant once per turn. Moonlight Step can also carry one willing creature.],
    ))
  }
  fs
})
