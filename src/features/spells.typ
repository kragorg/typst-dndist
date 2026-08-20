// - A spell is an object with a name and a level.
// - A spell that carries effects also works as a feature: add it to a
//   character directly (Mage Armor changes AC).
// - A spell without effects is data: a feat or feature refers to it.
// - Import with an alias: `#import "spells.typ" as spell`, then `spell.fire-bolt`.
// - Write `notes`, `scaling` and `trigger` as markup content, not strings:
//   apostrophes curl, and dice and modifiers are math (`$+1d 6$`, `$+5$`).
// - Put a space in the die token (`1d 6`): Typst reads `d6` as one identifier.
// - Keep structured fields (name, damage tiers) as plain data.

#import "../model.typ": feature, eff-ac-formula, eff-ac-bonus
#import "../data/abilities.typ": ability

#let _spell(
  name,
  level,
  school: none,
  casting-time: none,
  range: none,
  area: none,
  components: none,
  duration: none,
  concentration: false,
  ritual: false,
  save: none,
  attack: false,
  weapon-attack: false,
  check: none,
  trigger: none,
  material-cost: false,
  notes: none,
  // - Write the per-slot upcast prose here, not in `notes`.
  // - The SPELLS table shows the prose after the duration, behind a ▲ mark.
  // - The card deck's terse notes show the ▲ mark alone (`_upcastable`).
  // - Do not show this prose for a fixed-slot cast (pact slots): with no slot
  //   choice the delta reads incoherently. The ▲ mark is also suppressed.
  // - `at-level` (below) gives the computed effect for a fixed-slot cast.
  // - A spell with no `at-level` falls back to this prose, bullet-joined.
  scaling: none,
  // - Give a function `lv => (…)` that returns field overrides at a slot level.
  // - The resolver calls it only for a fixed-slot upcast above the base level.
  // - Returned keys overlay the resolved detail: `scaling` prose, or the
  //   structured `duration`, `concentration` and `area` fields.
  // - Return `scaling: none` when the structured fields carry the effect.
  // - Mirrors the `(ctx) => …` pattern of `eff-limited-use`'s `uses`.
  // - Omit the field when the spell needs none of this.
  at-level: none,
  damage: none,
  slot-damage: none,
  damage-bonus-per: "flat",
  damage-per-label: none,
  damage-bonus: none,
  healing: none,
  effects: (),
) = {
  // - Every spell needs a casting time; a missing one is a data bug.
  // - Without it, the card deck's action-economy routing drops the spell.
  // - The `#let … = _spell(…)` defs are module-level, so this fires at import.
  assert(casting-time != none, message: "spell " + name + " has no casting-time")
  feature(
  name,
  kind: "spell",
  source: "Spell",
  level: level,
  school: school,
  casting-time: casting-time,
  range: range,
  area: area,
  components: components,
  duration: duration,
  concentration: concentration,
  ritual: ritual,
  save: save,
  attack: attack,
  weapon-attack: weapon-attack,
  check: check,
  trigger: trigger,
  material-cost: material-cost,
  notes: notes,
  scaling: scaling,
  at-level: at-level,
  damage: damage,
  slot-damage: slot-damage,
  damage-bonus-per: damage-bonus-per,
  damage-per-label: damage-per-label,
  damage-bonus: damage-bonus,
  healing: healing,
  effects: effects,
  )
}

// --- Cantrips (level 0) ----------------------------------------------------
#let fire-bolt = _spell(
  "Fire Bolt", 0, school: "Evocation",
  casting-time: "Action", range: "120 ft", attack: true,
  damage: ((1, 1, "d10", "Fire"), (5, 2, "d10", "Fire"), (11, 3, "d10", "Fire"), (17, 4, "d10", "Fire")),
)
// - The hand's leash equals its range, so the note says "that range": the Telekinetic feat raises both together.
#let mage-hand = _spell("Mage Hand", 0, school: "Conjuration",
  casting-time: "Action", range: "30 ft", components: "V, S",
  duration: "1 min",
  notes: [A spectral floating hand manipulates an object, opens an unlocked door or container, stows or retrieves an item, or pours out a vial. _Magic Action_: control it again, moving it up to 30 ft. Can't attack, activate magic items, or carry over 10 lb; vanishes if it leaves that range or you recast it.],
)
#let light = _spell(
  "Light", 0, school: "Evocation",
  casting-time: "Action", range: "Touch", components: "V, M",
  duration: "1 hr",
  notes: [Touched object sheds Bright Light 20 ft, Dim Light 40 ft more, choose color. Opaque cover blocks it; ends if recast.],
)
#let prestidigitation = _spell("Prestidigitation", 0, school: "Transmutation", casting-time: "Action")
#let dancing-lights = _spell(
  "Dancing Lights", 0, school: "Illusion",
  casting-time: "Action", range: "120 ft", components: "V, S, M",
  duration: "1 min", concentration: true,
  notes: [Create up to four torch-size lights, or one Medium humanoid-shaped light, each shedding Dim Light in a 10-ft radius. Move them up to 60 ft as a Bonus Action.],
)
#let ray-of-frost = _spell("Ray of Frost", 0, school: "Evocation", casting-time: "Action", attack: true)
// - To discern the illusion, the target makes an Investigation check, not a save.
// - Thus use `check`: it renders in DAMAGE/EFFECT with the resolved DC.
// - Do not put a check in HIT/SAVE: that column shows attacks and saves only.
#let minor-illusion = _spell(
  "Minor Illusion", 0, school: "Illusion",
  casting-time: "Action", range: "30 ft", area: (shape: "cube", size: "5 ft"),
  components: "S, M", duration: "1 min",
  check: [_Study_ (Investigation) to discern],
  notes: [Create a sound (whisper to scream) or the image of an object (5-ft cube, no other sensory effect).],
)
#let druidcraft = _spell(
  "Druidcraft", 0, school: "Transmutation",
  casting-time: "Action", range: "30 ft", components: "V, S",
  duration: "Instantaneous",
  notes: [A tiny nature effect: predict 24h weather, bloom a plant, a harmless sensory effect (5-ft cube), or light/snuff a small flame.],
)
#let thorn-whip = _spell(
  "Thorn Whip", 0, school: "Transmutation",
  casting-time: "Action", range: "30 ft", components: "V, S, M",
  duration: "Instantaneous", attack: true,
  damage: ((1, 1, "d6", "Piercing"), (5, 2, "d6", "Piercing"), (11, 3, "d6", "Piercing"), (17, 4, "d6", "Piercing")),
  notes: [Melee spell attack. On hit: pull Large or smaller target up to 10 ft closer.],
)
#let message = _spell(
  "Message", 0, school: "Transmutation",
  casting-time: "Action", range: "120 ft", components: "S, M",
  duration: "1 round",
  notes: [Whisper a message to one creature in range; only it hears, and it may whisper back. Travels around corners; blocked by lead or 1 ft of stone.],
)
#let sorcerous-burst = _spell(
  "Sorcerous Burst", 0, school: "Evocation",
  casting-time: "Action", range: "120 ft", components: "V, S",
  duration: "Instantaneous", attack: true,
  damage: ((1, 1, "d8", "Acid"), (5, 2, "d8", "Acid"), (11, 3, "d8", "Acid"), (17, 4, "d8", "Acid")),
  notes: [Damage type is your choice (Acid/Cold/Fire/Lightning/Poison/Psychic/Thunder). Roll an 8: add another d8, up to your spellcasting modifier.],
)

