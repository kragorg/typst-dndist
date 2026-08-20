// - Species features.
// - A species gives speed and trait proficiencies.
// - Do not give ability bonuses here: in 5.5e they come from the background.
// - Import aliased: `#import "species.typ" as species`, then `species.human()`.
// - SRD 5.2.1 species: Dragonborn, Dwarf, Elf, Gnome, Goliath, Halfling,
//   Human, Orc, Tiefling. Tortle, Fairy, Bugbear, and Aasimar are non-SRD fan
//   restatements of the 2024 rulebooks.
//
// EVERY species is a function, including the ones that take no argument today.
// - This catalog is the one place where the value-vs-function convention costs more than it conveys.
// - Most 2024 species carry a lineage or ancestry choice, so a species modelled as a plain value turns into a function the moment it is modelled properly.
// - That conversion is a breaking API change: it forces a major version bump, and thus an edit to the `@preview/dndist:<version>` import of every consumer file.
// - An elf character must not break because someone modelled the dragonborn.
// - A uniform function shape makes each later addition a *named parameter with a default*, which is additive and breaks nothing.

#import "../model.typ": feature, eff-stat, eff-prof, eff-ac-formula, eff-unarmed, eff-spellcasting, eff-reach, eff-save-advantage, eff-sense, eff-resistance, eff-limited-use, id-of
#import "../data/abilities.typ": ability
#import "../data/skills.typ": skill as skills
#import "spells.typ" as spell

// Give the display name of a skill object or string id; fall back to the id.
#let _skill-name(s) = skills.at(id-of(s), default: (name: id-of(s))).name

#let _species(name, speed: 30, size: "Medium", profs: ()) = feature(
  name,
  kind: "species",
  source: "Species",
  size: size,
  creature-type: "Humanoid",
  effects: (eff-stat("speed", speed, kind: "set"),) + profs,
)

// Not yet modelled: speed, size, and creature type only.
// - Tiefling's Fiendish Legacy and Gnome's Gnomish Lineage are player choices; each arrives as a named parameter with a default, breaking nothing.
// - Dwarf has no character-creation choice, thus it keeps an empty signature even once its traits land.
#let dwarf() = _species("Dwarf")
#let tiefling() = _species("Tiefling")
#let gnome() = _species("Gnome", size: "Small")

// - Build a species trait: a `kind: "trait"` sub-feature.
// - Set the species as `source` and the display prose as `desc`.
// - Pass all other feature fields through as named arguments.
#let _trait(source, name, desc, ..rest) = feature(
  name, kind: "trait", source: source, desc: desc, ..rest.named(),
)

