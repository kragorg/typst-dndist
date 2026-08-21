// Monster stat block catalog and builder.
// - Sourced from the 2024 Monster Manual reference (/mnt/shared/dndrules/ref/monsters/).
// - Use `monster(...)` or `monster.custom(...)` for custom monsters.

#import "../model.typ": monster

#let custom = monster

// --- CR 0 -------------------------------------------------------------------

#let badger = monster(
  "Badger",
  size: "Tiny", creature-type: "Beast", alignment: "Unaligned",
  ac: 11, hp: 5, hit-dice: "1d4 + 3", speed: "20 ft, burrow 5 ft", cr: "0",
  abilities: (str: 10, dex: 11, con: 16, int: 2, wis: 12, cha: 5),
  skills: (perception: 3),
  resistances: ("Poison",),
  senses: ("Darkvision 30 ft", "Passive Perception 13"),
  actions: (
    (name: "Bite", desc: [_Melee Attack Roll:_ $+2$, reach 5 ft. _Hit:_ $1$ Piercing damage.]),
  ),
)

#let bat = monster(
  "Bat",
  size: "Tiny", creature-type: "Beast", alignment: "Unaligned",
  ac: 12, hp: 1, hit-dice: "1d4 - 1", speed: "5 ft, fly 30 ft", cr: "0",
  abilities: (str: 2, dex: 15, con: 8, int: 2, wis: 12, cha: 4),
  senses: ("Blindsight 60 ft", "Passive Perception 11"),
  actions: (
    (name: "Bite", desc: [_Melee Attack Roll:_ $+4$ to hit, reach 5 ft. _Hit:_ $1$ Piercing damage.]),
  ),
)

#let cat = monster(
  "Cat",
  size: "Tiny", creature-type: "Beast", alignment: "Unaligned",
  ac: 12, hp: 2, hit-dice: "1d4", speed: "40 ft, climb 40 ft", cr: "0",
  abilities: (str: 3, dex: 15, con: 10, int: 3, wis: 12, cha: 7),
  saves: (dex: 4),
  skills: (perception: 3, stealth: 4),
  senses: ("Darkvision 60 ft", "Passive Perception 13"),
  traits: (
    (name: "Jumper", desc: [The cat's jump distance is determined using its Dexterity rather than its Strength.]),
  ),
  actions: (
    (name: "Scratch", desc: [_Melee Attack Roll:_ $+4$, reach 5 ft. _Hit:_ $1$ Slashing damage.]),
  ),
)

#let deer = monster(
  "Deer",
  size: "Medium", creature-type: "Beast", alignment: "Unaligned",
  ac: 13, hp: 4, hit-dice: "1d8", speed: "50 ft", cr: "0",
  abilities: (str: 11, dex: 16, con: 11, int: 2, wis: 14, cha: 5),
  skills: (perception: 4),
  senses: ("Darkvision 60 ft", "Passive Perception 14"),
  traits: (
    (name: "Agile", desc: [The deer doesn't provoke an Opportunity Attack when it moves out of an enemy's reach.]),
  ),
  actions: (
    (name: "Ram", desc: [_Melee Attack Roll:_ $+2$, reach 5 ft. _Hit:_ $2$ ($1d 4$) Bludgeoning damage.]),
  ),
)

#let goat = monster(
  "Goat",
  size: "Medium", creature-type: "Beast", alignment: "Unaligned",
  ac: 10, hp: 4, hit-dice: "1d8", speed: "40 ft, climb 30 ft", cr: "0",
  abilities: (str: 11, dex: 10, con: 11, int: 2, wis: 10, cha: 5),
  saves: (str: 2),
  skills: (perception: 2),
  senses: ("Darkvision 60 ft", "Passive Perception 12"),
  actions: (
    (name: "Ram", desc: [_Melee Attack Roll:_ $+2$, reach 5 ft. _Hit:_ $1$ Bludgeoning damage, or $2$ ($1d 4$) Bludgeoning damage if the goat moved 20+ ft straight toward the target immediately before the hit.]),
  ),
)

#let hawk = monster(
  "Hawk",
  size: "Tiny", creature-type: "Beast", alignment: "Unaligned",
  ac: 13, hp: 1, hit-dice: "1d4 - 1", speed: "10 ft, fly 60 ft", cr: "0",
  abilities: (str: 5, dex: 16, con: 8, int: 2, wis: 14, cha: 6),
  skills: (perception: 6),
  senses: ("Passive Perception 16",),
  actions: (
    (name: "Talons", desc: [_Melee Attack Roll:_ $+5$, reach 5 ft. _Hit:_ $1$ Slashing damage.]),
  ),
)