// --- Warlock cantrips ------------------------------------------------------
// - `weapon-attack: true`: the attack is a normal melee weapon attack.
// - The resolver makes one `via-spell` attack line per melee weapon, which
//   reuses the weapon's own hit and damage.
// - Thus the spell carries no damage tiers; the note gives the booming rider.
// - The rider does no guaranteed on-hit damage, so it stays out of Damage.
#let booming-blade = _spell(
  "Booming Blade", 0, school: "Evocation",
  casting-time: "Action", range: "Self (5 ft.)", components: "S, M",
  duration: "1 round", weapon-attack: true,
  notes: [Target sheathed in booming energy until SoYN; $1d 8$ Thunder if it moves 5+ ft (increased to $2d 8$, $3d 8$, $4d 8$ at levels 5, 11, 17). At level 5+, also takes one less damage die on the hit itself.],
)
#let eldritch-blast = _spell(
  "Eldritch Blast", 0, school: "Evocation",
  casting-time: "Action", range: "120 ft", components: "V, S",
  duration: "Instantaneous", attack: true,
  damage: ((1, 1, "1d10", "Force"), (5, 2, "1d10", "Force"), (11, 3, "1d10", "Force"), (17, 4, "1d10", "Force")),
  damage-bonus-per: "beam",
  notes: [Each beam is a separate attack roll.],
)

// --- 1st-level spells ------------------------------------------------------
#let detect-magic = _spell(
  "Detect Magic", 1, school: "Divination",
  casting-time: "Action", range: "Self", area: (shape: "sphere", size: "30 ft"),
  components: "V, S", duration: "10 min", concentration: true, ritual: true,
  notes: [Sense magic within 30 ft. _Magic Action_ to see auras and learn spell school. Blocked by 1 ft stone/dirt/wood, 1 in metal, or lead.],
)
#let expeditious-retreat = _spell(
  "Expeditious Retreat", 1, school: "Transmutation",
  casting-time: "Bonus Action", range: "Self", components: "V, S",
  duration: "10 min", concentration: true,
  notes: [You can take the Dash action on that turn. For the duration, you can take the Dash action as a Bonus Action.],
)
#let magic-missile = _spell(
  "Magic Missile", 1, school: "Evocation",
  casting-time: "Action", range: "120 ft", components: "V, S",
  duration: "Instantaneous",
  slot-damage: (
    (1, 3, "1d4+1", "Force"), (2, 4, "1d4+1", "Force"), (3, 5, "1d4+1", "Force"),
    (4, 6, "1d4+1", "Force"), (5, 7, "1d4+1", "Force"), (6, 8, "1d4+1", "Force"),
    (7, 9, "1d4+1", "Force"), (8, 10, "1d4+1", "Force"), (9, 11, "1d4+1", "Force"),
  ),
  damage-bonus-per: "beam", damage-per-label: "per dart",
  notes: [Auto-hit; no attack roll.],
  scaling: [$+1$ dart/slot above 1st.],
)
// - Source: Forgotten Realms: Heroes of Faerûn. Setting content, outside SRD 5.2.1.
#let spellfire-flare = _spell(
  "Spellfire Flare", 1, school: "Evocation",
  casting-time: "Action", range: "60 ft", components: "V, S",
  duration: "Instantaneous", attack: true,
  slot-damage: (
    (1, 1, "2d10", "Radiant"), (2, 2, "2d10", "Radiant"), (3, 3, "2d10", "Radiant"),
    (4, 4, "2d10", "Radiant"), (5, 5, "2d10", "Radiant"), (6, 6, "2d10", "Radiant"),
    (7, 7, "2d10", "Radiant"), (8, 8, "2d10", "Radiant"), (9, 9, "2d10", "Radiant"),
  ),
  damage-bonus-per: "beam", damage-per-label: "per blast",
  notes: [Target gains no benefit from Half or Three-Quarters Cover against this attack. Each blast is a separate attack roll.],
  scaling: [$+1$ blast/slot above 1st.],
)
#let feather-fall = _spell(
  "Feather Fall", 1, school: "Transmutation",
  casting-time: "Reaction", range: "60 ft", components: "V, M", duration: "1 min",
  trigger: [You or a creature within 60 ft falls.],
  notes: [Up to 5 falling creatures take no falling damage; ends on landing or after 1 min.],
)
#let find-familiar = _spell(
  "Find Familiar", 1, school: "Conjuration",
  casting-time: "1 hr", range: "10 ft", components: "V, S, M",
  duration: "Instantaneous", material-cost: true,
  notes: [Summon a celestial/fey/fiendish spirit in beast form. Touch-range spells can be delivered through it.],
)
#let comprehend-languages = _spell(
  "Comprehend Languages", 1, school: "Divination",
  casting-time: "Action", range: "Self", components: "V, S, M",
  duration: "1 hour", ritual: true,
  notes: [Understand meaning of any spoken/signed language, and any written language you touch (\~1 min/page). Doesn't decode symbols or secret messages.],
)

// Spells with passive effects also work as features.
#let mage-armor = _spell(
  "Mage Armor", 1, school: "Abjuration",
  casting-time: "Action", range: "Touch", components: "V, S, M",
  duration: "8 hr",
  notes: [Target's base AC becomes $13$ + Dex while it wears no armor. Ends if it dons armor.],
  effects: (eff-ac-formula(13, abilities: (ability.dex,), source: "Mage Armor"),),
)
#let chromatic-orb = _spell(
  "Chromatic Orb", 1, school: "Evocation",
  casting-time: "Action", range: "90 ft", components: "V, S, M", material-cost: true,
  duration: "Instantaneous", attack: true,
  slot-damage: (
    (1, 3, "d8", "Acid"), (2, 4, "d8", "Acid"), (3, 5, "d8", "Acid"),
    (4, 6, "d8", "Acid"), (5, 7, "d8", "Acid"), (6, 8, "d8", "Acid"),
    (7, 9, "d8", "Acid"), (8, 10, "d8", "Acid"), (9, 11, "d8", "Acid"),
  ),
  notes: [Damage type is your choice (Acid/Cold/Fire/Lightning/Poison/Thunder). Matching d8s make the orb leap to a new target within 30 ft.],
  scaling: [$+1d 8$/slot above 1st.],
)
#let shield-of-faith = _spell(
  "Shield of Faith", 1, school: "Abjuration",
  casting-time: "Bonus Action", range: "60 ft", components: "V, S, M",
  duration: "10 min", concentration: true,
  notes: [$+2$ AC to a creature you can see, for the duration.],
  effects: (eff-ac-bonus(2, source: "Shield of Faith"),),
)

