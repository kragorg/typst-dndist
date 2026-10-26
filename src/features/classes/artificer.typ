#import "../../model.typ": feature, limited-use-feature
#import "../../data/abilities.typ": ability
#import "../../data/tools.typ": tool
#import "../spells.typ" as spell

#import "common.typ": _class, _spellcasting-feature, _subclass-grants

// - Artificer spell slots (Eberron: Forge of the Artificer).
// - A half caster that rounds up: level 1 already has two 1st-level slots.
#let _artificer-slots(level) = {
  let rows = (
    (2,), (2,), (3,), (3,), (4, 2), (4, 2), (4, 3), (4, 3),
    (4, 3, 2), (4, 3, 2), (4, 3, 3), (4, 3, 3), (4, 3, 3, 1), (4, 3, 3, 1),
    (4, 3, 3, 2), (4, 3, 3, 2), (4, 3, 3, 3, 1), (4, 3, 3, 3, 1),
    (4, 3, 3, 3, 2), (4, 3, 3, 3, 2),
  )
  let d = (:)
  for (i, n) in rows.at(calc.clamp(level, 1, 20) - 1).enumerate() { d.insert(str(i + 1), n) }
  d
}

// - Tinker's Magic: Artificer level 1.
// - It grants Mending; the cantrip folds into the class spellcasting source.
#let _tinkers-magic = limited-use-feature(
  "Tinker’s Magic",
  ctx => calc.max(1, ctx.ability-mods.int),
  uses-label: "INT mod",
  kind: "class-feature",
  source: "Artificer",
  activation: "Action",
  desc: [You know the _Mending_ cantrip. As a Magic action while holding Tinker’s Tools, create one item in an unoccupied space within 5 ft: Ball Bearings, Basket, Bedroll, Bell, Blanket, Block and Tackle, Glass Bottle, Bucket, Caltrops, Candle, Crowbar, Flask, Grappling Hook, Hunting Trap, Jug, Lamp, Manacles, Net, Oil, Paper, Parchment, Pole, Pouch, Rope, Sack, Shovel, Iron Spikes, String, Tinderbox, Torch, or Vial. The item vanishes when you finish a Long Rest.],
  notes: [Create a mundane item (e.g. Rope, Crowbar, Caltrops, Torch) within 5 ft; it lasts until a Long Rest. Needs Tinker’s Tools.],
)

// - Artificer: an Intelligence half caster (rounding up).
// - `artisan-tool` is the Artisan's Tools of the player's choice, on top of
//   Thieves' Tools and Tinker's Tools.
// - Modelled through level 1: Replicate Magic Item (L2) and later features are
//   not in the catalog yet.
#let artificer(level: 1, subclass: none, skills: (), artisan-tool: none, cantrips: (), spells: ()) = _class(
  "Artificer", level, subclass: subclass, hit-die: "d8",
  saves: ("con", "int"), armor: ("light", "medium", "shield"),
  weapons: ("simple",),
  tools: (tool.thieves-tools, tool.tinkers-tools)
    + if artisan-tool != none { (artisan-tool,) } else { () },
  skills: skills,
  features: (
    _spellcasting-feature(
      "Artificer", ability.int,
      (spell.mending,) + cantrips + _subclass-grants(subclass, level, "cantrips"),
      spells + _subclass-grants(subclass, level, "spells"),
      _artificer-slots(level),
    ),
    _tinkers-magic,
  ),
)