#let owl = monster(
  "Owl",
  size: "Tiny", creature-type: "Beast", alignment: "Unaligned",
  ac: 11, hp: 1, hit-dice: "1d4 - 1", speed: "5 ft, fly 60 ft", cr: "0",
  abilities: (str: 3, dex: 13, con: 8, int: 2, wis: 12, cha: 7),
  skills: (perception: 5, stealth: 5),
  senses: ("Darkvision 120 ft", "Passive Perception 15"),
  traits: (
    (name: "Flyby", desc: [The owl doesn't provoke Opportunity Attacks when it flies out of an enemy's reach.]),
  ),
  actions: (
    (name: "Talons", desc: [_Melee Attack Roll:_ $+3$, reach 5 ft. _Hit:_ $1$ Slashing damage.]),
  ),
)

#let rat = monster(
  "Rat",
  size: "Tiny", creature-type: "Beast", alignment: "Unaligned",
  ac: 10, hp: 1, hit-dice: "1d4 - 1", speed: "20 ft, climb 20 ft", cr: "0",
  abilities: (str: 2, dex: 11, con: 9, int: 2, wis: 10, cha: 4),
  skills: (perception: 2),
  senses: ("Darkvision 30 ft", "Passive Perception 12"),
  traits: (
    (name: "Agile", desc: [The rat doesn't provoke Opportunity Attacks when it moves out of an enemy's reach.]),
  ),
  actions: (
    (name: "Bite", desc: [_Melee Attack Roll:_ $+2$, reach 5 ft. _Hit:_ $1$ Piercing damage.]),
  ),
)

#let raven = monster(
  "Raven",
  size: "Tiny", creature-type: "Beast", alignment: "Unaligned",
  ac: 12, hp: 2, hit-dice: "1d4", speed: "10 ft, fly 50 ft", cr: "0",
  abilities: (str: 2, dex: 14, con: 10, int: 5, wis: 13, cha: 6),
  skills: (perception: 3),
  senses: ("Passive Perception 13",),
  traits: (
    (name: "Mimicry", desc: [The raven can mimic simple sounds it has heard. A hearer can discern the sounds are imitations with a successful DC 10 Wisdom (Insight) check.]),
  ),
  actions: (
    (name: "Beak", desc: [_Melee Attack Roll:_ $+4$, reach 5 ft. _Hit:_ $1$ Piercing damage.]),
  ),
)

#let spider = monster(
  "Spider",
  size: "Tiny", creature-type: "Beast", alignment: "Unaligned",
  ac: 12, hp: 1, hit-dice: "1d4 - 1", speed: "20 ft, climb 20 ft", cr: "0",
  abilities: (str: 2, dex: 14, con: 8, int: 1, wis: 10, cha: 2),
  skills: (stealth: 4),
  senses: ("Darkvision 30 ft", "Passive Perception 10"),
  traits: (
    (name: "Spider Climb", desc: [The spider can climb difficult surfaces, including along ceilings, without needing to make an ability check.]),
    (name: "Web Walker", desc: [The spider ignores movement restrictions caused by webs, and knows the location of any other creature in contact with the same web.]),
  ),
  actions: (
    (name: "Bite", desc: [_Melee Attack Roll:_ $+4$, reach 5 ft. _Hit:_ $1$ Piercing damage plus $2$ ($1d 4$) Poison damage.]),
  ),
)

// --- CR 1/8 -----------------------------------------------------------------

#let dolphin = monster(
  "Dolphin",
  size: "Medium", creature-type: "Beast", alignment: "Unaligned",
  ac: 12, hp: 11, hit-dice: "2d8 + 2", speed: "0 ft, swim 60 ft", cr: "1/8",
  abilities: (str: 14, dex: 13, con: 13, int: 6, wis: 12, cha: 7),
  skills: (perception: 3),
  senses: ("Blindsight 60 ft", "Passive Perception 13"),
  traits: (
    (name: "Hold Breath", desc: [The dolphin can hold its breath for 20 minutes.]),
    (name: "Pack Tactics", desc: [The dolphin has Advantage on an attack roll against a creature if at least one of the dolphin's allies is within 5 ft of the creature and the ally isn't Incapacitated.]),
  ),
  actions: (
    (name: "Slam", desc: [_Melee Attack Roll:_ $+4$, reach 5 ft. _Hit:_ $5$ ($1d 6 + 2$) Bludgeoning damage.]),
  ),
)