// --- Goro's spells ---------------------------------------------------------
// Druid & Primal Order cantrips
#let guidance = _spell(
  "Guidance", 0, school: "Divination",
  casting-time: "Action", range: "Touch", components: "V, S",
  duration: "1 min", concentration: true,
  notes: [Touched creature adds $+1d 4$ to ability checks using one chosen skill.],
)
#let produce-flame = _spell(
  "Produce Flame", 0, school: "Conjuration",
  casting-time: "Bonus Action", range: "Self", components: "V, S",
  duration: "10 min", attack: true,
  damage: ((1, 1, "d8", "Fire"), (5, 2, "d8", "Fire"), (11, 3, "d8", "Fire"), (17, 4, "d8", "Fire")),
  notes: [Bright/Dim Light 20/40 ft. _Action_: 60 ft ranged spell attack.],
)
#let shape-water = _spell(
  "Shape Water", 0, school: "Transmutation",
  casting-time: "Action", range: "30 ft", area: (shape: "cube", size: "5 ft"),
  components: "S", duration: "Instantaneous",
  notes: [Move/shape/freeze/change color of a cube of water. Non-instant changes last 1 hour (2 active at a time).],
)
// Magic Initiate (Wizard) cantrips
#let mind-sliver = _spell(
  "Mind Sliver", 0, school: "Enchantment",
  casting-time: "Action", range: "60 ft", components: "V",
  duration: "1 round", save: "INT",
  damage: ((1, 1, "d6", "Psychic"), (5, 2, "d6", "Psychic"), (11, 3, "d6", "Psychic"), (17, 4, "d6", "Psychic")),
  notes: [$-1d 4$ to its next save before EoYN.],
)
// - `weapon-attack: true`: it makes a weapon attack, not a spell attack.
// - Thus the SPELLS table shows no HIT/SAVE for it.
// - The resolver makes one `via-spell` attack line per proficient weapon,
//   cast with the spellcasting ability, with Radiant damage and level-scaled
//   dice (see `_true-strike-line`).
// - Its material component is the weapon itself, worth 1+ CP.
// - Do not set `material-cost`: 1+ CP is not a costly component. Detect
//   Thoughts gets the same treatment.
#let true-strike = _spell(
  "True Strike", 0, school: "Divination",
  casting-time: "Action", range: "Self", components: "S, M",
  duration: "Instantaneous", weapon-attack: true,
  notes: [Weapon attack w/spell ability. Can deal Radiant damage.],
)

// Druid 1st-level prepared spells
#let absorb-elements = _spell(
  "Absorb Elements", 1, school: "Abjuration",
  casting-time: "Reaction", range: "Self", components: "S",
  duration: "1 round",
  trigger: [You take acid, cold, fire, lightning, or thunder damage.],
  notes: [Resistance to triggering damage. $+1d 6$ of triggering type on next melee hit.],
)
#let entangle = _spell(
  "Entangle", 1, school: "Conjuration",
  casting-time: "Action", range: "90 ft", area: (shape: "square", size: "20 ft"),
  components: "V, S", duration: "1 min", concentration: true, save: "STR",
  notes: [Restrained. Area is difficult terrain.],
)
#let faerie-fire = _spell(
  "Faerie Fire", 1, school: "Evocation",
  casting-time: "Action", range: "60 ft", area: (shape: "cube", size: "20 ft"),
  components: "V", duration: "1 min", concentration: true, save: "DEX",
  notes: [Affected creatures shed Dim Light 10 ft; attack rolls against them have Advantage; they cannot benefit from being Invisible.],
)
#let healing-word = _spell(
  "Healing Word", 1, school: "Abjuration",
  casting-time: "Bonus Action", range: "60 ft", components: "V",
  duration: "Instantaneous",
  healing: ((1, 2, "d4"), (2, 3, "d4"), (3, 4, "d4"), (4, 5, "d4"), (5, 6, "d4"), (6, 7, "d4"), (7, 8, "d4"), (8, 9, "d4"), (9, 10, "d4")),
  damage-bonus: "casting-mod",
)
#let goodberry = _spell(
  "Goodberry", 1, school: "Conjuration",
  casting-time: "Action", range: "Self", components: "V, S, M",
  duration: "24 hours",
  notes: [10 magic berries appear. _B.Action_ to eat one: restores 1 HP and sustains a creature for a day.],
)
#let jump = _spell(
  "Jump", 1, school: "Transmutation",
  casting-time: "Bonus Action", range: "Touch", components: "V, S, M",
  duration: "1 min", notes: [1/turn, spend 10 ft movement to jump 30 ft.],
)
#let speak-with-animals = _spell(
  "Speak with Animals", 1, school: "Divination",
  casting-time: "Action", range: "Self", components: "V, S",
  duration: "10 min", ritual: true, notes: [Communicate with Beasts. Influence them.],
)

// --- Warlock 1st-level spells ----------------------------------------------
#let armor-of-agathys = _spell(
  "Armor of Agathys", 1, school: "Abjuration",
  casting-time: "Bonus Action", range: "Self", components: "V, S, M",
  duration: "1 hour",
  notes: [5 THP/slot. If creature hits you with a melee attack, it takes 5 Cold/slot.],
)
#let dissonant-whispers = _spell(
  "Dissonant Whispers", 1, school: "Enchantment",
  casting-time: "Action", range: "60 ft", components: "V",
  duration: "Instantaneous", save: "WIS",
  slot-damage: (
    (1, 3, "d6", "Psychic"), (2, 4, "d6", "Psychic"), (3, 5, "d6", "Psychic"),
    (4, 6, "d6", "Psychic"), (5, 7, "d6", "Psychic"), (6, 8, "d6", "Psychic"),
    (7, 9, "d6", "Psychic"), (8, 10, "d6", "Psychic"), (9, 11, "d6", "Psychic"),
  ),
  notes: [On fail: target uses Reaction to flee as far as possible. On success: half damage.],
  scaling: [$+1d 6$/slot above 1st.],
)
#let false-life = _spell(
  "False Life", 1, school: "Necromancy",
  casting-time: "Action", range: "Self", components: "V, S, M",
  duration: "Instantaneous",
  notes: [Gain $2d 4 + 4$ Temporary HP.],
  scaling: [$+5$ THP/slot above 1st.],
  at-level: lv => (scaling: [An additional #(5 * (lv - 1)) THP.],),
)
#let hex = _spell(
  "Hex", 1, school: "Enchantment",
  casting-time: "Bonus Action", range: "90 ft", components: "V, S, M",
  duration: "1 hour", concentration: true,
  notes: [$+1d 6$ Necrotic whenever you hit target with an attack roll. Target has Disadvantage on one chosen ability's checks. _B.Action_: curse a new target if current drops to 0 HP. Slot 2: 4h; 3–4: 8h; 5+: 24h.],
)
#let tashas-hideous-laughter = _spell(
  "Tasha’s Hideous Laughter", 1, school: "Enchantment",
  casting-time: "Action", range: "30 ft", components: "V, S, M",
  duration: "1 min", concentration: true, save: "WIS",
  notes: [On fail: Prone and Incapacitated; can't end Prone itself. Repeats save at end of each turn and on taking damage (Advantage when triggered by damage); success ends spell.],
  scaling: [$+1$ target/slot above 1st.],
  at-level: lv => (scaling: [Targets up to #lv creatures.],),
)

// --- Warlock 2nd-level spells ----------------------------------------------
#let cloud-of-daggers = _spell(
  "Cloud of Daggers", 2, school: "Conjuration",
  casting-time: "Action", range: "60 ft", area: (shape: "cube", size: "5 ft"),
  components: "V, S, M", duration: "1 min", concentration: true,
  slot-damage: (
    (2, 4, "d4", "Slashing"), (3, 6, "d4", "Slashing"), (4, 8, "d4", "Slashing"),
    (5, 10, "d4", "Slashing"), (6, 12, "d4", "Slashing"),
  ),
  notes: [Creatures entering or ending their turn in the area take damage once/turn. _Magic Action_: teleport cube up to 30 ft; creatures whose space it enters take damage.],
  scaling: [$+2d 4$/slot above 2nd.],
)
#let detect-thoughts = _spell(
  "Detect Thoughts", 2, school: "Divination",
  casting-time: "Action", range: "Self", components: "V, S, M",
  duration: "1 min", concentration: true, save: "WIS",
  notes: [Sense Thoughts: detect thinking creatures within 30 ft. Read Thoughts: learn surface thoughts of a target within 30 ft. _Magic Action_: probe deeper (WIS save; creature knows either way).],
)
#let phantasmal-force = _spell(
  "Phantasmal Force", 2, school: "Illusion",
  casting-time: "Action", range: "60 ft", area: (shape: "cube", size: "10 ft"),
  components: "V, S, M", duration: "1 min", concentration: true,
  save: "INT",
  notes: [Target perceives a self-consistent illusion. On each of your turns, the phantasm deals $2d 8$ Psychic if the target is in or within 5 ft of it. Study action + INT (Investigation) check vs. spell save DC to disbelieve.],
)
#let suggestion = _spell(
  "Suggestion", 2, school: "Enchantment",
  casting-time: "Action", range: "30 ft", components: "V, M",
  duration: "8 hours", concentration: true, save: "WIS",
  notes: [Issue a reasonable suggestion (no more than 25 words). On a failed save, target has the Charmed condition and follows it. Spell ends when the activity completes or you/allies deal damage to the target.],
)

