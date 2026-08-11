// - Item features: the full mundane armor table, shields, and magic items.
// - Import aliased: `#import "items.typ" as item`, then `item.shield`.
// - Armor and shields come from SRD 5.2.1. Each magic item cites its own
//   source; NOTICE records which entries are SRD and which are not.

#import "../model.typ": feature, limited-use-feature, eff-ac-base, eff-ac-bonus, eff-check-advantage, eff-prof, eff-save-bonus, eff-sense, eff-spellcasting-bonus
#import "../data/constants.typ": armor-table, armor-dex-cap
#import "../data/skills.typ": skill
// An item that casts a spell names it with `casts:`; the spell catalog owns the numbers. `spells.typ` reaches only model.typ and the ability data, so this does not cycle back.
#import "spells.typ" as spell

// Build an armor feature from the armor table by id.
#let _armor(id) = {
  let a = armor-table.at(id)
  feature(
    a.name,
    kind: "armor",
    source: "Armor",
    effects: (eff-ac-base(a.base, cap: armor-dex-cap.at(a.category), source: a.name),),
  )
}

// - Build a +N version of a table armor: raise the base AC by `bonus`.
// - Keep the base armor's Dex cap.
// - `name` overrides the display name. The default is "<Armor> +N".
// - Use `kind: "magic-item"` so the armor lists among the magic items.
#let magic-armor(base-id, bonus: 1, name: none) = {
  let a = armor-table.at(base-id)
  let label = if name != none { name } else { a.name + " +" + str(bonus) }
  feature(
    label,
    kind: "magic-item",
    source: "Armor",
    effects: (eff-ac-base(a.base + bonus, cap: armor-dex-cap.at(a.category), source: label),),
  )
}

// Light armor
#let padded = _armor("padded")
#let leather = _armor("leather")
#let studded-leather = _armor("studded-leather")

// Medium armor
#let hide = _armor("hide")
#let chain-shirt = _armor("chain-shirt")
#let scale-mail = _armor("scale-mail")
#let breastplate = _armor("breastplate")
#let half-plate = _armor("half-plate")

// Heavy armor
#let ring-mail = _armor("ring-mail")
#let chain-mail = _armor("chain-mail")
#let splint = _armor("splint")
#let plate = _armor("plate")

// Shields and worn magic items. Source: SRD 5.2.1 §Equipment — Armor, §Magic Items.
#let shield = feature(
  "Shield",
  kind: "shield",
  source: "Shield",
  effects: (eff-ac-bonus(2, source: "Shield"),),
)

#let ring-of-protection = feature(
  "Ring of Protection",
  kind: "magic-item",
  source: "Ring of Protection",
  effects: (eff-ac-bonus(1, source: "Ring of Protection"),),
)

// - The engine computes both halves.
// - The AC bonus stacks on the chosen AC base.
// - The save bonus folds into every saving throw.
#let cloak-of-protection = feature(
  "Cloak of Protection",
  kind: "magic-item",
  source: "Cloak of Protection",
  effects: (
    eff-ac-bonus(1, source: "Cloak of Protection"),
    eff-save-bonus(1, source: "Cloak of Protection"),
  ),
  desc: [While worn, you gain a $+1$ bonus to Armor Class and to all saving throws (requires Attunement).],
)

// - The bonus applies only to Warlock spells, so it scopes to the "Warlock"
//   spellcasting source by default.
// - A feat or species source keeps its own attack bonus and save DC.
// - The rod splits into a parent and a child feature: the parent holds the
//   passive bonus, the child holds the Magic Action and its limited-use pool.
#let rod-of-the-pact-keeper(bonus, source-name: "Warlock") = feature(
  "Rod of the Pact Keeper +" + str(bonus),
  kind: "magic-item",
  source: "Magic Item",
  effects: (eff-spellcasting-bonus(attack: bonus, dc: bonus, source-name: source-name),),
  desc: [While held, $+#bonus$ to spell attack rolls and to the spell save DCs of your Warlock spells (requires Attunement by a Warlock).],
  features: (
    limited-use-feature(
      "Regain Pact Slot", 1,
      kind: "magic-item",
      source: "Rod of the Pact Keeper",
      activation: "Action",
      desc: [As a Magic Action while holding the Rod of the Pact Keeper, regain one expended Pact Magic spell slot. Once per Long Rest.],
      notes: [Regain one expended pact slot using the Rod of the Pact Keeper (1/Long Rest).],
    ),
  ),
)

// - Source: DMG 2024, uncommon.
// - It is a Shield, thus it also carries the shield's own AC bonus.
// - The Perception advantage covers the whole skill: the layouts badge that skill row,
//   and the passive score rises by 5 (see resolve.typ).
// - Advantage on Initiative rolls is not modelled and stays prose.
#let sentinel-shield = feature(
  "Sentinel Shield",
  kind: "magic-item",
  source: "Magic Item",
  effects: (
    eff-ac-bonus(2, source: "Sentinel Shield"),
    eff-check-advantage(skill.perception, source: "Sentinel Shield"),
  ),
  desc: [While holding this Shield, emblazoned with the symbol of an eye, you have Advantage on Initiative rolls and on Wisdom (Perception) checks.],
)

