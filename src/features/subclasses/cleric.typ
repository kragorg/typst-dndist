// Cleric subclasses (Domains).
#import "common.typ": sub-feature as _sub-feature, subclass as _subclass
#import "../../model.typ": eff-limited-use
#import "../spells.typ" as spell

// - The always-prepared spells ride as plain `spells:` fields on their granting sub-feature.
// - The class builder folds them into its Cleric spellcasting source (`_subclass-grants`, classes.typ).
// - Do not emit `eff-spellcasting` from a subclass: it duplicates the class spellcasting row.
// - Radiance of the Dawn expends a Channel Divinity use, thus it carries no pool of its own.
// - Its damage scales with the Cleric level and its DC with the context, so `desc` and `notes` are functions.
#let light = _subclass("Light Domain", level => {
  let fs = ()
  if level >= 3 {
    // The feature has no `desc:`: the spell table is its display surface.
    fs.push(_sub-feature(
      "Light Domain Spells", "Light Domain",
      spells: (
        spell.burning-hands, spell.faerie-fire,
        spell.scorching-ray, spell.see-invisibility,
      ),
    ))
    fs.push(_sub-feature(
      "Radiance of the Dawn", "Light Domain",
      activation: "Action",
      desc: ctx => [As a Magic Action, expend a use of your Channel Divinity to present your Holy Symbol and flash light in a 30-ft Emanation, dispelling any magical Darkness there. Each creature of your choice in it takes $2d 10 + #level$ Radiant damage on a failed Constitution saving throw (DC $#{8 + ctx.pb + ctx.ability-mods.wis}$), half as much on a success.],
      notes: ctx => [Expend a Channel Divinity use: dispel magical Darkness in a 30-ft Emanation and deal $2d 10 + #level$ Radiant on a failed CON $#{8 + ctx.pb + ctx.ability-mods.wis}$ save (half on a success).],
    ))
    fs.push(_sub-feature(
      "Warding Flare", "Light Domain",
      activation: "Reaction",
      effects: (eff-limited-use("Warding Flare", ctx => calc.max(1, ctx.ability-mods.wis), uses-label: "WIS mod", source: "Light Domain"),),
      desc: [When a creature you can see within 30 ft makes an attack roll, you can take a Reaction to impose Disadvantage on it, light flaring before the attack hits or misses.],
      notes: [Impose Disadvantage on the attack roll of a creature you can see within 30 ft.],
    ))
  }
  fs
})