// --- Bard spells (Elara) ---------------------------------------------------
#let vicious-mockery = _spell(
  "Vicious Mockery", 0, school: "Enchantment",
  casting-time: "Action", range: "60 ft", components: "V",
  duration: "1 round", save: "WIS",
  damage: ((1, 1, "d6", "Psychic"), (5, 2, "d6", "Psychic"), (11, 3, "d6", "Psychic"), (17, 4, "d6", "Psychic")),
  notes: [On a failed save, the target also has Disadvantage on its next attack roll before the end of its next turn.],
)
#let starry-wisp = _spell(
  "Starry Wisp", 0, school: "Evocation",
  casting-time: "Action", range: "60 ft", components: "V, S",
  duration: "Instantaneous", attack: true,
  damage: ((1, 1, "d8", "Radiant"), (5, 2, "d8", "Radiant"), (11, 3, "d8", "Radiant"), (17, 4, "d8", "Radiant")),
  notes: [On a hit, target sheds Dim Light in a 10 ft radius, cannot benefit from the Invisible condition until EoYN.],
)
#let charm-person = _spell(
  "Charm Person", 1, school: "Enchantment",
  casting-time: "Action", range: "30 ft", components: "V, S",
  duration: "1 hour", save: "WIS",
  notes: [On a failed save, the target has the Charmed condition until the spell ends or you or an ally harm it. It knows it was Charmed afterward.],
  scaling: [$+1$ target/slot above 1st.],
  at-level: lv => (scaling: [Targets up to #lv creatures.],),
)
#let command = _spell(
  "Command", 1, school: "Enchantment",
  casting-time: "Action", range: "60 ft", components: "V",
  duration: "1 round", save: "WIS",
  notes: [Speak a one-word command (Approach, Drop, Flee, Grovel, or Halt) the target obeys on its next turn if it fails the save.],
  scaling: [$+1$ target/slot above 1st.],
  at-level: lv => (scaling: [Targets up to #lv creatures.],),
)
#let sleep = _spell(
  "Sleep", 1, school: "Enchantment",
  casting-time: "Action", range: "90 ft", area: (shape: "sphere", size: "5 ft"),
  components: "V, S, M", duration: "1 min", concentration: true, save: "WIS",
  notes: [Creatures in the Sphere that fail the save have the Incapacitated condition until the spell ends, ending early for a creature that takes damage or is shaken awake.],
)
#let silvery-barbs = _spell(
  "Silvery Barbs", 1, school: "Enchantment",
  casting-time: "Reaction", range: "60 ft", components: "V",
  duration: "Instantaneous",
  trigger: [A creature you can see within 60 ft succeeds on an attack roll, ability check, or saving throw.],
  notes: [Force it to reroll and use the lower roll. A different creature you can see gains Advantage on its next attack roll, check, or save within 1 minute.],
)
#let ice-knife = _spell(
  "Ice Knife", 1, school: "Conjuration",
  casting-time: "Action", range: "60 ft", area: (shape: "sphere", size: "5 ft"),
  components: "S, M", duration: "Instantaneous", attack: true,
  slot-damage: ((1, 1, "d10", "Piercing"),),
  notes: [Ranged spell attack for the knife's Piercing damage. Hit or miss, each creature within 5 ft of the target makes a DEX save or takes $2d 6$ Cold.],
  scaling: [$+1d 6$ Cold/slot above 1st.],
  at-level: lv => (scaling: [Burst: $#(lv + 1) d 6$ Cold (DEX save) within 5 ft.],),
)
#let enlarge-reduce = _spell(
  "Enlarge/Reduce", 2, school: "Transmutation",
  casting-time: "Action", range: "30 ft", components: "V, S, M",
  duration: "1 min", concentration: true, save: "CON",
  notes: [_Enlarge_: size up, Advantage on Strength checks/saves, $+1d 4$ weapon damage. _Reduce_: size down, Disadvantage on Strength checks/saves, $-1d 4$ weapon damage. A creature can save to resist.],
)
#let invisibility = _spell(
  "Invisibility", 2, school: "Illusion",
  casting-time: "Action", range: "Touch", components: "V, S, M",
  duration: "1 hour", concentration: true,
  notes: [The target and its gear have the Invisible condition until the spell ends or it attacks or casts a spell.],
  scaling: [$+1$ target/slot above 2nd.],
  at-level: lv => (scaling: [Targets up to #(lv - 1) creatures.],),
)
#let mirror-image = _spell(
  "Mirror Image", 2, school: "Illusion",
  casting-time: "Action", range: "Self", components: "V, S",
  duration: "1 min",
  notes: [Three illusory duplicates appear. When a creature attacks you, roll to see if it targets a duplicate instead (destroying it). Duplicates mimic your movements.],
)
#let misty-step = _spell(
  "Misty Step", 2, school: "Conjuration",
  casting-time: "Bonus Action", range: "Self", components: "V",
  duration: "Instantaneous",
  notes: [Teleport up to 30 ft to an unoccupied space you can see.],
)