// - Source: DMG, uncommon.
// - The resolver keeps the longest range when a species also grants Darkvision,
//   thus the "+60 ft on existing Darkvision" half stays prose.
#let goggles-of-night = feature(
  "Goggles of Night",
  kind: "magic-item",
  source: "Goggles of Night",
  effects: (eff-sense("Darkvision", range: "60 ft", source: "Goggles of Night"),),
  desc: [While wearing these dark lenses, you have Darkvision out to 60 ft. If you already have Darkvision, the goggles increase its range by 60 ft.],
)

// - The +2 AC applies only with no armor and no shield.
// - The resolver has no conditional gating, so declare this item only on an
//   unarmored character.
#let bracers-of-defense = feature(
  "Bracers of Defense",
  kind: "magic-item",
  source: "Bracers of Defense",
  effects: (eff-ac-bonus(2, source: "Bracers of Defense"),),
)

// - Source: DMG, uncommon.
// - Do not emit `eff-spellcasting`: a magic item is not a spellcasting source.
//   It has no spellcasting ability, save DC, or attack bonus, and a bogus row
//   would show in the spellcasting header. `casts:` is how an item names the
//   spell it casts without becoming one — the resolver projects it to the same
//   detail the spell tables use, and the Action table's note reads the dart
//   count, the range and the damage from there. So neither `desc` nor `notes`
//   restates a number that belongs to Magic Missile.
// - The activation puts the item in the card deck's Action table.
// - The charges show at maximum in the resource tracker.
// - `name` reskins the display, for example "Rod of Magic Missiles". The
//   resource pool follows the name.
#let wand-of-magic-missiles(name: "Wand of Magic Missiles") = limited-use-feature(
  name, 7,
  kind: "magic-item",
  source: "Magic Item",
  activation: "Action",
  casts: (spell: spell.magic-missile, slot: 1),
  desc: [7 charges, regaining $1d 6 + 1$ at dawn. As a Magic Action while holding it, expend up to 3 charges to cast _Magic Missile_ from it: 1 charge casts it at 1st level, and each additional charge raises the level by one. If you expend the last charge, roll a $d 20$; on a $1$, the wand crumbles to ashes and is destroyed.],
  notes: [Expend 1–3 charges, $+1$ level each.],
)

// - Source: PHB 2024 / DMG 2024.
// - The potion is consumed on use.
#let potion-of-healing = feature(
  "Potion of Healing",
  kind: "magic-item",
  source: "Potion",
  activation: "Bonus Action",
  desc: [As a Bonus Action, you can drink this potion or administer it to another creature within 5 feet. The creature regains $2d 4 + 2$ Hit Points.],
  notes: [Drink or administer to regain $2d 4 + 2$ HP.],
)

// - Source: DMG 2024, uncommon.
// - The Stealth advantage is a real effect: it covers the whole skill, so the layouts badge that skill row.
// - Silent movement changes no computed value and stays prose.
#let boots-of-elvenkind = feature(
  "Boots of Elvenkind",
  kind: "magic-item",
  source: "Magic Item",
  effects: (eff-check-advantage(skill.stealth, source: "Boots of Elvenkind"),),
  desc: [While you wear these boots, your steps make no sound, whatever surface you cross. You also have Advantage on Dexterity (Stealth) checks.],
)

// - Homebrew: the Helm of Comprehending Languages (DMG 2024, uncommon) as a ring with charges.
// - The 1-charge dawn refill is the `dawn` recharge kind, footnoted on the tracker row.
#let ring-of-comprehension = limited-use-feature(
  "Ring of Comprehension", 3,
  recharge: "dawn",
  kind: "magic-item",
  source: "Magic Item",
  activation: "Action",
  casts: spell.comprehend-languages,
  desc: [You can take a Magic Action and 1 charge to cast _Comprehend Languages_. The ring has 3 charges, regaining 1 at dawn.  If you expend the last charge, there is a 10% chance the ring ceases to function.],
  notes: [Expend 1 charge.],
)

// Source: DMG 2024.
#let wand-of-magic-detection = limited-use-feature(
  "Wand of Magic Detection", 3,
  kind: "magic-item",
  source: "Magic Item",
  activation: "Action",
  casts: spell.detect-magic,
  desc: [3 charges, regaining $1d 3$ at dawn. While holding it, you can take a Magic Action to expend 1 charge to cast _Detect Magic_ from it. If you expend the last charge, roll a $d 20$; on a $1$, the wand is destroyed.],
  notes: [Expend 1 charge.],
)

// - Source: DMG 2024 (not SRD), common wondrous item, requires Attunement.
// - 1 use per dawn: forgo the d20, treat the attack roll as a 10.
#let clockwork-amulet = limited-use-feature(
  "Clockwork Amulet", 1,
  recharge: "dawn",
  kind: "magic-item",
  source: "Magic Item",
  desc: [
    This copper amulet of interlocking gears, humming with Mechanus magic, emits faint ticking and whirring. When you make an attack roll while wearing the amulet, you can forgo rolling the $d 20$ to get a 10 on the die. Once used, this property can't be used again until the next dawn (requires Attunement).
  ],
  notes: [Forgo the d20; treat one attack roll as a 10. Recharges at dawn.],
)


