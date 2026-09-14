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
// - Star Map folds Guidance + Guiding Bolt into the class spellcasting source
//   (never a second eff-spellcasting); the 3 free Guiding Bolts/Long Rest are
//   the pool, named by the spell object so the resource row italicizes.
// - Starry Form expends a Wild Shape use, so it carries no pool of its own
//   (the Circle Forms pattern).
#let circle-of-the-stars = _subclass("Circle of the Stars", level => {
  let fs = ()
  if level >= 3 {
    fs.push(_sub-feature(
      "Star Map", "Circle of the Stars",
      cantrips: (spell.guidance,),
      spells: (spell.guiding-bolt,),
      effects: (eff-limited-use(spell.guiding-bolt, 3, recharge: "long", source: "Circle of the Stars"),),
      desc: [You've created a star chart, a Tiny object usable as a Spellcasting Focus for your Druid spells. While holding it, you have _Guidance_ and _Guiding Bolt_ prepared, and can cast _Guiding Bolt_ without expending a spell slot $3$ times per Long Rest. If you lose the map, a 1-hour ceremony during a Short or Long Rest magically creates a replacement and destroys the previous map.],
      notes: [Cast _Guiding Bolt_ without a slot (3/Long Rest).],
    ))
    fs.push(_sub-feature(
      "Starry Form", "Circle of the Stars",
      activation: "Bonus Action",
      desc: [As a Bonus Action, expend a use of Wild Shape to take on a starry form rather than shape-shifting. Your body becomes luminous, shedding Bright Light in a 10-ft radius and Dim Light for a further 10 ft. The form lasts 10 minutes and ends early if you dismiss it (no action required), you have the Incapacitated condition, or you use this feature again. When you assume it, choose a constellation: *Archer* — when you activate this form and as a Bonus Action on your subsequent turns while it lasts, make one ranged spell attack against a creature within 60 ft, dealing $1d 8$ + your Wisdom modifier Radiant damage on a hit; *Chalice* — whenever you cast a spell using a spell slot that restores Hit Points, you or another creature within 30 ft regains $1d 8$ + your Wisdom modifier Hit Points; *Dragon* — when you make an Intelligence or Wisdom check or a Constitution save to maintain Concentration, treat a roll of 9 or lower on the $d 20$ as a 10.],
      notes: [Expend a Wild Shape use; Bright/Dim Light 10/10 ft; Archer / Chalice / Dragon.],
    ))
  }
  fs
})