// Magic Initiate (Wizard) 1st-level spell
#let shield = _spell(
  "Shield", 1, school: "Abjuration",
  casting-time: "Reaction", range: "Self", components: "V, S",
  duration: "1 round",
  trigger: [Hit by an attack roll or targeted by the _Magic Missile_ spell.],
  notes: [$+5$ AC and no damage from _Magic Missile_ until SoYN.],
)

// --- Kragor's Warlock spells (3rd–5th level, cast with pact slots) ----------
#let clairvoyance = _spell(
  "Clairvoyance", 3, school: "Divination",
  casting-time: "10 min", range: "1 mile", components: "V, S, M", material-cost: true,
  duration: "10 min", concentration: true,
  notes: [Create an Invisible sensor at a known or obvious location and see or hear through it. Bonus Action to switch between sight and hearing.],
)
#let dispel-magic = _spell(
  "Dispel Magic", 3, school: "Abjuration",
  casting-time: "Action", range: "120 ft", components: "V, S",
  duration: "Instantaneous",
  notes: [End an ongoing spell in range. Requires spellcasting ability check of DC $10$ + that spell's level.],
  scaling: [Automatic success if the spell's level is equal to or less than the slot used.],
  at-level: lv => (scaling: [Automatic success if the spell is level #lv or lower.]),
)
#let fly = _spell(
  "Fly", 3, school: "Transmutation",
  casting-time: "Action", range: "Touch", components: "V, S, M",
  duration: "10 min", concentration: true,
  notes: [A willing creature you touch gains a Fly Speed of 60 ft and can hover.],
  scaling: [$+1$ target/slot above 3rd.],
  at-level: lv => (scaling: [Targets up to #(lv - 2) creatures.],),
)
#let hunger-of-hadar = _spell(
  "Hunger of Hadar", 3, school: "Conjuration",
  casting-time: "Action", range: "150 ft", area: (shape: "sphere", size: "20 ft"),
  components: "V, S, M", duration: "1 min", concentration: true, save: "DEX",
  notes: [A 20-ft Sphere of Darkness and Difficult Terrain; creatures fully inside are Blinded. Start a turn there: $2d 6$ Cold. End a turn there: DEX save or $2d 6$ Acid.],
  scaling: [$+1d 6$ Cold or Acid/slot above 3rd.],
  at-level: lv => (scaling: [Start/end turn there: $#(lv - 1) d 6$ Cold or Acid.],),
)
#let major-image = _spell(
  "Major Image", 3, school: "Illusion",
  casting-time: "Action", range: "120 ft", area: (shape: "cube", size: "20 ft"),
  components: "V, S, M", duration: "10 min", concentration: true,
  check: [_Study_ (Investigation) to disbelieve],
  notes: [Create a real-seeming image (with sound, smell, temperature) up to a 20-ft Cube. _Magic Action_: Move it within range.],
  scaling: [Lasts until dispelled, no Concentration, if cast at 4th+.],
  at-level: lv => if lv >= 4 { (duration: "until dispelled", concentration: false, scaling: none) } else { (:) },
)
#let remove-curse = _spell(
  "Remove Curse", 3, school: "Abjuration",
  casting-time: "Action", range: "Touch", components: "V, S",
  duration: "Instantaneous",
  notes: [End all curses affecting one creature or object; breaks a cursed magic item's Attunement so it can be removed.],
)
#let summon-fey = _spell(
  "Summon Fey", 3, school: "Conjuration",
  casting-time: "Action", range: "90 ft", components: "V, S, M", material-cost: true,
  duration: "1 hour", concentration: true,
  notes: [Summon a Fey Spirit ally (Fuming, Mirthful, or Tricksy).],
  scaling: [AC $12$ + slot; HP $30 + 10$/slot above 3rd; Fey Blade $2d 6 + 3$ + slot Force.],
  at-level: lv => (scaling: [Spirit: AC #(12 + lv), HP #(30 + 10 * (lv - 3)), Fey Blade $2d 6 + #(3 + lv)$ Force (#calc.floor(lv / 2) attacks).],),
)
#let banishment = _spell(
  "Banishment", 4, school: "Abjuration",
  casting-time: "Action", range: "30 ft", components: "V, S, M",
  duration: "1 min", concentration: true, save: "CHA",
  notes: [On a failed save, banish the target to a harmless demiplane (Incapacitated). A native outsider banished a full minute is sent to its home plane.],
  scaling: [$+1$ target/slot above 4th.],
  at-level: lv => (scaling: [Targets up to #(lv - 3) creatures.],),
)
#let confusion = _spell(
  "Confusion", 4, school: "Enchantment",
  casting-time: "Action", range: "90 ft", area: (shape: "sphere", size: "10 ft"),
  components: "V, S, M", duration: "1 min", concentration: true, save: "WIS",
  notes: [Creatures in a 10-ft Sphere that fail can't take Bonus Actions or Reactions and roll $1d 10$ each turn to act randomly. Save repeats at end of turn.],
  scaling: [$+5$ ft radius/slot above 4th.],
  at-level: lv => (area: (shape: "sphere", size: str(10 + (lv - 4) * 5) + " ft"), scaling: none),
)
#let dimension-door = _spell(
  "Dimension Door", 4, school: "Conjuration",
  casting-time: "Action", range: "500 ft", components: "V",
  duration: "Instantaneous",
  notes: [Teleport to a spot within range you can see, visualize, or describe; bring one willing creature within 5 ft. Colliding: $4d 6$ Force each and the teleport fails.],
)
#let summon-aberration = _spell(
  "Summon Aberration", 4, school: "Conjuration",
  casting-time: "Action", range: "90 ft", components: "V, S, M", material-cost: true,
  duration: "1 hour", concentration: true,
  notes: [Summon an Aberrant Spirit ally (Beholderkin, Mind Flayer, or Slaad).],
  scaling: [AC $11$ + slot; HP $40 + 10$/slot above 4th; damage $+3$ + slot Force.],
  at-level: lv => (scaling: [Spirit: AC #(11 + lv), HP #(40 + 10 * (lv - 4)), damage $+ #(3 + lv)$ (#calc.floor(lv / 2) attacks).],),
)
#let arcane-eye = _spell(
  "Arcane Eye", 4, school: "Divination",
  casting-time: "Action", range: "30 ft", components: "V, S, M",
  duration: "1 hour", concentration: true,
  notes: [Create an Invisible sensor with Darkvision 30 ft that sees every direction. Bonus Action to move it up to 30 ft (through gaps as small as 1 inch).],
)
#let contact-other-plane = _spell(
  "Contact Other Plane", 5, school: "Divination",
  casting-time: "1 min", range: "Self", components: "V",
  duration: "1 min", ritual: true,
  notes: [Ask an otherworldly entity up to five one-word questions. Make a DC $15$ INT save; on a failure, take $6d 6$ Psychic and are Incapacitated until a Long Rest.],
)
#let modify-memory = _spell(
  "Modify Memory", 5, school: "Enchantment",
  casting-time: "Action", range: "30 ft", components: "V, S",
  duration: "1 min", concentration: true, save: "WIS",
  notes: [On a failed save the target is Charmed and Incapacitated while you reshape one of its memories (an event within the last 24 h, up to 10 min long). Ends if it takes damage.],
  scaling: [Reach further back: 7 days (6th), 30 days (7th), 1 year (8th), any time (9th).],
)
#let synaptic-static = _spell(
  "Synaptic Static", 5, school: "Enchantment",
  casting-time: "Action", range: "120 ft", area: (shape: "sphere", size: "20 ft"),
  components: "V, S", duration: "Instantaneous", save: "INT",
  slot-damage: ((5, 8, "d6", "Psychic"),),
  notes: [Half damage on a save. On a failed save, also $-1d 6$ to attacks, ability checks, and Concentration saves for 1 min (save ends).],
)
#let telekinesis = _spell(
  "Telekinesis", 5, school: "Transmutation",
  casting-time: "Action", range: "60 ft", components: "V, S",
  duration: "10 min", concentration: true, save: "STR",
  notes: [By thought, move a Huge or smaller creature (STR save, then Restrained) or object up to 30 ft. _Magic Action_: Repeat on each turn. Fine manipulation of objects.],
)

// --- Druid cantrips (Scarlet) ----------------------------------------------
#let primal-savagery = _spell(
  "Primal Savagery", 0, school: "Transmutation",
  casting-time: "Action", range: "Self", components: "S",
  duration: "Instantaneous", attack: true,
  damage: ((1, 1, "d10", "Acid"), (5, 2, "d10", "Acid"), (11, 3, "d10", "Acid"), (17, 4, "d10", "Acid")),
  notes: [Melee spell attack with sharpened teeth/nails, reach 5 ft.],
)
// - Shillelagh imbues a Club or Quarterstaff you hold; it makes no spell attack.
// - `weapon-attack: true` thus expands it into a per-weapon attack line, and
//   leaves this row without a HIT/SAVE or damage cell (see resolve.typ).
#let shillelagh = _spell(
  "Shillelagh", 0, school: "Transmutation",
  casting-time: "Bonus Action", range: "Self", components: "V, S, M",
  duration: "1 min", weapon-attack: true,
  notes: [Attack with a Club or Quarterstaff using your spellcasting ability and a $d 8$ damage die. Force damage or the weapon's own type.],
)