#let giant-rat = monster(
  "Giant Rat",
  size: "Small", creature-type: "Beast", alignment: "Unaligned",
  ac: 12, hp: 7, hit-dice: "2d6", speed: "30 ft", cr: "1/8",
  abilities: (str: 7, dex: 15, con: 11, int: 2, wis: 10, cha: 4),
  senses: ("Darkvision 60 ft", "Passive Perception 10"),
  traits: (
    (name: "Keen Smell", desc: [The giant rat has Advantage on Wisdom (Perception) checks that rely on smell.]),
    (name: "Pack Tactics", desc: [The giant rat has Advantage on an attack roll against a creature if at least one of the rat's allies is within 5 ft of the creature and the ally isn't Incapacitated.]),
  ),
  actions: (
    (name: "Bite", desc: [_Melee Attack Roll:_ $+4$ to hit, reach 5 ft. _Hit:_ $4$ ($1d 4 + 2$) Piercing damage.]),
  ),
)

#let mastiff = monster(
  "Mastiff",
  size: "Medium", creature-type: "Beast", alignment: "Unaligned",
  ac: 12, hp: 5, hit-dice: "1d8 + 1", speed: "40 ft", cr: "1/8",
  abilities: (str: 13, dex: 14, con: 12, int: 3, wis: 12, cha: 7),
  skills: (perception: 5),
  senses: ("Darkvision 60 ft", "Passive Perception 15"),
  actions: (
    (name: "Bite", desc: [_Melee Attack Roll:_ $+3$, reach 5 ft. _Hit:_ $4$ ($1d 6 + 1$) Piercing damage. If the target is a Medium or smaller creature, it has the Prone condition.]),
  ),
)

#let venomous-snake = monster(
  "Venomous Snake",
  size: "Tiny", creature-type: "Beast", alignment: "Unaligned",
  ac: 12, hp: 5, hit-dice: "2d4", speed: "30 ft, swim 30 ft", cr: "1/8",
  abilities: (str: 2, dex: 15, con: 11, int: 1, wis: 10, cha: 3),
  senses: ("Blindsight 10 ft", "Passive Perception 10"),
  actions: (
    (name: "Bite", desc: [_Melee Attack Roll:_ $+4$, reach 5 ft. _Hit:_ $4$ ($1d 4 + 2$) Piercing damage plus $3$ ($1d 6$) Poison damage.]),
  ),
)
#let poisonous-snake = venomous-snake

// --- CR 1/4 -----------------------------------------------------------------

#let boar = monster(
  "Boar",
  size: "Medium", creature-type: "Beast", alignment: "Unaligned",
  ac: 11, hp: 13, hit-dice: "2d8 + 4", speed: "40 ft", cr: "1/4",
  abilities: (str: 13, dex: 11, con: 14, int: 2, wis: 9, cha: 5),
  senses: ("Passive Perception 9",),
  traits: (
    (name: "Bloodied Fury", desc: [While Bloodied, the boar has Advantage on attack rolls.]),
  ),
  actions: (
    (name: "Gore", desc: [_Melee Attack Roll:_ $+3$, reach 5 ft. _Hit:_ $4$ ($1d 6 + 1$) Piercing damage. If the target is Medium or smaller and the boar moved 20+ ft straight toward it immediately before the hit, the target takes an extra $3$ ($1d 6$) Piercing damage and has the Prone condition.]),
  ),
)

#let constrictor-snake = monster(
  "Constrictor Snake",
  size: "Large", creature-type: "Beast", alignment: "Unaligned",
  ac: 13, hp: 13, hit-dice: "2d10 + 2", speed: "30 ft, swim 30 ft", cr: "1/4",
  abilities: (str: 15, dex: 14, con: 12, int: 1, wis: 10, cha: 3),
  skills: (perception: 2, stealth: 4),
  senses: ("Blindsight 10 ft", "Passive Perception 12"),
  actions: (
    (name: "Bite", desc: [_Melee Attack Roll:_ $+4$, reach 5 ft. _Hit:_ $6$ ($1d 8 + 2$) Piercing damage.]),
    (name: "Constrict", desc: [_Strength Saving Throw:_ DC 12, one Medium or smaller creature within 5 ft. _Failure:_ $7$ ($3d 4$) Bludgeoning damage, and the target has the Grappled condition (escape DC 12).]),
  ),
)