// - Human is a function: the player chooses the Skillful skill and the Versatile Origin feat.
// - Versatile nests the chosen feat, thus `flatten-features` collects its effects and the layouts tag it ORIGIN.
// - Resourceful grants Heroic Inspiration, which changes no computed stat and stays prose.
#let human(skill: "perception", origin-feat: none) = feature(
  "Human",
  kind: "species",
  source: "Species",
  size: "Medium",
  creature-type: "Humanoid",
  effects: (
    eff-stat("speed", 30, kind: "set"),
    eff-prof("skill", skill),
  ),
  features: (
    _trait("Human", "Resourceful", [You gain Heroic Inspiration whenever you finish a Long Rest.]),
    _trait("Human", "Skillful", [You have proficiency in the #_skill-name(skill) skill.]),
    _trait("Human", "Versatile", [You gain an Origin feat of your choice#if origin-feat != none [: #origin-feat.name].]),
  ) + if origin-feat != none { (origin-feat,) } else { () },
)

// Elven Lineage rows: the level-1 benefit, plus the level 3 and 5 spells.
// - Drow raises the Darkvision range; Wood Elf raises the Speed.
#let _elven-lineages = (
  "drow": (name: "Drow", cantrip: spell.dancing-lights, darkvision: "120 ft", speed: 30,
    level3: "Faerie Fire", level5: "Darkness"),
  "high-elf": (name: "High Elf", cantrip: spell.prestidigitation, darkvision: "60 ft", speed: 30,
    level3: "Detect Magic", level5: "Misty Step"),
  "wood-elf": (name: "Wood Elf", cantrip: spell.druidcraft, darkvision: "60 ft", speed: 35,
    level3: "Longstrider", level5: "Pass without Trace"),
)

// - `lineage` is required: it sets the cantrip, the Darkvision range and the Speed, so no default is defensible.
// - Keen Senses is a choice of Insight, Perception, or Survival.
// - Only the lineage's level-1 cantrip becomes an effect. The level 3 and 5 spells are gated on total character level, which a species builder cannot see (level lives on the class feature), so they stay prose — the Fairy Magic limitation.
// - Drow's Darkvision emits at 120 ft beside the base 60 ft: the resolver dedupes senses by name and keeps the longest range, so both traits' prose stays true.
#let elf(lineage: none, skill: skills.perception, casting-ability: ability.int) = {
  assert(lineage != none, message: "Elf needs a lineage: \"drow\", \"high-elf\", or \"wood-elf\"")
  let l = _elven-lineages.at(lineage, default: none)
  assert(l != none, message: "unknown Elven Lineage '" + lineage + "'; expected drow, high-elf, or wood-elf")
  feature(
    "Elf",
    kind: "species",
    source: "Species",
    size: "Medium",
    creature-type: "Humanoid",
    effects: (
      eff-stat("speed", l.speed, kind: "set"),
      eff-prof("skill", skill),
    ),
    features: (
      _trait("Elf", "Darkvision", [You have Darkvision with a range of 60 ft.],
        effects: (eff-sense("Darkvision", range: "60 ft", source: "Elf"),)),
      _trait("Elf", "Elven Lineage", [You are of the #l.name lineage. You know the #emph(l.cantrip.name) cantrip. At character level 3 you always have #emph(l.level3) prepared, and at level 5 #emph(l.level5). You can cast each once per Long Rest without a slot, or with any slot of the appropriate level. #ability.at(id-of(casting-ability)).name is your spellcasting ability for them.],
        effects: (eff-spellcasting("Elven Lineage", casting-ability, cantrips: (l.cantrip,)),)
          + if l.darkvision != "60 ft" { (eff-sense("Darkvision", range: l.darkvision, source: "Elven Lineage"),) } else { () }),
      _trait("Elf", "Fey Ancestry", [You have Advantage on saving throws you make to avoid or end the Charmed condition.],
        effects: (eff-save-advantage([to avoid or end the Charmed condition], source: "Fey Ancestry"),)),
      _trait("Elf", "Keen Senses", [You have proficiency in the #_skill-name(skill) skill.]),
      _trait("Elf", "Trance", [You do not need to sleep, and magic cannot put you to sleep. You can finish a Long Rest in 4 hours spent in a trancelike meditation, during which you retain consciousness.]),
    ),
  )
}

// Draconic Ancestry: the dragon kind sets the Breath Weapon damage type and the Damage Resistance.
#let _draconic-ancestries = (
  "black": "Acid", "blue": "Lightning", "brass": "Fire", "bronze": "Lightning",
  "copper": "Acid", "gold": "Fire", "green": "Poison", "red": "Fire",
  "silver": "Cold", "white": "Cold",
)

// - `ancestry` is required: it sets both the Breath Weapon damage type and the Damage Resistance.
// - Breath Weapon replaces one attack of the Attack action, thus it carries no `activation` and routes to the card's OTHER table — the Cunning Strike reasoning.
// - Its dice scale on total character level and its save DC is Constitution-based, so `desc` and `notes` are functions of the computed context.
// - Draconic Flight is gated on character level 5, which a species builder cannot see, so it stays prose and emits no pool — the Fairy Magic limitation.
#let dragonborn(ancestry: none) = {
  assert(ancestry != none, message: "Dragonborn needs a draconic ancestry, e.g. \"red\"")
  let dmg = _draconic-ancestries.at(ancestry, default: none)
  assert(dmg != none, message: "unknown draconic ancestry '" + ancestry + "'")
  let kind = upper(ancestry.first()) + ancestry.slice(1)
  let dice = ctx => if ctx.level >= 17 { 4 } else if ctx.level >= 11 { 3 } else if ctx.level >= 5 { 2 } else { 1 }
  feature(
    "Dragonborn",
    kind: "species",
    source: "Species",
    size: "Medium",
    creature-type: "Humanoid",
    effects: (eff-stat("speed", 30, kind: "set"),),
    features: (
      _trait("Dragonborn", "Draconic Ancestry", [Your lineage traces to a #kind dragon, which sets your Breath Weapon damage and your Damage Resistance to #dmg.]),
      _trait("Dragonborn", "Breath Weapon", ctx => {
        let dc = 8 + ctx.pb + ctx.ability-mods.con
        [When you take the Attack action, you can replace one attack with an exhalation in a 15-ft Cone or a 30-ft Line 5 ft wide. Each creature in the area makes a Dexterity save (DC #dc), taking $#{str(dice(ctx))}d 10$ #dmg damage on a failure and half as much on a success. #ctx.pb uses; regained on a Long Rest.]
      },
        effects: (eff-limited-use("Breath Weapon", ctx => ctx.pb, uses-label: "PB", source: "Dragonborn"),),
        notes: ctx => [Replace one attack: 15-ft Cone or 30-ft Line, DEX $#{8 + ctx.pb + ctx.ability-mods.con}$ save, $#{str(dice(ctx))}d 10$ #dmg (half on a success) (#ctx.pb/Long Rest).]),
      _trait("Dragonborn", "Damage Resistance", [You have Resistance to #dmg damage.],
        effects: (eff-resistance(dmg, source: "Dragonborn"),)),
      _trait("Dragonborn", "Darkvision", [You have Darkvision with a range of 60 ft.],
        effects: (eff-sense("Darkvision", range: "60 ft", source: "Dragonborn"),)),
      _trait("Dragonborn", "Draconic Flight", [At character level 5, as a Bonus Action, you sprout spectral wings for 10 minutes, gaining a Fly Speed equal to your Speed. The wings vanish early if you retract them (no action required) or have the Incapacitated condition. Once per Long Rest.]),
    ),
  )
}

#let orc() = feature(
  "Orc",
  kind: "species",
  source: "Species",
  size: "Medium",
  creature-type: "Humanoid",
  effects: (
    eff-stat("speed", 30, kind: "set"),
  ),
  features: (
    _trait("Orc", "Adrenaline Rush", [As a Bonus Action, take the Dash action, gaining Temporary HP equal to your Proficiency Bonus. Proficiency Bonus uses; regained on a Short or Long Rest.],
      effects: (eff-limited-use("Adrenaline Rush", ctx => ctx.pb, uses-label: "PB", recharge: "short-or-long", source: "Orc"),),
      activation: "Bonus Action",
      notes: ctx => [Take the Dash action; gain #ctx.pb THP (#ctx.pb/Short or Long Rest).]),
    _trait("Orc", "Darkvision", [You have Darkvision with a range of 120 ft.],
      effects: (eff-sense("Darkvision", range: "120 ft", source: "Orc"),)),
    _trait("Orc", "Relentless Endurance", [Once per Long Rest, when reduced to 0 HP but not killed outright, you drop to 1 HP instead.],
      effects: (eff-limited-use("Relentless Endurance", 1, source: "Orc"),)),
  ),
)

// - Brave is a conditional save advantage, thus the layouts badge it in the
//   Defenses & Senses footnote. A `notes` row would repeat it.
// - The other three traits are display-only affordances that apply in combat,
//   thus each carries terse `notes` for the OTHER table.
#let halfling() = feature(
  "Halfling",
  kind: "species",
  source: "Species",
  size: "Small",
  creature-type: "Humanoid",
  effects: (
    eff-stat("speed", 30, kind: "set"),
  ),
  features: (
    _trait("Halfling", "Brave", [You have Advantage on saving throws you make to avoid or end the Frightened condition.],
      effects: (eff-save-advantage([to avoid or end the Frightened condition], source: "Brave"),)),
    _trait("Halfling", "Halfling Nimbleness", [You can move through the space of any creature that is a size larger than you, but you cannot stop in the same space.],
      notes: [Move through the space of a larger creature, no stopping.]),
    _trait("Halfling", "Luck", [When you roll a 1 on the $d 20$ of a D20 Test, you can reroll the die, and you must use the new roll.],
      notes: [Reroll a $1$ on any D20 Test; keep the new roll.]),
    _trait("Halfling", "Naturally Stealthy", [You can take the Hide action even when you are obscured only by a creature that is at least one size larger than you.],
      notes: [Hide action while obscured by a larger creature.]),
  ),
)

// - Tortle is a function: the player chooses the size and the Nature’s
//   Intuition skill.
// - Natural Armor is a fixed base-17 AC formula with no abilities. Dex does
//   not apply.
// - A shield bonus still stacks on the natural armor base.
// - Shell Defense splits into a parent and a child feature: the two halves
//   have different activation costs.
#let tortle(size: "Small", skill: "perception") = feature(
  "Tortle",
  kind: "species",
  source: "Species",
  size: size,
  creature-type: "Humanoid",
  effects: (
    eff-stat("speed", 30, kind: "set"),
    eff-prof("skill", skill),
    eff-ac-formula(17, abilities: (), source: "Natural Armor"),
  ),
  features: (
    _trait("Tortle", "Claws", [Your claws are natural weapons. An unarmed strike with them deals $1d 6$ + your Strength modifier slashing damage, instead of the bludgeoning damage normal for an unarmed strike.],
      effects: (eff-unarmed(damage: "1d6", damage-type: "Slashing", source: "Claws"),)),
    _trait("Tortle", "Hold Breath", [You can hold your breath for up to 1 hour.]),
    _trait("Tortle", "Natural Armor", [Your shell gives a base AC of 17 (Dex doesn't apply). You can't wear armor, but a shield's bonus still applies.]),
    _trait("Tortle", "Nature’s Intuition", [You have proficiency in the #_skill-name(skill) skill.]),
    _trait("Tortle", "Shell Defense", [As an action, withdraw into your shell: $+4$ AC and advantage on Str and Con saves, but you are prone, speed 0, have disadvantage on Dex saves, and can't take reactions.],
      activation: "Action",
      notes: [$+4$ AC, Adv. Str/Con saves; Prone, Speed 0, Disadv. Dex saves, no Reactions.],
      features: (
        _trait("Tortle", "Emerge", [As a Bonus Action, emerge from your shell, ending the Shell Defense effect.],
          activation: "Bonus Action",
          notes: [End Shell Defense.]),
      )),
  ),
)

// - Fairy is a function: the player chooses the Fairy Magic ability
//   (Int/Wis/Cha).
// - Fairy Magic gives the Druidcraft cantrip.
// - The higher-level Faerie Fire and Enlarge/Reduce casts stay prose: they are
//   gated on total character level, which a species builder cannot see.
#let fairy(casting-ability: ability.cha) = feature(
  "Fairy",
  kind: "species",
  source: "Species",
  size: "Small",
  creature-type: "Fey",
  effects: (
    eff-stat("speed", 30, kind: "set"),
  ),
  features: (
    _trait("Fairy", "Fairy Magic", [You know the _Druidcraft_ cantrip. At 3rd level you can cast _Faerie Fire_, and at 5th level _Enlarge/Reduce_, once each per Long Rest without a slot (or with any slot of the appropriate level).],
      effects: (eff-spellcasting("Fairy Magic", casting-ability, cantrips: (spell.druidcraft,)),)),
    _trait("Fairy", "Flight", [Thanks to your wings you have a flying speed equal to your walking speed. You can't use it while wearing Medium or Heavy armor.]),
  ),
)

// - Light Bearer is Charisma-based: the player makes no ability choice.
// - Celestial Revelation computes its save DC and its extra damage from the
//   proficiency bonus, so `desc` and `notes` are functions of the context.
#let aasimar() = feature(
  "Aasimar",
  kind: "species",
  source: "Species",
  size: "Medium",
  creature-type: "Humanoid",
  effects: (
    eff-stat("speed", 30, kind: "set"),
  ),
  features: (
    _trait("Aasimar", "Celestial Resistance", [You have Resistance to Necrotic and Radiant damage.],
      effects: (
        eff-resistance("Necrotic", source: "Aasimar"),
        eff-resistance("Radiant", source: "Aasimar"),
      )),
    _trait("Aasimar", "Darkvision", [You have Darkvision with a range of 60 ft.],
      effects: (eff-sense("Darkvision", range: "60 ft", source: "Aasimar"),)),
    _trait("Aasimar", "Healing Hands", [As a Magic Action, touch a creature and roll a number of d4s equal to your Proficiency Bonus; it regains that many HP. Once per Long Rest.],
      effects: (eff-limited-use("Healing Hands", 1, source: "Aasimar"),),
      activation: "Action",
      notes: ctx => [Touch a creature; it regains $#{str(ctx.pb)}d 4$ HP (1/Long Rest).]),
    _trait("Aasimar", "Light Bearer", [You know the _Light_ cantrip. Charisma is your spellcasting ability for it.],
      effects: (eff-spellcasting("Light Bearer", ability.cha, cantrips: (spell.light,)),)),
    _trait("Aasimar", "Celestial Revelation", ctx => {
      let dc = 8 + ctx.pb + ctx.ability-mods.cha
      [Once per Long Rest, as a Bonus Action, transform for 1 minute using one revelation, gaining its benefit and dealing $+ #{ctx.pb}$ Radiant/Necrotic damage to one target once per turn on a hit. *Heavenly Wings*: gain a Fly Speed equal to your Speed. *Inner Radiance*: shed Bright Light (10 ft) and Dim Light (a further 10 ft); each creature within 10 ft takes $+ #{ctx.pb}$ Radiant damage at the end of your turn. *Necrotic Shroud*: each creature other than an ally within 10 ft must succeed on a Charisma save (DC #dc) or have the Frightened condition until the end of your next turn.]
    },
      effects: (eff-limited-use("Celestial Revelation", 1, source: "Aasimar"),),
      activation: "Bonus Action",
      notes: ctx => [Transform for 1 minute (Wings / Inner Radiance / Necrotic Shroud); damage $+ #{ctx.pb}$/turn (1/Long Rest).]),
  ),
)

// - Long-Limbed adds 5 ft of reach to melee attacks only.
// - Goblinoid, Powerful Build, and Surprise Attack are display-only traits.
#let bugbear() = feature(
  "Bugbear",
  kind: "species",
  source: "Species",
  size: "Medium",
  creature-type: "Humanoid",
  effects: (
    eff-stat("speed", 30, kind: "set"),
    eff-prof("skill", "stealth"), // Sneaky
  ),
  features: (
    _trait("Bugbear", "Darkvision", [You can see in dim light within 60 ft as if it were bright light, and in darkness as if it were dim light (colors as shades of gray).],
      effects: (eff-sense("Darkvision", range: "60 ft", source: "Bugbear"),)),
    _trait("Bugbear", "Goblinoid", [You count as a goblinoid for any prerequisite or effect that requires you to be a goblinoid.]),
    _trait("Bugbear", 
      "Fey Ancestry",
      [You have Advantage on saving throws you make to avoid or end the Charmed condition.],
      effects: (eff-save-advantage([to avoid or end the Charmed condition], source: "Fey Ancestry"),),
    ),
    _trait("Bugbear", 
      "Long-Limbed",
      [When you make a melee attack on your turn, your reach for it is 5 ft greater than normal.],
      effects: (eff-reach(5, source: "Long-Limbed"),),
      notes: [Reach additional $5$ ft.],
    ),
    _trait("Bugbear", "Powerful Build", [You count as one size larger when determining your carrying capacity and the weight you can push, drag, or lift.]),
    _trait("Bugbear", "Sneaky", [You are proficient in the Stealth skill. Without squeezing, you can move through and stop in a space large enough for a Small creature.]),
    _trait("Bugbear", "Surprise Attack", [If you hit a creature with an attack roll before it has taken a turn in the current combat, the target takes an extra $2d 6$ damage.],
      notes: [$+2d 6$ against creatures that have not yet taken a turn.]),
  ),
)