// --- Druid 1st-level spells (Scarlet) ---------------------------------------
#let animal-friendship = _spell(
  "Animal Friendship", 1, school: "Enchantment",
  casting-time: "Action", range: "30 ft", components: "V, S, M",
  duration: "24 hours", save: "WIS",
  notes: [Charm one Beast you can see. Ends if you or an ally damages it.],
  scaling: [$+1$ Beast/slot above 1st.],
)
#let bless = _spell(
  "Bless", 1, school: "Enchantment",
  casting-time: "Action", range: "30 ft", components: "V, S, M", material-cost: true,
  duration: "1 min", concentration: true,
  notes: [Up to three creatures add $+1d 4$ to each attack roll and saving throw.],
  scaling: [$+1$ target/slot above 1st.],
)
#let cure-wounds = _spell(
  "Cure Wounds", 1, school: "Abjuration",
  casting-time: "Action", range: "Touch", components: "V, S",
  duration: "Instantaneous",
  healing: ((1, 2, "d8"), (2, 4, "d8"), (3, 6, "d8"), (4, 8, "d8"), (5, 10, "d8"), (6, 12, "d8"), (7, 14, "d8"), (8, 16, "d8"), (9, 18, "d8")),
  damage-bonus: "casting-mod",
)

// --- Druid 2nd-level spells (Scarlet) ---------------------------------------
#let hold-person = _spell(
  "Hold Person", 2, school: "Enchantment",
  casting-time: "Action", range: "60 ft", components: "V, S, M",
  duration: "1 min", concentration: true, save: "WIS",
  notes: [Paralyze one Humanoid. It repeats the save ever EoNT.],
  scaling: [$+1$ Humanoid/slot above 2nd.],
)
#let moonbeam = _spell(
  "Moonbeam", 2, school: "Evocation",
  casting-time: "Action", range: "120 ft", area: (shape: "cylinder", size: "5 ft"),
  components: "V, S, M", duration: "1 min", concentration: true, save: "CON",
  slot-damage: (
    (2, 2, "d10", "Radiant"), (3, 3, "d10", "Radiant"), (4, 4, "d10", "Radiant"),
    (5, 5, "d10", "Radiant"), (6, 6, "d10", "Radiant"), (7, 7, "d10", "Radiant"),
    (8, 8, "d10", "Radiant"), (9, 9, "d10", "Radiant"),
  ),
  notes: [5-ft radius, 40-ft high Cylinder of Dim Light, damage once per turn when it appears, is moved, creature enters or ends its turn in area. Save: half damage. Cancels shape-shift. _Magic Action_: move Cylinder 60 ft.],
  scaling: [$+1d 10$/slot above 2nd.],
)
#let pass-without-trace = _spell(
  "Pass without Trace", 2, school: "Abjuration",
  casting-time: "Action", range: "Self", area: (shape: "emanation", size: "30 ft"),
  components: "V, S, M", duration: "1 hour", concentration: true,
  notes: [Creatures you choose gain $+10$ to Dexterity (Stealth) checks and leave no tracks.],
)
#let spike-growth = _spell(
  "Spike Growth", 2, school: "Transmutation",
  casting-time: "Action", range: "150 ft", area: (shape: "sphere", size: "20 ft"),
  components: "V, S, M", duration: "10 min", concentration: true,
  slot-damage: ((2, 2, "d4", "Piercing"),),
  check: [_Search_ (Perception or Survival) to spot the hazard],
  notes: [The ground becomes Difficult Terrain. A creature takes the damage for every 5 ft it moves in the area.],
)
#let summon-beast = _spell(
  "Summon Beast", 2, school: "Conjuration",
  casting-time: "Action", range: "90 ft", components: "V, S, M", material-cost: true,
  duration: "1 hour", concentration: true,
  notes: [Summon Air, Land, or Water Bestial Spirit. Shares Initiative, takes turn immediately after yours. Obeys your verbal commands.],
  scaling: [AC $11$ + slot's level; HP $20$ (Air) or $30$ (Land, Water) $+5$/slot's level; melee damage $1d 8 + 4$ + slot's level.]
)