#let giant-badger = monster(
  "Giant Badger",
  size: "Medium", creature-type: "Beast", alignment: "Unaligned",
  ac: 13, hp: 15, hit-dice: "2d8 + 6", speed: "30 ft, burrow 10 ft", cr: "1/4",
  abilities: (str: 13, dex: 10, con: 17, int: 2, wis: 12, cha: 5),
  skills: (perception: 3),
  resistances: ("Poison",),
  senses: ("Darkvision 60 ft", "Passive Perception 13"),
  actions: (
    (name: "Bite", desc: [_Melee Attack Roll:_ $+3$, reach 5 ft. _Hit:_ $6$ ($2d 4 + 1$) Piercing damage.]),
  ),
)

#let giant-frog = monster(
  "Giant Frog",
  size: "Medium", creature-type: "Beast", alignment: "Unaligned",
  ac: 11, hp: 18, hit-dice: "4d8", speed: "30 ft, swim 30 ft", cr: "1/4",
  abilities: (str: 12, dex: 13, con: 11, int: 2, wis: 10, cha: 3),
  skills: (perception: 2, stealth: 4),
  senses: ("Darkvision 30 ft", "Passive Perception 12"),
  traits: (
    (name: "Amphibious", desc: [The frog can breathe air and water.]),
    (name: "Standing Leap", desc: [The frog's Long Jump is up to 20 ft and High Jump is up to 10 ft with or without a running start.]),
  ),
  actions: (
    (name: "Bite", desc: [_Melee Attack Roll:_ $+3$, reach 5 ft. _Hit:_ $5$ ($1d 6 + 2$) Piercing damage. If the target is Medium or smaller, it has the Grappled condition (escape DC 11).]),
    (name: "Swallow", desc: [The frog swallows a Small or smaller target it is grappling. The swallowed target has the Blinded and Restrained conditions and Total Cover. Takes $5$ ($2d 4$) Acid damage at the end of the frog's next turn.]),
  ),
)

#let giant-owl = monster(
  "Giant Owl",
  size: "Large", creature-type: "Celestial", alignment: "Neutral",
  ac: 12, hp: 19, hit-dice: "3d10 + 3", speed: "5 ft, fly 60 ft", cr: "1/4",
  abilities: (str: 13, dex: 15, con: 12, int: 10, wis: 14, cha: 10),
  saves: (wis: 4),
  skills: (perception: 6, stealth: 6),
  resistances: ("Necrotic", "Radiant"),
  senses: ("Darkvision 120 ft", "Passive Perception 16"),
  languages: "Celestial; understands Common, Elvish, Sylvan",
  traits: (
    (name: "Flyby", desc: [The owl doesn't provoke an Opportunity Attack when it flies out of an enemy's reach.]),
  ),
  actions: (
    (name: "Talons", desc: [_Melee Attack Roll:_ $+4$, reach 5 ft. _Hit:_ $7$ ($1d 10 + 2$) Slashing damage.]),
    (name: "Spellcasting", desc: [Wisdom-based, no components. *At Will:* _Detect Evil and Good_, _Detect Magic_. *1/Day:* _Clairvoyance_.]),
  ),
)

#let giant-venomous-snake = monster(
  "Giant Venomous Snake",
  size: "Medium", creature-type: "Beast", alignment: "Unaligned",
  ac: 14, hp: 11, hit-dice: "2d8 + 2", speed: "40 ft, swim 40 ft", cr: "1/4",
  abilities: (str: 10, dex: 18, con: 13, int: 2, wis: 10, cha: 3),
  skills: (perception: 2),
  senses: ("Blindsight 10 ft", "Passive Perception 12"),
  actions: (
    (name: "Bite", desc: [_Melee Attack Roll:_ $+6$, reach 10 ft. _Hit:_ $6$ ($1d 4 + 4$) Piercing damage plus $4$ ($1d 8$) Poison damage.]),
  ),
)
#let giant-poisonous-snake = giant-venomous-snake

#let giant-wolf-spider = monster(
  "Giant Wolf Spider",
  size: "Medium", creature-type: "Beast", alignment: "Unaligned",
  ac: 13, hp: 11, hit-dice: "2d8 + 2", speed: "40 ft, climb 40 ft", cr: "1/4",
  abilities: (str: 12, dex: 16, con: 13, int: 3, wis: 12, cha: 4),
  skills: (perception: 3, stealth: 7),
  senses: ("Blindsight 10 ft", "Darkvision 60 ft", "Passive Perception 13"),
  traits: (
    (name: "Spider Climb", desc: [The spider can climb difficult surfaces, including along ceilings, without needing to make an ability check.]),
  ),
  actions: (
    (name: "Bite", desc: [_Melee Attack Roll:_ $+5$, reach 5 ft. _Hit:_ $5$ ($1d 4 + 3$) Piercing damage plus $5$ ($2d 4$) Poison damage.]),
  ),
)