// --- Circle of the Moon spells (levels 5, 7 and 9) --------------------------
#let conjure-animals = _spell(
  "Conjure Animals", 3, school: "Conjuration",
  casting-time: "Action", range: "60 ft", components: "V, S",
  duration: "10 min", concentration: true, save: "DEX",
  slot-damage: (
    (3, 3, "d10", "Slashing"), (4, 4, "d10", "Slashing"), (5, 5, "d10", "Slashing"),
    (6, 6, "d10", "Slashing"), (7, 7, "d10", "Slashing"), (8, 8, "d10", "Slashing"),
    (9, 9, "d10", "Slashing"),
  ),
  notes: [A Large pack of spirit animals. Advantage on STR saves within 5 ft of it; move it 30 ft when you move. Damage once per turn to a creature within 10 ft of the pack.],
  scaling: [$+1d 10$/slot above 3rd.],
)
#let fount-of-moonlight = _spell(
  "Fount of Moonlight", 4, school: "Evocation",
  casting-time: "Action", range: "Self", components: "V, S",
  duration: "10 min", concentration: true, save: "CON",
  notes: [Bright Light 20 ft, Dim Light 20 ft more. You gain Resistance to Radiant damage and your melee attacks deal $+2d 6$ Radiant. _Reaction_ after a visible creature within 60 ft damages you: it is Blinded until the end of your next turn on a failed save.],
)
#let mass-cure-wounds = _spell(
  "Mass Cure Wounds", 5, school: "Abjuration",
  casting-time: "Action", range: "60 ft", area: (shape: "sphere", size: "30 ft"),
  components: "V, S", duration: "Instantaneous",
  healing: ((5, 5, "d8"), (6, 6, "d8"), (7, 7, "d8"), (8, 8, "d8"), (9, 9, "d8")),
  damage-bonus: "casting-mod",
  notes: [Up to six creatures of your choice in the Sphere.],
)

// --- Cleric cantrips (Therin) -----------------------------------------------
#let sacred-flame = _spell(
  "Sacred Flame", 0, school: "Evocation",
  casting-time: "Action", range: "60 ft", components: "V, S",
  duration: "Instantaneous", save: "DEX",
  damage: ((1, 1, "d8", "Radiant"), (5, 2, "d8", "Radiant"), (11, 3, "d8", "Radiant"), (17, 4, "d8", "Radiant")),
  notes: [The target gains no benefit from Half Cover or Three-Quarters Cover for this save.],
)
#let thaumaturgy = _spell(
  "Thaumaturgy", 0, school: "Transmutation",
  casting-time: "Action", range: "30 ft", components: "V",
  duration: "1 min",
  notes: [One minor wonder: altered eyes, a voice three times as loud (Advantage on Intimidation checks), flames that flicker or change color, an unlocked door or window that flies open or slams shut, a phantom sound, or harmless tremors. Up to three of its 1-minute effects can be active at a time.],
)
// The alternative d12 is conditional on the target's Hit Points, thus it stays prose and the tiers carry the d8.
#let toll-the-dead = _spell(
  "Toll the Dead", 0, school: "Necromancy",
  casting-time: "Action", range: "60 ft", components: "V, S",
  duration: "Instantaneous", save: "WIS",
  damage: ((1, 1, "d8", "Necrotic"), (5, 2, "d8", "Necrotic"), (11, 3, "d8", "Necrotic"), (17, 4, "d8", "Necrotic")),
  notes: [Against a target missing any of its Hit Points, roll $d 12$ dice instead.],
)
#let word-of-radiance = _spell(
  "Word of Radiance", 0, school: "Evocation",
  casting-time: "Action", range: "Self", area: (shape: "emanation", size: "5 ft"),
  components: "V, M", duration: "Instantaneous", save: "CON",
  damage: ((1, 1, "d6", "Radiant"), (5, 2, "d6", "Radiant"), (11, 3, "d6", "Radiant"), (17, 4, "d6", "Radiant")),
  notes: [Radiance erupts in a 5-ft Emanation, hitting each creature of your choice that you can see in it.],
)

// --- Cleric 1st-level spells (Therin) ---------------------------------------
#let bane = _spell(
  "Bane", 1, school: "Enchantment",
  casting-time: "Action", range: "30 ft", components: "V, S, M",
  duration: "1 min", concentration: true, save: "CHA",
  notes: [Up to three creatures subtract $1d 4$ from each attack roll and saving throw they make.],
  scaling: [$+1$ target/slot above 1st.],
  at-level: lv => (scaling: [Targets up to #(lv + 2) creatures.],),
)
#let burning-hands = _spell(
  "Burning Hands", 1, school: "Evocation",
  casting-time: "Action", range: "Self", area: (shape: "cone", size: "15 ft"),
  components: "V, S", duration: "Instantaneous", save: "DEX",
  slot-damage: (
    (1, 3, "d6", "Fire"), (2, 4, "d6", "Fire"), (3, 5, "d6", "Fire"),
    (4, 6, "d6", "Fire"), (5, 7, "d6", "Fire"), (6, 8, "d6", "Fire"),
    (7, 9, "d6", "Fire"), (8, 10, "d6", "Fire"), (9, 11, "d6", "Fire"),
  ),
  notes: [Half damage on a success. Flammable objects in the Cone that no one wears or carries start burning.],
  scaling: [$+1d 6$/slot above 1st.],
)

// --- Cleric 2nd-level spells (Therin) ---------------------------------------
// The 5 Hit Points are a maximum increase, not healing, thus they stay prose and the spell carries no healing tiers.
#let aid = _spell(
  "Aid", 2, school: "Abjuration",
  casting-time: "Action", range: "30 ft", components: "V, S, M",
  duration: "8 hours",
  notes: [Up to three creatures each raise their Hit Point maximum and current Hit Points by $5$.],
  scaling: [$+5$ HP/slot above 2nd.],
  at-level: lv => (scaling: [Each target raises both by $#(5 * (lv - 1))$.],),
)
#let lesser-restoration = _spell(
  "Lesser Restoration", 2, school: "Abjuration",
  casting-time: "Bonus Action", range: "Touch", components: "V, S",
  duration: "Instantaneous",
  notes: [End one condition on the creature you touch: Blinded, Deafened, Paralyzed, or Poisoned.],
)
#let prayer-of-healing = _spell(
  "Prayer of Healing", 2, school: "Abjuration",
  casting-time: "10 min", range: "30 ft", components: "V",
  duration: "Instantaneous",
  healing: ((2, 2, "d8"), (3, 3, "d8"), (4, 4, "d8"), (5, 5, "d8"), (6, 6, "d8"), (7, 7, "d8"), (8, 8, "d8"), (9, 9, "d8")),
  notes: [Up to five creatures that stay in range for the whole casting also gain the benefits of a Short Rest. A creature cannot be affected again until it finishes a Long Rest.],
)
// Each ray is its own attack roll, thus the beam form: the die is the per-ray damage and the count is the ray count.
#let scorching-ray = _spell(
  "Scorching Ray", 2, school: "Evocation",
  casting-time: "Action", range: "120 ft", components: "V, S",
  duration: "Instantaneous", attack: true,
  slot-damage: (
    (2, 3, "2d6", "Fire"), (3, 4, "2d6", "Fire"), (4, 5, "2d6", "Fire"),
    (5, 6, "2d6", "Fire"), (6, 7, "2d6", "Fire"), (7, 8, "2d6", "Fire"),
    (8, 9, "2d6", "Fire"), (9, 10, "2d6", "Fire"),
  ),
  damage-bonus-per: "beam", damage-per-label: "per ray",
  notes: [Hurl the rays at one target or at several.],
  scaling: [$+1$ ray/slot above 2nd.],
)
#let see-invisibility = _spell(
  "See Invisibility", 2, school: "Divination",
  casting-time: "Action", range: "Self", components: "V, S, M",
  duration: "1 hour",
  notes: [See creatures and objects that have the Invisible condition as if they were visible, and see into the Ethereal Plane, where they appear ghostly.],
)

// --- 4th-level spells ------------------------------------------------------
#let raulothims-psychic-lance = _spell(
  "Raulothim's Psychic Lance", 4, school: "Enchantment",
  casting-time: "Action", range: "120 ft", components: "V",
  duration: "Instantaneous", save: "INT",
  slot-damage: (
    (4, 7, "d6", "Psychic"), (5, 8, "d6", "Psychic"), (6, 9, "d6", "Psychic"),
    (7, 10, "d6", "Psychic"), (8, 11, "d6", "Psychic"), (9, 12, "d6", "Psychic"),
  ),
  notes: [On fail: Incapacitated until SoYNT. On save: half damage, no condition. You may utter a creature's name; if it's in range it becomes the target even if unseen. If the named target isn't in range, the lance dissipates.],
  scaling: [$+1d 6$/slot above 4th.],
)

// --- Staff spells (Staff of the Woodlands / Staff of Power) -----------------
#let awaken = _spell(
  "Awaken", 5, school: "Transmutation",
  casting-time: "8 hours", range: "Touch", components: "V, S, M", material-cost: true,
  duration: "Instantaneous",
  notes: [Beast or Plant with INT ≤3 gains INT 10, learns one language, and is Charmed for 30 days.],
)
#let barkskin = _spell(
  "Barkskin", 2, school: "Transmutation",
  casting-time: "Bonus Action", range: "Touch", components: "V, S, M",
  duration: "1 hour",
  notes: [Give a willing creature AC 17.],
)
#let locate-animals-or-plants = _spell(
  "Locate Animals/Plants", 2, school: "Divination",
  casting-time: "Action", range: "Self", components: "V, S, M",
  duration: "Instantaneous", ritual: true,
  notes: [Describe or name specific kind of Beast or Plant to learn direction and distance within 5 miles.],
)
#let speak-with-plants = _spell(
  "Speak with Plants", 3, school: "Transmutation",
  casting-time: "Action", range: "Self", area: (shape: "emanation", size: "30 ft"),
  components: "V, S", duration: "10 min",
  notes: [Communicate with Plants, turn terrain to/from Difficult Terrain, move branches/vines.],
)
#let wall-of-thorns = _spell(
  "Wall of Thorns", 6, school: "Conjuration",
  casting-time: "Action", range: "120 ft",
  components: "V, S, M", duration: "10 min", concentration: true, save: "DEX",
  slot-damage: (
    (6, 7, "d8", "Piercing"), (7, 8, "d8", "Piercing"), (8, 9, "d8", "Piercing"),
    (9, 10, "d8", "Piercing"),
  ),
  notes: [60×10×5 ft wall or 20 ft diameter/height circle. Save: half damage. 1 ft move costs 4 ft. Creature entering/ending turn in wall takes $7d 8$ Slashing (DEX save: half damage).],
  scaling: [$+1d 8$ Piercing & Slashing/slot above 6th.],
)
#let cone-of-cold = _spell(
  "Cone of Cold", 5, school: "Evocation",
  casting-time: "Action", range: "Self", area: (shape: "cone", size: "60 ft"),
  components: "V, S, M", duration: "Instantaneous", save: "CON",
  slot-damage: ((5, 8, "d8", "Cold"), (6, 9, "d8", "Cold"), (7, 10, "d8", "Cold"), (8, 11, "d8", "Cold"), (9, 12, "d8", "Cold")),
  notes: [Save: half damage. Killed creatures freeze until thawed.],
  scaling: [$+1d 8$/slot above 5th.],
)
#let fireball = _spell(
  "Fireball", 3, school: "Evocation",
  casting-time: "Action", range: "150 ft", area: (shape: "sphere", size: "20 ft"),
  components: "V, S, M", duration: "Instantaneous", save: "DEX",
  slot-damage: (
    (3, 8, "d6", "Fire"), (4, 9, "d6", "Fire"), (5, 10, "d6", "Fire"),
    (6, 11, "d6", "Fire"), (7, 12, "d6", "Fire"), (8, 13, "d6", "Fire"),
    (9, 14, "d6", "Fire"),
  ),
  notes: [20-ft radius Sphere. Save: half damage. Flammable objects burn.],
  scaling: [$+1d 6$/slot above 3rd.],
)
#let globe-of-invulnerability = _spell(
  "Globe of Invulnerability", 6, school: "Abjuration",
  casting-time: "Action", range: "Self", area: (shape: "emanation", size: "10 ft"),
  components: "V, S, M", duration: "1 min", concentration: true,
  notes: [Barrier blocks spells of 5th level or lower from affecting anything within it.],
  scaling: [$+1$ spell level blocked/slot above 6th.],
)
#let hold-monster = _spell(
  "Hold Monster", 5, school: "Enchantment",
  casting-time: "Action", range: "90 ft", components: "V, S, M",
  duration: "1 min", concentration: true, save: "WIS",
  notes: [Paralyze one creature. It repeats the save at EoNT.],
  scaling: [$+1$ creature/slot above 5th.],
)
#let levitate = _spell(
  "Levitate", 2, school: "Transmutation",
  casting-time: "Action", range: "60 ft", components: "V, S, M",
  duration: "10 min", concentration: true, save: "CON",
  notes: [Target creature or object (≤500 lb) rises vertically up to 20 ft. _Magic Action_: change altitude by up to 20 ft.],
)
#let lightning-bolt = _spell(
  "Lightning Bolt", 3, school: "Evocation",
  casting-time: "Action", range: "Self", area: (shape: "line", size: "100 ft"),
  components: "V, S, M", duration: "Instantaneous", save: "DEX",
  slot-damage: ((3, 8, "d6", "Lightning"), (4, 9, "d6", "Lightning"), (5, 10, "d6", "Lightning"), (6, 11, "d6", "Lightning"), (7, 12, "d6", "Lightning"), (8, 13, "d6", "Lightning"), (9, 14, "d6", "Lightning")),
  notes: [100-ft long, 5-ft wide Line. Save: half damage.],
  scaling: [$+1d 6$/slot above 3rd.],
)
#let ray-of-enfeeblement = _spell(
  "Ray of Enfeeblement", 2, school: "Necromancy",
  casting-time: "Action", range: "60 ft", components: "V, S",
  duration: "1 min", concentration: true, save: "CON",
  notes: [Save fail: Disadv. on STR D20 tests, subtract $1d 8$ from damage rolls (repeat save at EoNT). Save success: Disadv. on next attack roll.],
)
#let wall-of-force = _spell(
  "Wall of Force", 5, school: "Evocation",
  casting-time: "Action", range: "120 ft", components: "V, S, M",
  duration: "10 min", concentration: true,
  notes: [Invisible, impassable, indestructible wall (dome/globe 10-ft radius, or ten 10×10-ft panels). Blocks ethereal travel.],
)