#let panther = monster(
  "Panther",
  size: "Medium", creature-type: "Beast", alignment: "Unaligned",
  ac: 13, hp: 13, hit-dice: "3d8", speed: "50 ft, climb 40 ft", cr: "1/4",
  abilities: (str: 14, dex: 16, con: 10, int: 3, wis: 14, cha: 7),
  skills: (perception: 4, stealth: 7),
  senses: ("Darkvision 60 ft", "Passive Perception 14"),
  actions: (
    (name: "Rend", desc: [_Melee Attack Roll:_ $+5$, reach 5 ft. _Hit:_ $6$ ($1d 6 + 3$) Slashing damage.]),
  ),
  bonus-actions: (
    (name: "Nimble Escape", desc: [The panther takes the Disengage or Hide action.]),
  ),
)

#let riding-horse = monster(
  "Riding Horse",
  size: "Large", creature-type: "Beast", alignment: "Unaligned",
  ac: 11, hp: 13, hit-dice: "2d10 + 2", speed: "60 ft", cr: "1/4",
  abilities: (str: 16, dex: 13, con: 12, int: 2, wis: 11, cha: 7),
  senses: ("Passive Perception 10",),
  actions: (
    (name: "Hooves", desc: [_Melee Attack Roll:_ $+5$, reach 5 ft. _Hit:_ $7$ ($1d 8 + 3$) Bludgeoning damage.]),
  ),
)

#let wolf = monster(
  "Wolf",
  size: "Medium", creature-type: "Beast", alignment: "Unaligned",
  ac: 12, hp: 11, hit-dice: "2d8 + 2", speed: "40 ft", cr: "1/4",
  abilities: (str: 14, dex: 15, con: 12, int: 3, wis: 12, cha: 6),
  skills: (perception: 5, stealth: 4),
  senses: ("Darkvision 60 ft", "Passive Perception 15"),
  traits: (
    (name: "Pack Tactics", desc: [The wolf has Advantage on attack rolls against a creature if at least one of the wolf's allies is within 5 ft of the creature and the ally doesn't have the Incapacitated condition.]),
  ),
  actions: (
    (name: "Bite", desc: [_Melee Attack Roll:_ $+4$, reach 5 ft. _Hit:_ $5$ ($1d 6 + 2$) Piercing damage. If the target is Medium or smaller, it has the Prone condition.]),
  ),
)

// --- CR 1/2 -----------------------------------------------------------------

#let ape = monster(
  "Ape",
  size: "Medium", creature-type: "Beast", alignment: "Unaligned",
  ac: 12, hp: 19, hit-dice: "3d8 + 6", speed: "30 ft, climb 30 ft", cr: "1/2",
  abilities: (str: 16, dex: 14, con: 14, int: 6, wis: 12, cha: 7),
  skills: (athletics: 5, perception: 3),
  senses: ("Passive Perception 13",),
  actions: (
    (name: "Multiattack", desc: [The ape makes two Fist attacks.]),
    (name: "Fist", desc: [_Melee Attack Roll:_ $+5$, reach 5 ft. _Hit:_ $5$ ($1d 4 + 3$) Bludgeoning damage.]),
    (name: "Rock (Recharge 6)", desc: [_Ranged Attack Roll:_ $+5$, range 25/50 ft. _Hit:_ $10$ ($2d 6 + 3$) Bludgeoning damage.]),
  ),
)

#let black-bear = monster(
  "Black Bear",
  size: "Medium", creature-type: "Beast", alignment: "Unaligned",
  ac: 11, hp: 19, hit-dice: "3d8 + 6", speed: "30 ft, climb 30 ft, swim 30 ft", cr: "1/2",
  abilities: (str: 15, dex: 12, con: 14, int: 2, wis: 12, cha: 7),
  skills: (perception: 5),
  senses: ("Darkvision 60 ft", "Passive Perception 15"),
  actions: (
    (name: "Multiattack", desc: [The bear makes two Rend attacks.]),
    (name: "Rend", desc: [_Melee Attack Roll:_ $+4$, reach 5 ft. _Hit:_ $5$ ($1d 6 + 2$) Slashing damage.]),
  ),
)

#let crocodile = monster(
  "Crocodile",
  size: "Large", creature-type: "Beast", alignment: "Unaligned",
  ac: 12, hp: 13, hit-dice: "2d10 + 2", speed: "20 ft, swim 30 ft", cr: "1/2",
  abilities: (str: 15, dex: 10, con: 13, int: 2, wis: 10, cha: 5),
  saves: (con: 3),
  skills: (stealth: 2),
  senses: ("Passive Perception 10",),
  traits: (
    (name: "Hold Breath", desc: [The crocodile can hold its breath for 1 hour.]),
  ),
  actions: (
    (name: "Bite", desc: [_Melee Attack Roll:_ $+4$, reach 5 ft. _Hit:_ $6$ ($1d 8 + 2$) Piercing damage. If the target is Medium or smaller, it has the Grappled condition (escape DC 12) and Restrained condition.]),
  ),
)

#let giant-goat = monster(
  "Giant Goat",
  size: "Large", creature-type: "Beast", alignment: "Unaligned",
  ac: 11, hp: 19, hit-dice: "3d10 + 3", speed: "40 ft, climb 30 ft", cr: "1/2",
  abilities: (str: 17, dex: 13, con: 12, int: 3, wis: 12, cha: 6),
  saves: (str: 5),
  skills: (perception: 3),
  senses: ("Darkvision 60 ft", "Passive Perception 13"),
  actions: (
    (name: "Ram", desc: [_Melee Attack Roll:_ $+5$, reach 5 ft. _Hit:_ $6$ ($1d 6 + 3$) Bludgeoning damage. If the target is Large or smaller and the goat moved 20+ ft straight toward it immediately before the hit, the target takes an extra $5$ ($2d 4$) Bludgeoning damage and has the Prone condition.]),
  ),
)

#let warhorse = monster(
  "Warhorse",
  size: "Large", creature-type: "Beast", alignment: "Unaligned",
  ac: 11, hp: 19, hit-dice: "3d10 + 3", speed: "60 ft", cr: "1/2",
  abilities: (str: 18, dex: 12, con: 13, int: 2, wis: 12, cha: 7),
  saves: (wis: 3),
  senses: ("Passive Perception 11",),
  actions: (
    (name: "Hooves", desc: [_Melee Attack Roll:_ $+6$, reach 5 ft. _Hit:_ $9$ ($2d 4 + 4$) Bludgeoning damage. If the target is Large or smaller and the horse moved 20+ ft straight toward it immediately before the hit, the target takes an extra $5$ ($2d 4$) Bludgeoning damage and has the Prone condition.]),
  ),
)

// --- CR 1 -------------------------------------------------------------------

#let brown-bear = monster(
  "Brown Bear",
  size: "Large", creature-type: "Beast", alignment: "Unaligned",
  ac: 11, hp: 22, hit-dice: "3d10 + 6", speed: "40 ft, climb 30 ft", cr: "1",
  abilities: (str: 17, dex: 12, con: 15, int: 2, wis: 13, cha: 7),
  skills: (perception: 3),
  senses: ("Darkvision 60 ft", "Passive Perception 13"),
  actions: (
    (name: "Multiattack", desc: [The bear makes one Bite attack and one Claw attack.]),
    (name: "Bite", desc: [_Melee Attack Roll:_ $+5$, reach 5 ft. _Hit:_ $7$ ($1d 8 + 3$) Piercing damage.]),
    (name: "Claw", desc: [_Melee Attack Roll:_ $+5$, reach 5 ft. _Hit:_ $5$ ($1d 4 + 3$) Slashing damage. If the target is Large or smaller, it has the Prone condition.]),
  ),
)

#let dire-wolf = monster(
  "Dire Wolf",
  size: "Large", creature-type: "Beast", alignment: "Unaligned",
  ac: 14, hp: 22, hit-dice: "3d10 + 6", speed: "50 ft", cr: "1",
  abilities: (str: 17, dex: 15, con: 15, int: 3, wis: 12, cha: 7),
  skills: (perception: 5, stealth: 4),
  senses: ("Darkvision 60 ft", "Passive Perception 15"),
  traits: (
    (name: "Pack Tactics", desc: [The wolf has Advantage on attack rolls against a creature if at least one of the wolf's allies is within 5 ft of the creature and the ally doesn't have the Incapacitated condition.]),
  ),
  actions: (
    (name: "Bite", desc: [_Melee Attack Roll:_ $+5$, reach 5 ft. _Hit:_ $8$ ($1d 10 + 3$) Piercing damage. If the target is Large or smaller, it has the Prone condition.]),
  ),
)

#let giant-eagle = monster(
  "Giant Eagle",
  size: "Large", creature-type: "Celestial", alignment: "Neutral Good",
  ac: 13, hp: 26, hit-dice: "4d10 + 4", speed: "10 ft, fly 80 ft", cr: "1",
  abilities: (str: 16, dex: 17, con: 13, int: 8, wis: 14, cha: 10),
  skills: (perception: 6),
  resistances: ("Necrotic", "Radiant"),
  senses: ("Passive Perception 16",),
  languages: "Celestial; understands Common and Primordial (Auran)",
  actions: (
    (name: "Multiattack", desc: [The eagle makes two Rend attacks.]),
    (name: "Rend", desc: [_Melee Attack Roll:_ $+5$, reach 5 ft. _Hit:_ $5$ ($1d 4 + 3$) Slashing damage plus $3$ ($1d 6$) Radiant damage.]),
  ),
)

#let giant-hyena = monster(
  "Giant Hyena",
  size: "Large", creature-type: "Beast", alignment: "Unaligned",
  ac: 12, hp: 45, hit-dice: "6d10 + 12", speed: "50 ft", cr: "1",
  abilities: (str: 16, dex: 14, con: 14, int: 2, wis: 12, cha: 7),
  skills: (perception: 3),
  senses: ("Darkvision 60 ft", "Passive Perception 13"),
  actions: (
    (name: "Bite", desc: [_Melee Attack Roll:_ $+5$, reach 5 ft. _Hit:_ $10$ ($2d 6 + 3$) Piercing damage.]),
  ),
  bonus-actions: (
    (name: "Rampage (1/Day)", desc: [Immediately after dealing damage to a creature that was already Bloodied, the hyena can move up to half its Speed and make one Bite attack.]),
  ),
)

#let giant-spider = monster(
  "Giant Spider",
  size: "Large", creature-type: "Beast", alignment: "Unaligned",
  ac: 14, hp: 26, hit-dice: "4d10 + 4", speed: "30 ft, climb 30 ft", cr: "1",
  abilities: (str: 14, dex: 16, con: 12, int: 2, wis: 11, cha: 4),
  skills: (perception: 4, stealth: 7),
  senses: ("Darkvision 60 ft", "Passive Perception 14"),
  traits: (
    (name: "Spider Climb", desc: [The spider can climb difficult surfaces, including along ceilings, without needing to make an ability check.]),
    (name: "Web Walker", desc: [The spider ignores movement restrictions caused by webs, and knows the location of any other creature in contact with the same web.]),
  ),
  actions: (
    (name: "Bite", desc: [_Melee Attack Roll:_ $+5$, reach 5 ft. _Hit:_ $7$ ($1d 8 + 3$) Piercing damage plus $7$ ($2d 6$) Poison damage.]),
    (name: "Web (Recharge 5–6)", desc: [_Dexterity Saving Throw:_ DC 13, one creature within 60 ft. _Failure:_ The target has the Restrained condition until the web is destroyed (AC 10; HP 5; Vulnerability to Fire; Immunity to Poison/Psychic).]),
  ),
)

#let lion = monster(
  "Lion",
  size: "Large", creature-type: "Beast", alignment: "Unaligned",
  ac: 12, hp: 22, hit-dice: "4d10", speed: "50 ft", cr: "1",
  abilities: (str: 17, dex: 15, con: 11, int: 3, wis: 12, cha: 8),
  skills: (perception: 3, stealth: 4),
  senses: ("Darkvision 60 ft", "Passive Perception 13"),
  traits: (
    (name: "Pack Tactics", desc: [The lion has Advantage on attack rolls against a creature if at least one of the lion's allies is within 5 ft of the creature and the ally doesn't have the Incapacitated condition.]),
    (name: "Running Leap", desc: [With a 10-foot running start, the lion can Long Jump up to 25 ft.]),
  ),
  actions: (
    (name: "Multiattack", desc: [The lion makes two Rend attacks, or replaces one attack with Roar.]),
    (name: "Rend", desc: [_Melee Attack Roll:_ $+5$, reach 5 ft. _Hit:_ $7$ ($1d 8 + 3$) Slashing damage.]),
    (name: "Roar", desc: [_Wisdom Saving Throw:_ DC 11, one creature within 15 ft. _Failure:_ The target has the Frightened condition until the start of the lion's next turn.]),
  ),
)

#let tiger = monster(
  "Tiger",
  size: "Large", creature-type: "Beast", alignment: "Unaligned",
  ac: 13, hp: 30, hit-dice: "4d10 + 8", speed: "40 ft", cr: "1",
  abilities: (str: 17, dex: 16, con: 14, int: 3, wis: 12, cha: 8),
  skills: (perception: 3, stealth: 7),
  senses: ("Darkvision 60 ft", "Passive Perception 13"),
  actions: (
    (name: "Rend", desc: [_Melee Attack Roll:_ $+5$, reach 5 ft. _Hit:_ $10$ ($2d 6 + 3$) Slashing damage. If the target is Large or smaller, it has the Prone condition.]),
  ),
  bonus-actions: (
    (name: "Nimble Escape", desc: [The tiger takes the Disengage or Hide action.]),
  ),
)

// --- CR 2 -------------------------------------------------------------------

#let giant-constrictor-snake = monster(
  "Giant Constrictor Snake",
  size: "Huge", creature-type: "Beast", alignment: "Unaligned",
  ac: 12, hp: 60, hit-dice: "8d12 + 8", speed: "30 ft, swim 30 ft", cr: "2",
  abilities: (str: 19, dex: 14, con: 12, int: 1, wis: 10, cha: 3),
  skills: (perception: 2),
  senses: ("Blindsight 10 ft", "Passive Perception 12"),
  actions: (
    (name: "Multiattack", desc: [The snake makes one Bite attack and uses Constrict.]),
    (name: "Bite", desc: [_Melee Attack Roll:_ $+6$, reach 10 ft. _Hit:_ $11$ ($2d 6 + 4$) Piercing damage.]),
    (name: "Constrict", desc: [_Strength Saving Throw:_ DC 14, one Large or smaller creature within 10 ft. _Failure:_ $13$ ($2d 8 + 4$) Bludgeoning damage, and the target has the Grappled condition (escape DC 14).]),
  ),
)

#let polar-bear = monster(
  "Polar Bear",
  size: "Large", creature-type: "Beast", alignment: "Unaligned",
  ac: 12, hp: 42, hit-dice: "5d10 + 15", speed: "40 ft, swim 40 ft", cr: "2",
  abilities: (str: 20, dex: 14, con: 16, int: 2, wis: 13, cha: 7),
  skills: (perception: 5, stealth: 4),
  resistances: ("Cold",),
  senses: ("Darkvision 60 ft", "Passive Perception 15"),
  actions: (
    (name: "Multiattack", desc: [The bear makes two Rend attacks.]),
    (name: "Rend", desc: [_Melee Attack Roll:_ $+7$, reach 5 ft. _Hit:_ $9$ ($1d 8 + 5$) Slashing damage.]),
  ),
)

#let saber-toothed-tiger = monster(
  "Saber-Toothed Tiger",
  size: "Large", creature-type: "Beast", alignment: "Unaligned",
  ac: 13, hp: 52, hit-dice: "7d10 + 14", speed: "40 ft", cr: "2",
  abilities: (str: 18, dex: 17, con: 15, int: 3, wis: 12, cha: 8),
  saves: (str: 6, dex: 5),
  skills: (perception: 5, stealth: 7),
  senses: ("Darkvision 60 ft", "Passive Perception 15"),
  traits: (
    (name: "Running Leap", desc: [With a 10-foot running start, the tiger can Long Jump up to 25 ft.]),
  ),
  actions: (
    (name: "Multiattack", desc: [The tiger makes two Rend attacks.]),
    (name: "Rend", desc: [_Melee Attack Roll:_ $+6$, reach 5 ft. _Hit:_ $11$ ($2d 6 + 4$) Slashing damage.]),
  ),
  bonus-actions: (
    (name: "Nimble Escape", desc: [The tiger takes the Disengage or Hide action.]),
  ),
)
