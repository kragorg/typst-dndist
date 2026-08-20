// Resolution-engine tests. `assert`s fail compilation on regression.
//   typst compile --root . tests/resolve-test.typ
#import "@preview/dndist:1.0.0": *
#import "../src/resolve.typ": resolve-ac, resolve-abilities, _signed, _pick-tier, dedup-by
#import "../src/model.typ": feature as raw-feature
#import "../src/layout/common.typ": all-spells

// A weapon's attack lines. A weapon-attack cantrip's line (True Strike / Booming Blade / Shillelagh) keeps the weapon's own `name`, so `via` — the cantrip in `via-spell`, `none` for the plain attack — is what tells the two apart.
#let attack-lines(c, weapon, via: none) = c.attacks.filter(a =>
  a.name == weapon and a.at("via-spell", default: none) == via)

// --- Modifiers & proficiency bonus -----------------------------------------
#assert.eq(modifier(9), -1)
#assert.eq(modifier(7), -2)
#assert.eq(modifier(10), 0)
#assert.eq(modifier(16), 3)
#assert.eq(modifier(18), 4)
#assert.eq(modifier(20), 5)

#assert.eq(prof-bonus(1), 2)
#assert.eq(prof-bonus(4), 2)
#assert.eq(prof-bonus(5), 3)
#assert.eq(prof-bonus(11), 4)
#assert.eq(prof-bonus(20), 6)

// --- AC engine (scores with Dex 16 = +3 unless noted) ----------------------
#let s = (str: 10, dex: 16, con: 10, int: 10, wis: 10, cha: 10)
// Studded leather (12, light) + shield.
#assert.eq(resolve-ac(s, (eff-ac-base(12, cap: none), eff-ac-bonus(2))), 17)
// Mage Armor (13 + Dex) beats nothing-else + shield.
#assert.eq(resolve-ac(s, (eff-ac-formula(13, abilities: ("dex",)), eff-ac-bonus(2))), 18)
// Plate (18, heavy cap 0) ignores Dex, + shield.
#assert.eq(resolve-ac(s, (eff-ac-base(18, cap: 0), eff-ac-bonus(2))), 20)
// Half plate (15, medium cap 2).
#assert.eq(resolve-ac(s, (eff-ac-base(15, cap: 2),)), 17)
// Default unarmored when nothing applies.
#assert.eq(resolve-ac(s, ()), 13)
// Set forces an exact value.
#assert.eq(resolve-ac(s, (eff-ac-set(17),)), 17)
// Barbarian Unarmored Defense 10 + Dex + Con (Dex 14, Con 16).
#let sb = (str: 14, dex: 14, con: 16, int: 10, wis: 10, cha: 10)
#assert.eq(resolve-ac(sb, (eff-ac-formula(10, abilities: ("dex", "con")),)), 15)

// --- Ability resolution ----------------------------------------------------
#assert.eq(
  resolve-abilities((str: 10), (eff-ability("str", 2, kind: "background"), eff-ability("str", 1))).str,
  13,
)
#assert.eq(
  resolve-abilities((str: 10), (eff-ability("str", 2), eff-ability("str", 18, kind: "set"))).str,
  18,
)

// --- Full character: bard 4 (PB 2), Jack of All Trades ---------------------
#let elara = character(
  abilities: (str: 9, dex: 16, con: 12, int: 10, wis: 10, cha: 18),
  features: (
    class.bard(level: 4, skills: ("deception", "persuasion"), expertise: ("persuasion",)),
    item.studded-leather,
    item.shield,
  ),
)
#let r = resolve(elara)
#assert.eq(r.level, 4)
#assert.eq(r.proficiency-bonus, 2)
#assert.eq(r.ac, 17)
#assert.eq(r.ability-mods.cha, 4)
#assert.eq(r.skills.persuasion.bonus, 8)
#assert.eq(r.skills.deception.bonus, 6)
#assert.eq(r.skills.arcana.bonus, 1)
#assert.eq(r.passives.perception, 11)
#assert.eq(r.saves.cha.bonus, 6)
#assert.eq(r.saves.dex.bonus, 5)
#assert.eq(r.saves.str.bonus, -1)
// Universal unarmed strike: always present, always proficient (Str -1 + PB 2).
#let punch = r.attacks.find(a => a.name == "Unarmed Strike")
#assert.eq(punch.bonus, 1)
#assert.eq(punch.damage, "1-1")
#assert.eq(punch.damage-type, "Bludgeoning")

// --- Full character: rogue 11, expertise + Reliable Talent -----------------
#let sneak = character(
  abilities: (str: 10, dex: 16, con: 10, int: 14, wis: 10, cha: 10),
  features: (class.rogue(level: 11, skills: ("stealth",), expertise: ("stealth",)),),
)
#let rr = resolve(sneak)
#assert.eq(rr.proficiency-bonus, 4)
#assert.eq(rr.skills.stealth.bonus, 11)
#assert(rr.skills.stealth.reliable)
#assert.eq(rr.skills.arcana.bonus, 2)
#assert.eq(rr.skills.arcana.reliable, false)

// --- Background object: ability increases + granted proficiencies ----------
// Entertainer (+2 Cha, +1 Dex) applied to base scores; grants Acrobatics &
// Performance proficiency, a Musical Instrument, and the Musician origin feat.
#let bg-char = character(
  abilities: (str: 9, dex: 15, con: 12, int: 10, wis: 10, cha: 16),
  features: (
    background.entertainer("cha", "dex"),
    class.bard(level: 4),
  ),
)
#let rb = resolve(bg-char)
#assert.eq(rb.abilities.cha, 18)
#assert.eq(rb.abilities.dex, 16)
#assert.eq(rb.background, "Entertainer")
#assert.eq(rb.skills.acrobatics.level, "proficient")
#assert.eq(rb.skills.performance.level, "proficient")
#assert(rb.proficiencies.tool.contains("musical-instrument"))
// JoAT (a nested class feature on the Bard) still reaches non-proficient skills.
#assert.eq(rb.skills.arcana.bonus, 1)

// +1/+1/+1 spread when three abilities are chosen.
#let three = resolve(character(
  abilities: (str: 10, dex: 10, con: 10, int: 10, wis: 10, cha: 10),
  features: (background.entertainer("dex", "wis", "cha"),),
))
#assert.eq(three.abilities.dex, 11)
#assert.eq(three.abilities.wis, 11)
#assert.eq(three.abilities.cha, 11)

// --- Conditional save advantages (display-only, collected flat) ------------
// The Bugbear's Fey Ancestry emits one save-advantage from a nested species trait; display-only, it leaves the save numbers untouched.
#let bug = resolve(character(
  abilities: (str: 10, dex: 10, con: 10, int: 10, wis: 10, cha: 10),
  features: (species.bugbear(),),
))
#assert.eq(bug.save-advantages.len(), 1)
#assert.eq(bug.save-advantages.first().source, "Fey Ancestry")
#assert.eq(bug.saves.wis.bonus, 0)

// A second, character-level source stacks into the flat list.
#let bug2 = resolve(character(
  abilities: (str: 10, dex: 10, con: 10, int: 10, wis: 10, cha: 10),
  features: (species.bugbear(),),
  effects: (eff-save-advantage([on Constitution saves to maintain concentration], source: "War Caster"),),
))
#assert.eq(bug2.save-advantages.len(), 2)
#assert(bug2.save-advantages.map(a => a.source).contains("War Caster"))

// --- Senses (display-only, deduped by name, longest range wins) ------------
// The Bugbear's Darkvision trait emits a sense effect.
#assert.eq(bug.senses.len(), 1)
#assert.eq(bug.senses.first().name, "Darkvision")
#assert.eq(bug.senses.first().range, "60 ft")

// Same-named senses merge: the longer range wins (here a character-level Darkvision 120 ft supersedes the Bugbear's 60 ft), and a distinct sense adds.
#let sen = resolve(character(
  abilities: (str: 10, dex: 10, con: 10, int: 10, wis: 10, cha: 10),
  features: (species.bugbear(),),
  effects: (
    eff-sense("Darkvision", range: "120 ft", source: "Item"),
    eff-sense("Blindsight", range: "30 ft", source: "Item"),
  ),
))
#assert.eq(sen.senses.len(), 2)
#assert.eq(sen.senses.filter(s => s.name == "Darkvision").first().range, "120 ft")
#assert(sen.senses.map(s => s.name).contains("Blindsight"))

// --- Damage responses (display-only, deduped by kind+type) -----------------
#let res = resolve(character(
  abilities: (str: 10, dex: 10, con: 10, int: 10, wis: 10, cha: 10),
  effects: (
    eff-resistance("Fire"),
    eff-resistance("Fire", source: "Ring"),        // dup (same kind+type) — collapses
    eff-resistance("Poison", kind: "immunity"),
  ),
))
#assert.eq(res.resistances.len(), 2)
#assert.eq(res.resistances.filter(r => r.kind == "resistance").first().type, "Fire")
#assert.eq(res.resistances.filter(r => r.kind == "immunity").first().type, "Poison")

// Skill objects and string ids are interchangeable in proficiency grants.
#let obj = resolve(character(
  abilities: (dex: 14, str: 10, con: 10, int: 10, wis: 10, cha: 10),
  features: (class.rogue(level: 1, skills: (skill.stealth,)),),
))
#assert.eq(obj.skills.stealth.level, "proficient")

// --- Subclass object contributes proficiencies + named sub-features --------
#let lore-bard = character(
  abilities: (str: 10, dex: 12, con: 12, int: 14, wis: 10, cha: 16),
  features: (
    class.bard(level: 3, subclass: subclass.bard.lore(skill.arcana, skill.history, skill.nature)),
  ),
)
#let rl = resolve(lore-bard)
#assert.eq(rl.classes.first().subclass, "College of Lore")
#assert.eq(rl.skills.arcana.level, "proficient")
#assert.eq(rl.skills.history.level, "proficient")
#assert(rl.traits.map(t => t.name).contains("Cutting Words"))

// Glamour subclass attaches its named level-3 feature, and Beguiling Magic's
// always-prepared Charm Person / Mirror Image fold into the *Bard* spellcasting
// source (a subclass never emits its own eff-spellcasting — no phantom row).
#let glam = resolve(character(
  abilities: (cha: 16),
  features: (class.bard(level: 4, subclass: subclass.bard.glamour),),
))
#assert(glam.traits.map(t => t.name).contains("Mantle of Inspiration"))
#assert.eq(glam.spellcasting.len(), 1)
#let glam-spells = glam.spellcasting.first().spells
#assert(glam-spells.contains("Charm Person"))
#assert(glam-spells.contains("Mirror Image"))
#assert.eq(glam.item-spells.len(), 0)

// --- Abilities as objects (interchangeable with string ids) ----------------
// Background choices given as ability objects apply the same as strings.
#let via-obj = resolve(character(
  abilities: (cha: 16, dex: 15),
  features: (background.entertainer(ability.cha, ability.dex),),
))
#assert.eq(via-obj.abilities.cha, 18)
#assert.eq(via-obj.abilities.dex, 16)

// Barbarian Unarmored Defense (10 + Dex + Con) wired with ability objects.
#let barb = resolve(character(
  abilities: (str: 14, dex: 14, con: 16, int: 10, wis: 10, cha: 8),
  features: (class.barbarian(level: 1),),
))
#assert.eq(barb.ac, 15)

// --- Sage background + Magic Initiate (Wizard): spellcasting source ---------
#let sage-char = character(
  abilities: (str: 8, dex: 14, con: 13, int: 14, wis: 12, cha: 10),
  features: (
    background.sage(
      ability.int, ability.con,
      origin-feat: feat.magic-initiate(
        "Wizard",
        cantrips: (spell.fire-bolt, spell.mage-hand),
        spell: spell.detect-magic,
      ),
    ),
    class.wizard(level: 1),
  ),
)
#let rs = resolve(sage-char)
#assert.eq(rs.abilities.int, 16)
#assert.eq(rs.abilities.con, 14)
#assert.eq(rs.skills.arcana.level, "proficient")
#assert.eq(rs.skills.history.level, "proficient")
#assert(rs.proficiencies.tool.contains("calligraphers-supplies"))
#assert.eq(rs.spellcasting.len(), 1)
#let sc = rs.spellcasting.first()
#assert.eq(sc.source, "Magic Initiate (Wizard)")
#assert.eq(sc.ability, "int")
#assert.eq(sc.save-dc, 13)
#assert.eq(sc.attack, 5)
#assert(sc.cantrips.contains("Fire Bolt"))
#assert(sc.cantrips.contains("Mage Hand"))
#assert(sc.spells.contains("Detect Magic"))
// The catalog spell is feat-free: a caster without Telekinetic reads the catalog note unchanged.
#assert.eq(sc.spells-detail.find(s => s.name == "Mage Hand").notes, spell.mage-hand.notes)

// --- Goro: Tortle Druid 1, Sage, Magic Initiate (Wizard) -------------------
// Exercises Natural Armor, a full-caster class (slots), Primal Order Magician
// (Wis to Arcana/Nature), weapons/attacks, and two spellcasting sources.
#let goro = character(
  name: "Goro",
  alignment: "NN",
  max-hp: 11,
  abilities: (str: 8, dex: 10, con: 15, int: 14, wis: 15, cha: 8),
  features: (
    species.tortle(size: "Small", skill: skill.perception),
    background.sage(
      ability.wis, ability.con,
      origin-feat: feat.magic-initiate(
        "Wizard",
        casting-ability: ability.wis,
        cantrips: (spell.mind-sliver, spell.true-strike),
        spell: spell.shield,
      ),
    ),
    class.druid(
      level: 1,
      skills: (skill.insight, skill.nature),
      cantrips: (spell.produce-flame, spell.shape-water, spell.guidance),
      prepared: (spell.detect-magic, spell.entangle, spell.faerie-fire, spell.healing-word),
    ),
    weapon.crossbow-light,
    weapon.quarterstaff,
    item.shield,
  ),
  effects: (eff-prof("language", "Primordial"),),
)
#let rg = resolve(goro)
#assert.eq(rg.level, 1)
#assert.eq(rg.proficiency-bonus, 2)
#assert.eq(rg.abilities.wis, 17)
#assert.eq(rg.abilities.con, 16)
#assert.eq(rg.ac, 19)
#assert.eq(rg.max-hp, 11)
#assert.eq(rg.initiative, 0)
#assert.eq(rg.speed, 30)
#assert.eq(rg.size, "Small")
#assert.eq(rg.creature-type, "Humanoid")
#assert.eq(rg.saves.int.bonus, 4)
#assert.eq(rg.saves.wis.bonus, 5)
#assert.eq(rg.skills.arcana.bonus, 7)
#assert.eq(rg.skills.nature.bonus, 7)
#assert.eq(rg.skills.history.bonus, 4)
#assert.eq(rg.skills.insight.bonus, 5)
#assert.eq(rg.skills.perception.bonus, 5)
#assert.eq(rg.skills.religion.bonus, 2)
#assert.eq(rg.passives.perception, 15)
#assert.eq(rg.passives.investigation, 12)
#assert.eq(rg.passives.insight, 15)
#assert(rg.proficiencies.tool.contains("herbalism-kit"))
#assert(rg.proficiencies.tool.contains("calligraphers-supplies"))
#assert(rg.proficiencies.language.contains("Druidic"))
#assert(rg.proficiencies.language.contains("Primordial"))
// Two Wisdom spellcasting sources at DC 13 / attack +5.
#assert.eq(rg.spellcasting.len(), 2)
#assert(rg.spellcasting.all(s => s.save-dc == 13 and s.attack == 5))
#let druid-src = rg.spellcasting.find(s => s.source == "Druid")
#assert.eq(druid-src.slots.at("1"), 2)
#assert(druid-src.spells.contains("Speak with Animals"))

// Per-spell detail carries the source's DC/attack for the HIT/SAVE column, plus
// the spell-attack flag, area of effect, and reaction trigger for the table.
#let flame = druid-src.spells-detail.find(s => s.name == "Produce Flame")
#assert(flame.attack)
#assert.eq(flame.attack-bonus, 5)
#let entangle = druid-src.spells-detail.find(s => s.name == "Entangle")
#assert.eq(entangle.save, "STR")
#assert.eq(entangle.save-dc, 13)
#assert.eq(entangle.area, (shape: "square", size: "20 ft"))
#let absorb = druid-src.spells-detail.find(s => s.name == "Entangle")
#assert(absorb.trigger == none)
// Healing Word: 2d4 + casting ability modifier (Wis +3).
#let hw = druid-src.spells-detail.find(s => s.name == "Healing Word")
#assert.eq(hw.damage, none)
#assert.eq(hw.healing, "2d4+3")
// Attacks: Crossbow +2 (1d8, Dex +0 suppressed), Quarterstaff +1 (1d6-1).
#let bow = attack-lines(rg, "Light Crossbow").first()
#assert.eq(bow.bonus, 2)
#assert.eq(bow.damage, "1d8")
// Goro knows True Strike, so every eligible weapon he's proficient with gains a Wis-based Radiant line. Level 1, so no extra Radiant dice yet (+1d6 arrives at level 5).
#let ts-bow = attack-lines(rg, "Light Crossbow", via: "True Strike").first()
#assert.eq(ts-bow.bonus, 5)
#assert.eq(ts-bow.damage, "1d8+3")
#assert.eq(ts-bow.damage-type, "Radiant")
#assert.eq(ts-bow.range, "80/320 ft")
#let ts-staff = attack-lines(rg, "Quarterstaff", via: "True Strike").first()
#assert.eq(ts-staff.bonus, 5)
#assert.eq(ts-staff.damage, "1d6+3")
#assert.eq(ts-staff.damage-type, "Radiant")
// The plain weapon lines are untouched (one each), and the unarmed strike — not a weapon worth 1 CP — gains no True Strike line.
#assert.eq(attack-lines(rg, "Light Crossbow").len(), 1)
#assert.eq(attack-lines(rg, "Quarterstaff").len(), 1)
#assert.eq(attack-lines(rg, "Unarmed Strike", via: "True Strike").len(), 0)

// A character without True Strike gets no such lines.
#let no-ts = resolve(character(
  abilities: (str: 10, dex: 10, con: 10, int: 10, wis: 10, cha: 10),
  features: (class.druid(level: 1), weapon.quarterstaff),
))
#assert.eq(no-ts.attacks.filter(a => a.at("via-spell", default: none) != none).len(), 0)

// Eligibility and proficiency gates: knowing True Strike, a proficient eligible weapon gains a line; a weapon flagged ineligible (worth < 1 CP) gains none, and one the character lacks proficiency with (martial, for a druid) gains none.
#let ts-gates = resolve(character(
  abilities: (str: 10, dex: 10, con: 10, int: 10, wis: 12, cha: 10),
  features: (class.druid(level: 1),),
  effects: (
    eff-spellcasting("Test", ability.wis, cantrips: (spell.true-strike,)),
    eff-weapon("Club", category: "simple", damage: "1d4"),
    eff-weapon("Phantom Dagger", category: "simple", damage: "1d8", true-strike: false),
    eff-weapon("Greatsword", category: "martial", damage: "2d6"),
  ),
))
#assert.eq(attack-lines(ts-gates, "Club", via: "True Strike").len(), 1)
#assert.eq(attack-lines(ts-gates, "Phantom Dagger", via: "True Strike").len(), 0)
#assert.eq(attack-lines(ts-gates, "Greatsword", via: "True Strike").len(), 0)
// A cantrip line still attacks with that weapon, so it carries the weapon's own reach and throw range.
#let ts-thrown = resolve(character(
  abilities: (str: 10, dex: 10, con: 10, int: 10, wis: 12, cha: 10),
  features: (class.druid(level: 1), weapon.dagger),
  effects: (eff-spellcasting("Test", ability.wis, cantrips: (spell.true-strike,)),),
))
#assert.eq(attack-lines(ts-thrown, "Dagger", via: "True Strike").first().range, "5 ft")
#assert.eq(attack-lines(ts-thrown, "Dagger", via: "True Strike").first().thrown-range, "20/60 ft")
// --- Shillelagh: the third weapon-attack cantrip ---------------------------
// The imbued weapon attacks with the spellcasting ability and a d8 die, and the damage type stays the weapon's own.
#let sh = resolve(character(
  abilities: (str: 8, dex: 10, con: 10, int: 10, wis: 16, cha: 10),
  features: (
    class.druid(level: 1, primal-order: class.primal-order-magician(spell.shillelagh)),
    weapon.quarterstaff,
    weapon.scimitar,
  ),
))
#let sh-staff = attack-lines(sh, "Quarterstaff", via: "Shillelagh").first()
#assert.eq(sh-staff.bonus, 5)
#assert.eq(sh-staff.damage, "1d8+3")
#assert.eq(sh-staff.damage-type, "Bludgeoning")
// Shillelagh is not an Extra Attack option, and it leaves the plain weapon line alone.
#assert.eq(sh-staff.extra-attack, false)
#assert.eq(attack-lines(sh, "Quarterstaff").first().damage, "1d6-1")
// Only a Club or a Quarterstaff is eligible; a scimitar gains no line.
#assert.eq(attack-lines(sh, "Scimitar", via: "Shillelagh").len(), 0)
// The cantrip's own SPELLS row makes no spell attack and shows no damage.
#let sh-row = sh.spellcasting.find(s => s.source == "Druid").spells-detail.find(s => s.name == "Shillelagh")
#assert.eq(sh-row.attack, false)
#assert.eq(sh-row.damage, none)
#assert.eq(sh-row.weapon-attack, true)

// The die grows with the caster's level: d8, then d10 at 5, d12 at 11, and 2d6 at 17.
#let sh-die-at(lv) = {
  let c = resolve(character(
    abilities: (str: 10, dex: 10, con: 10, int: 10, wis: 10, cha: 10),
    features: (
      class.druid(level: lv, primal-order: class.primal-order-magician(spell.shillelagh)),
      weapon.club,
    ),
  ))
  attack-lines(c, "Club", via: "Shillelagh").first().damage
}
#assert.eq(sh-die-at(4), "1d8")
#assert.eq(sh-die-at(5), "1d10")
#assert.eq(sh-die-at(11), "1d12")
#assert.eq(sh-die-at(17), "2d6")

// A character who does not know Shillelagh gets no such line.
#assert.eq(no-ts.attacks.filter(a => a.name.contains("Shillelagh")).len(), 0)

#let staff = rg.attacks.find(a => a.name == "Quarterstaff")
#assert.eq(staff.bonus, 1)
#assert.eq(staff.damage, "1d6-1")
// Goro (a druid) has no Weapon Mastery, so a weapon's mastery property is dropped from the displayed properties, and `mastery` stays none. (A trained mastery rides as its own `mastery` field, separate from `properties`.)
// Versatile leaves `properties` the same way; it rides as `versatile-damage` (the other grip's full damage) and `versatile-grip`. Goro wields the staff one-handed, so the alternative is its 1d8 two-handed die, at his same -1 Strength.
#assert(not staff.properties.contains("Versatile"))
#assert.eq(staff.versatile-damage, "1d8-1")
#assert.eq(staff.versatile-grip, "two-handed")
#assert(not staff.properties.contains("Topple"))
#assert(not bow.properties.contains("Slow"))
#assert.eq(staff.mastery, none)
#assert.eq(bow.mastery, none)

// A martial class with `mastery:` reveals the property for the named weapons only.
#let master = resolve(character(
  abilities: (str: 14, dex: 12, con: 12, int: 10, wis: 10, cha: 10),
  features: (
    class.fighter(level: 1, mastery: ("Dagger",)),
    weapon.dagger,       // mastery: Nick
    weapon.quarterstaff, // mastery: Topple — NOT mastered
  ),
))
#let m-dagger = master.attacks.find(a => a.name == "Dagger")
#let m-staff = master.attacks.find(a => a.name == "Quarterstaff")
#assert.eq(m-dagger.mastery, "Nick")
#assert(not m-dagger.properties.contains("Nick"))
#assert.eq(m-staff.mastery, none)
#assert.eq(m-staff.versatile-damage, "1d8+2")
// The `mastery:` choice also surfaces as a named class feature listing the
// chosen weapons (it carries the eff-weapon-mastery effect).
#assert(master.traits.any(t => t.name == "Weapon Mastery" and t.at("kind", default: none) == "class-feature"))
// Tortle Claws override the unarmed strike: 1d6 slashing, not 1 bludgeoning.
#let claws = rg.attacks.find(a => a.name == "Unarmed Strike")
#assert.eq(claws.bonus, 1)
#assert.eq(claws.damage, "1d6-1")
#assert.eq(claws.damage-type, "Slashing")
#assert.eq(rg.attacks.filter(a => a.name == "Unarmed Strike").len(), 1)

// --- two-handed(): the Versatile grip ---------------------------------------
// A Versatile weapon wielded in two hands rolls its second die. The grip holds
// for every line that attacks with that weapon, True Strike's included, and
// each line carries what the other grip deals — computed off the ability that
// line attacks with, so the True Strike line's alternative is Wisdom-based like
// its own damage. Str 16 (+3), Wis 18 (+4), PB +2, martial proficiency.
#let gripper = resolve(character(
  abilities: (str: 16, dex: 10, con: 12, int: 10, wis: 18, cha: 10),
  features: (
    class.fighter(level: 1, skills: (skill.athletics,)),
    feat.magic-initiate(
      "Wizard", casting-ability: ability.wis,
      cantrips: (spell.true-strike, spell.mind-sliver), spell: spell.shield,
    ),
    two-handed(weapon.longsword),
    weapon.battleaxe,
  ),
))
#let two-hand = attack-lines(gripper, "Longsword").first()
#assert.eq(two-hand.bonus, 5)
#assert.eq(two-hand.damage, "1d10+3")
#assert.eq(two-hand.versatile-damage, "1d8+3")
#assert.eq(two-hand.versatile-grip, "one-handed")
#assert(not two-hand.properties.contains("Versatile"))
// The Battleaxe beside it keeps the default grip, so its alternative is the two-handed die.
#let one-hand = attack-lines(gripper, "Battleaxe").first()
#assert.eq(one-hand.damage, "1d8+3")
#assert.eq(one-hand.versatile-damage, "1d10+3")
#assert.eq(one-hand.versatile-grip, "two-handed")
// True Strike swings the same sword: the grip's die, the cantrip's Radiant damage, and a Wisdom-based alternative.
#let ts-two-hand = attack-lines(gripper, "Longsword", via: "True Strike").first()
#assert.eq(ts-two-hand.damage, "1d10+4")
#assert.eq(ts-two-hand.damage-type, "Radiant")
#assert.eq(ts-two-hand.versatile-damage, "1d8+4")

// --- Horgra: Bugbear Rogue 4 (Phantom), Criminal, Alert + Crossbow Expert ----
// Exercises by-name martial-weapon proficiency, Weapon Mastery, Expertise, the
// Phantom sub-features, and Alert's Proficiency-Bonus Initiative.
#let horgra = resolve(character(
  name: "Horgra",
  alignment: "CN",
  max-hp: 31,
  abilities: (str: 10, dex: 15, con: 13, int: 10, wis: 14, cha: 10),
  features: (
    species.bugbear(),
    background.criminal(ability.dex, ability.con),
    class.rogue(
      level: 4,
      subclass: subclass.rogue.phantom(gained: skill.investigation),
      skills: (skill.acrobatics, skill.deception, skill.insight, skill.intimidation, skill.perception),
      expertise: (skill.perception, skill.stealth),
      mastery: ("Scimitar", "Hand Crossbow"),
      language: "Draconic",
    ),
    feat.crossbow-expert,
    weapon.hand-crossbow,
    weapon.scimitar,
    weapon.dagger,
    item.studded-leather,
  ),
  languages: ("Goblin",),
  effects: (eff-prof("tool", tool.poisoners-kit),),
))
#assert.eq(horgra.level, 4)
#assert.eq(horgra.proficiency-bonus, 2)
#assert.eq(horgra.abilities.dex, 18)
#assert.eq(horgra.abilities.con, 14)
#assert.eq(horgra.ac, 16)
#assert.eq(horgra.max-hp, 31)
#assert.eq(horgra.initiative, 6)
#assert.eq(horgra.size, "Medium")
#assert.eq(horgra.creature-type, "Humanoid")
#assert.eq(horgra.saves.dex.bonus, 6)
#assert.eq(horgra.saves.int.bonus, 2)
#assert.eq(horgra.saves.wis.bonus, 2)
#assert.eq(horgra.skills.stealth.bonus, 8)
#assert.eq(horgra.skills.stealth.level, "expertise")
#assert.eq(horgra.skills.perception.bonus, 6)
#assert.eq(horgra.skills.acrobatics.bonus, 6)
#assert.eq(horgra.skills.sleight-of-hand.bonus, 6)
#assert.eq(horgra.skills.investigation.level, "proficient")
#assert.eq(horgra.passives.perception, 16)
#assert.eq(horgra.passives.investigation, 12)
#assert.eq(horgra.passives.insight, 14)
#assert(horgra.proficiencies.language.contains("Goblin"))
#assert(horgra.proficiencies.language.contains("Thieves' Cant"))
#assert(horgra.proficiencies.language.contains("Draconic"))
#assert(horgra.proficiencies.tool.contains("thieves-tools"))
#assert(horgra.proficiencies.tool.contains("poisoners-kit"))
#assert(horgra.traits.map(t => t.name).contains("Wails from the Grave"))
#let horgra-wails = horgra.limited-uses.find(r => r.name == "Wails from the Grave")
#assert.eq(horgra-wails.uses, 4)
#assert.eq(horgra-wails.uses-label, "DEX mod")
#assert(horgra.traits.map(t => t.name).contains("Sneak Attack"))
// Activated abilities: Cunning Action/Steady Aim carry an activation tag +
// notes for the card deck's Bonus Action table; passive/triggered traits
// (Sneak Attack, Wails from the Grave — a Sneak Attack rider, not its own
// action) carry none.
#assert.eq(horgra.traits.find(t => t.name == "Cunning Action").activation, "Bonus Action")
#assert(horgra.traits.find(t => t.name == "Cunning Action").at("notes", default: none) != none)
#assert.eq(horgra.traits.find(t => t.name == "Steady Aim").activation, "Bonus Action")
#assert(horgra.traits.find(t => t.name == "Steady Aim").at("notes", default: none) != none)
#assert.eq(horgra.traits.find(t => t.name == "Sneak Attack").at("activation", default: none), none)
#assert.eq(horgra.traits.find(t => t.name == "Wails from the Grave").at("activation", default: none), none)
// Martial-finesse weapons are proficient by name → PB applies; mastery shown.
#let scim = horgra.attacks.find(a => a.name == "Scimitar")
#assert.eq(scim.bonus, 6)
#assert.eq(scim.damage, "1d6+4")
#assert.eq(scim.mastery, "Nick")
#assert.eq(scim.range, "10 ft")
#assert.eq(horgra.attacks.find(a => a.name == "Unarmed Strike").range, "10 ft")
#let hxbow = horgra.attacks.find(a => a.name == "Hand Crossbow")
#assert.eq(hxbow.bonus, 6)
#assert.eq(hxbow.damage, "1d6+4")
#assert.eq(hxbow.mastery, "Vex")
#assert.eq(hxbow.range, "30/120 ft")
// A Thrown melee weapon keeps its reach and its throw range apart: Long-Limbed
// extends the reach (5 → 10 ft) and leaves the throw range alone.
#let dagr = horgra.attacks.find(a => a.name == "Dagger")
#assert.eq(dagr.range, "10 ft")
#assert.eq(dagr.thrown-range, "20/60 ft")
#assert.eq(scim.thrown-range, none)
#assert.eq(hxbow.thrown-range, none)
// Horgra doesn't know True Strike, so no extra cantrip attack lines.
#assert.eq(horgra.attacks.filter(a => a.name.contains("True Strike")).len(), 0)

// --- Cunning Strike (2024 Rogue, level 5) -----------------------------------
#let cs-rogue = resolve(character(
  name: "Cunning Strike Test",
  abilities: (str: 10, dex: 18, con: 10, int: 10, wis: 10, cha: 10),
  features: (class.rogue(level: 5),),
))
#assert.eq(cs-rogue.proficiency-bonus, 3)
#assert.eq(cs-rogue.cunning-strikes.len(), 3)
#let cs-names = cs-rogue.cunning-strikes.map(cs => cs.name)
#assert(cs-names.contains("Poison"))
#assert(cs-names.contains("Trip"))
#assert(cs-names.contains("Withdraw"))
#let cs-poison = cs-rogue.cunning-strikes.find(cs => cs.name == "Poison")
#assert.eq(cs-poison.cost, "1d6")
#assert.eq(cs-poison.save-ability, "con")
#assert.eq(cs-poison.save-dc, 15)
#let cs-withdraw = cs-rogue.cunning-strikes.find(cs => cs.name == "Withdraw")
#assert.eq(cs-withdraw.save-ability, none)
#assert.eq(cs-withdraw.save-dc, 15)
#assert(cs-rogue.traits.map(t => t.name).contains("Cunning Strike"))
// Uncanny Dodge (2024 Rogue, level 5): a Reaction with both desc and notes,
// so it renders in the card deck's Features & Traits list *and* its Reaction
// table (see the card-partition note in CLAUDE.md).
#let ud = cs-rogue.traits.find(t => t.name == "Uncanny Dodge")
#assert.eq(ud.activation, "Reaction")
#assert(ud.at("desc", default: none) != none)
#assert(ud.at("notes", default: none) != none)

// Below level 5, no Cunning Strike options or Uncanny Dodge.
#let cs-rogue4 = resolve(character(
  abilities: (dex: 18,),
  features: (class.rogue(level: 4),),
))
#assert.eq(cs-rogue4.cunning-strikes.len(), 0)
#assert.eq(cs-rogue4.traits.map(t => t.name).contains("Uncanny Dodge"), false)

// Reliable Talent gates at level 7 (2024 Rogue).
#let rt6 = resolve(character(abilities: (dex: 10,), features: (class.rogue(level: 6),)))
#assert.eq(rt6.traits.map(t => t.name).contains("Reliable Talent"), false)
#let rt7 = resolve(character(abilities: (dex: 10,), features: (class.rogue(level: 7),)))
#assert(rt7.traits.map(t => t.name).contains("Reliable Talent"))

// --- Multiclass: classes fold into one character ---------------------------
// Fighter 1 / Wizard 9 — the resolver sums levels and derives one PB; each
// class stays a distinct entry (name, level, subclass, hit-die) for display.
#let mc = resolve(character(
  name: "Valda",
  abilities: (str: 14, dex: 12, con: 14, int: 16, wis: 10, cha: 8),
  features: (
    class.fighter(level: 1, skills: (skill.athletics,)),
    class.wizard(level: 9, subclass: "Evoker", skills: (skill.arcana,)),
  ),
))
#assert.eq(mc.level, 10)
#assert.eq(mc.proficiency-bonus, 4)
#assert.eq(mc.classes.len(), 2)
#let fig = mc.classes.find(c => c.name == "Fighter")
#let wiz = mc.classes.find(c => c.name == "Wizard")
#assert.eq(fig.level, 1)
#assert.eq(fig.at("subclass", default: none), none)
#assert.eq(wiz.level, 9)
#assert.eq(wiz.subclass, "Evoker")
#assert.eq(fig.hit-die, "d10")
#assert.eq(wiz.hit-die, "d6")

// --- Spell damage tiers + eff-spell-damage-bonus ----------------------------
// Warlock 4 (CHA 18, +4 mod) with Agonizing Blast: Eldritch Blast at level 4 shows 1 beam with the +4 Cha bonus.
#let kragor-test = character(
  abilities: (str: 10, dex: 16, con: 13, int: 8, wis: 10, cha: 18),
  features: (
    class.warlock(
      level: 4,
      cantrips: (spell.eldritch-blast, spell.mind-sliver),
      spells: (),
      // 3 invocations known at level 4; Agonizing Blast is the one under test.
      invocations: (
        invocation.agonizing-blast(spell.eldritch-blast),
        invocation.fiendish-vigor,
        invocation.eldritch-mind,
      ),
    ),
  ),
)
#let rk = resolve(kragor-test)
#let wk = rk.spellcasting.first()
#let eb = wk.spells-detail.find(s => s.name == "Eldritch Blast")
#assert.eq(eb.damage, "1d10+4")
#assert.eq(eb.damage-type, "Force")
#assert.eq(eb.damage-label, none)
// Eldritch Invocations nest under the class feature and flatten into traits.
#assert(rk.traits.any(t => t.name == "Agonizing Blast"))
#assert(rk.traits.any(t => t.name == "Fiendish Vigor"))
// The no-desc "Eldritch Invocations" container is present but renders no line
// (both layouts filter class-features to those with a desc).
#assert(rk.traits.any(t => t.name == "Eldritch Invocations" and t.at("desc", default: none) == none))

// Same character at level 5: two beams, doubled bonus.
#let kragor-5 = character(
  abilities: (str: 10, dex: 16, con: 13, int: 8, wis: 10, cha: 18),
  features: (
    class.warlock(
      level: 5,
      cantrips: (spell.eldritch-blast,),
      spells: (),
      // 5 invocations known at level 5; Agonizing Blast is the one under test.
      invocations: (
        invocation.agonizing-blast(spell.eldritch-blast),
        invocation.fiendish-vigor,
        invocation.eldritch-mind,
        invocation.thirsting-blade,
        invocation.pact-of-the-blade,
      ),
    ),
  ),
)
#let rk5 = resolve(kragor-5)
#let eb5 = rk5.spellcasting.first().spells-detail.find(s => s.name == "Eldritch Blast")
#assert.eq(eb5.damage, "1d10+4")
#assert.eq(eb5.damage-type, "Force")
#assert.eq(eb5.damage-label, "per beam")

// --- Pact of the Blade: melee + magic weapons use proficiency + Cha ----------
// Warlock 4 (Cha 18 → +4, Str/Dex +0, PB +2), no martial-weapon proficiency of its own (Warlocks get simple only). Pact of the Blade makes every melee weapon and every magic weapon proficient and Cha-based, regardless of category or the
// weapon's own default ability — but leaves a mundane martial *ranged* weapon
// (neither melee nor magic) untouched.
#let pact-char = resolve(character(
  abilities: (str: 10, dex: 10, con: 10, int: 8, wis: 10, cha: 18),
  features: (
    class.warlock(
      level: 4, cantrips: (spell.eldritch-blast,), spells: (),
      invocations: (invocation.pact-of-the-blade, invocation.fiendish-vigor, invocation.eldritch-mind),
    ),
    raw-feature("W1", kind: "weapon", source: "Test",
      effects: (eff-weapon("Greatsword", category: "martial", kind: "melee", damage: "2d6"),)),
    raw-feature("W2", kind: "weapon", source: "Test",
      effects: (eff-weapon("Longbow +1", category: "martial", kind: "ranged", damage: "1d8", bonus: 1),)),
    raw-feature("W3", kind: "weapon", source: "Test",
      effects: (eff-weapon("Shortbow", category: "martial", kind: "ranged", damage: "1d6"),)),
  ),
))
#let gs = pact-char.attacks.find(a => a.name == "Greatsword")
#assert.eq(gs.bonus, 6)
#assert.eq(gs.damage, "2d6+4")
#let lb = pact-char.attacks.find(a => a.name == "Longbow +1")
#assert.eq(lb.bonus, 7)
#assert.eq(lb.damage, "1d8+5")
#let sb = pact-char.attacks.find(a => a.name == "Shortbow")
#assert.eq(sb.bonus, 0)

// Mind Sliver at level 4 (no bonus): shows base tier → "1d6 Psychic".
#let ms = wk.spells-detail.find(s => s.name == "Mind Sliver")
#assert.eq(ms.damage, "1d6")
#assert.eq(ms.damage-type, "Psychic")
// A spell's school passes through to its detail entry unchanged (drives the
// card/letter's spell-school footnote — see `spell-school-notes`, common.typ).
#assert.eq(ms.school, "Enchantment")

// Fire Bolt at level 1 (no bonus, sage wizard): "1d10 Fire".
// At level 5 (same character promoted): "2d10 Fire".
// sage requires 2 cantrips for Magic Initiate; search all sources for Fire Bolt.
#let fb-char = character(
  abilities: (str: 8, dex: 14, con: 13, int: 14, wis: 12, cha: 10),
  features: (
    background.sage(
      ability.int, ability.con,
      origin-feat: feat.magic-initiate(
        "Wizard",
        cantrips: (spell.fire-bolt, spell.mage-hand),
        spell: spell.detect-magic,
      ),
    ),
    class.wizard(level: 1),
  ),
)
#let rfb = resolve(fb-char)
#let fb = rfb.spellcasting.map(s => s.spells-detail).flatten().find(s => s.name == "Fire Bolt")
#assert.eq(fb.damage, "1d10")
#assert.eq(fb.damage-type, "Fire")

#let fb5-char = character(
  abilities: (str: 8, dex: 14, con: 13, int: 14, wis: 12, cha: 10),
  features: (
    background.sage(
      ability.int, ability.con,
      origin-feat: feat.magic-initiate(
        "Wizard",
        cantrips: (spell.fire-bolt, spell.mage-hand),
        spell: spell.detect-magic,
      ),
    ),
    class.wizard(level: 5),
  ),
)
#let rfb5 = resolve(fb5-char)
#let fb5 = rfb5.spellcasting.map(s => s.spells-detail).flatten().find(s => s.name == "Fire Bolt")
#assert.eq(fb5.damage, "2d10")
#assert.eq(fb5.damage-type, "Fire")

// --- Extra Attack + beam count in spells-detail ------------------------------
// Fighter 1: no Extra Attack → attacks-per-action == 1.
#let f1 = resolve(character(
  abilities: (str: 16, dex: 12, con: 14, int: 10, wis: 10, cha: 8),
  features: (class.fighter(level: 1), weapon.dagger),
))
#assert.eq(f1.attacks-per-action, 1)

// Fighter 5: Extra Attack gives attacks-per-action 2.
#let f5 = resolve(character(
  abilities: (str: 16, dex: 12, con: 14, int: 10, wis: 10, cha: 8),
  features: (class.fighter(level: 5), weapon.dagger),
))
#assert.eq(f5.attacks-per-action, 2)

// Fighter 11: 3 attacks.
#let f11 = resolve(character(
  abilities: (str: 16, dex: 12, con: 14, int: 10, wis: 10, cha: 8),
  features: (class.fighter(level: 11), weapon.dagger),
))
#assert.eq(f11.attacks-per-action, 3)

// Barbarian 5: Extra Attack → 2.
#let b5 = resolve(character(
  abilities: (str: 16, dex: 12, con: 14, int: 10, wis: 10, cha: 8),
  features: (class.barbarian(level: 5),),
))
#assert.eq(b5.attacks-per-action, 2)

// Eldritch Blast at level 5 via Warlock: count == 2 (beam column annotation).
#let wb5 = resolve(character(
  abilities: (str: 10, dex: 14, con: 13, int: 8, wis: 10, cha: 16),
  features: (class.warlock(level: 5, cantrips: (spell.eldritch-blast,), spells: ()),),
))
#let eb-detail = wb5.spellcasting.first().spells-detail.find(s => s.name == "Eldritch Blast")
#assert.eq(eb-detail.count, 2)

// Eldritch Blast at level 4: count == none (only 1 beam, no annotation needed).
#let wb4 = resolve(character(
  abilities: (str: 10, dex: 14, con: 13, int: 8, wis: 10, cha: 16),
  features: (class.warlock(level: 4, cantrips: (spell.eldritch-blast,), spells: ()),),
))
#let eb4 = wb4.spellcasting.first().spells-detail.find(s => s.name == "Eldritch Blast")
#assert.eq(eb4.count, none)

// Fire Bolt never gets a count (single hit, not multi-beam).
#assert.eq(fb5.count, none)

// True Strike attack lines have extra-attack: false; regular weapon lines have true.
#let ts-line = attack-lines(rg, "Light Crossbow", via: "True Strike").first()
#assert.eq(ts-line.extra-attack, false)
#let reg-line = attack-lines(rg, "Light Crossbow").first()
#assert.eq(reg-line.extra-attack, true)

// --- Slot-level upcast scaling (prepared-at + slot-damage) -------------------

// Warlock 4: pact slots auto at level 2, prepared-at = 2 auto-derived.
// magic-missile (1st, slot-damage) at slot 2 → 4 darts "1d4+1 Force (per dart)".
#let wl-sc = resolve(character(
  abilities: (str: 10, dex: 14, con: 13, int: 8, wis: 10, cha: 16),
  features: (
    class.warlock(level: 4, cantrips: (), spells: (spell.magic-missile,)),
  ),
)).spellcasting.first()
#let mm-wl = wl-sc.spells-detail.find(s => s.name == "Magic Missile")
#assert.eq(mm-wl.count, 4)
#assert.eq(mm-wl.damage, "1d4+1")
#assert.eq(mm-wl.damage-type, "Force")
#assert.eq(mm-wl.damage-label, "per dart")

// spellfire-flare (1st, slot-damage, beam w/ multi-die-per-beam) at slot 2 →
// 2 blasts of 2d10 Radiant each — the beam dice-str now carries its own count
// ("2d10"), not a bare die needing a "1" prefix, so a >1-die-per-blast spell
// still shows the right per-blast expression (see resolve.typ's dice-str note).
#let sf-wl = resolve(character(
  abilities: (str: 10, dex: 14, con: 13, int: 8, wis: 10, cha: 16),
  features: (
    class.warlock(level: 4, cantrips: (), spells: (spell.spellfire-flare,)),
  ),
)).spellcasting.first().spells-detail.find(s => s.name == "Spellfire Flare")
#assert.eq(sf-wl.count, 2)
#assert.eq(sf-wl.damage, "2d10")
#assert.eq(sf-wl.damage-type, "Radiant")
#assert.eq(sf-wl.damage-label, "per blast")

// Base slot (1st): 1 blast → no beam count/label shown.
#let sf-base = resolve(character(
  abilities: (str: 10, dex: 10, con: 10, int: 16, wis: 10, cha: 10),
  features: (class.wizard(level: 3),),
  effects: (eff-spellcasting("Wizard", "int", spells: (spell.spellfire-flare,)),),
)).spellcasting.find(s => s.source == "Wizard").spells-detail.find(s => s.name == "Spellfire Flare")
#assert.eq(sf-base.count, none)
#assert.eq(sf-base.damage, "2d10")
#assert.eq(sf-base.damage-label, none)

// --- eff-spell-any-slot: Magic Initiate/Fey Touched fold into other slots ----
// Magic Initiate's granted 1st-level spell casts free once per Long Rest AND
// with any spell slot the character has (2024 PHB rule text) — declared
// directly, not nested in an invocation, to confirm the projection doesn't
// depend on how the feat is attached to the Warlock (a Warlock can take
// Magic Initiate/Fey Touched normally, not only via Lessons of the First Ones).
#let mi-direct = resolve(character(
  abilities: (str: 10, dex: 14, con: 13, int: 8, wis: 10, cha: 16),
  features: (
    class.warlock(level: 4, cantrips: (), spells: ()),
    feat.magic-initiate("Wizard", casting-ability: ability.cha,
      cantrips: (spell.shape-water, spell.guidance), spell: spell.spellfire-flare),
  ),
))
#let sf-free = mi-direct.spellcasting.find(s => s.source == "Magic Initiate (Wizard)").spells-detail.find(s => s.name == "Spellfire Flare")
#assert.eq(sf-free.cast-level, 1)
#assert.eq(sf-free.count, none)
// Pinned at its own level with no headroom: fixed-slot, so the layout's
// no-headroom heuristic (common.typ's `_spell-effect-cell`) drops the
// ▲/scaling prose entirely — the free cast can only ever be at 1st level,
// never a real upcast choice.
#assert.eq(sf-free.fixed-slot, true)
#let sf-pact = mi-direct.spellcasting.find(s => s.source == "Warlock").spells-detail.find(s => s.name == "Spellfire Flare")
#assert.eq(sf-pact.cast-level, 2)
#assert.eq(sf-pact.damage, "2d10")
#assert.eq(sf-pact.count, 2)
#assert.eq(sf-pact.damage-label, "per blast")
#assert.eq(sf-pact.fixed-slot, true)

// Same feat nested under an Eldritch Invocation (Lessons of the First Ones,
// the real Kragor placement) projects identically — the mechanism doesn't
// care how deeply the granting feat is nested.
#let mi-inv = resolve(character(
  abilities: (str: 10, dex: 14, con: 13, int: 8, wis: 10, cha: 16),
  features: (
    class.warlock(
      level: 4, cantrips: (), spells: (),
      invocations: (
        invocation.lessons-of-the-first-ones(
          feat.magic-initiate("Wizard", casting-ability: ability.cha,
            cantrips: (spell.shape-water, spell.guidance), spell: spell.spellfire-flare)),
        invocation.fiendish-vigor,
        invocation.eldritch-mind,
      ),
    ),
  ),
))
#let sf-pact-inv = mi-inv.spellcasting.find(s => s.source == "Warlock").spells-detail.find(s => s.name == "Spellfire Flare")
#assert.eq(sf-pact-inv.cast-level, 2)
#assert.eq(sf-pact-inv.count, 2)

// Fey Touched: both granted spells (Misty Step + the chosen spell) fold into
// the same other source, each pinned at that source's default slot level — a
// level-6 Warlock's pact level (3) rather than either spell's own base level
// (Misty Step is 2nd, Charm Person 1st), confirming the projection follows the
// host source, not the spell.
#let ft-wl = resolve(character(
  abilities: (str: 10, dex: 14, con: 13, int: 8, wis: 10, cha: 16),
  features: (
    class.warlock(level: 6, cantrips: (), spells: ()),
    feat.fey-touched(ability.cha, chosen-spell: spell.charm-person),
  ),
))
#let wl-src = ft-wl.spellcasting.find(s => s.source == "Warlock")
#assert.eq(wl-src.spells-detail.find(s => s.name == "Misty Step").cast-level, 3)
#assert.eq(wl-src.spells-detail.find(s => s.name == "Charm Person").cast-level, 3)
// The dedicated Fey Touched source keeps its own free-cast entries at base
// level (Misty Step is itself a 2nd-level spell).
#let ft-src = ft-wl.spellcasting.find(s => s.source == "Fey Touched")
#assert.eq(ft-src.spells-detail.find(s => s.name == "Misty Step").cast-level, 2)
#assert.eq(ft-src.spells-detail.find(s => s.name == "Misty Step").fixed-slot, true)
#assert.eq(ft-src.spells-detail.find(s => s.name == "Charm Person").fixed-slot, true)

// dissonant-whispers (1st, slot-damage) at slot 2 → 4d6 Psychic.
#let dw-wl = resolve(character(
  abilities: (str: 10, dex: 14, con: 13, int: 8, wis: 10, cha: 16),
  features: (
    class.warlock(level: 4, cantrips: (), spells: (spell.dissonant-whispers,)),
  ),
)).spellcasting.first().spells-detail.find(s => s.name == "Dissonant Whispers")
#assert.eq(dw-wl.damage, "4d6")
#assert.eq(dw-wl.damage-type, "Psychic")

// cloud-of-daggers (2nd) at slot 2 → base 4d4 Slashing.
#let cod-wl = resolve(character(
  abilities: (str: 10, dex: 14, con: 13, int: 8, wis: 10, cha: 16),
  features: (
    class.warlock(level: 4, cantrips: (), spells: (spell.cloud-of-daggers,)),
  ),
)).spellcasting.first().spells-detail.find(s => s.name == "Cloud of Daggers")
#assert.eq(cod-wl.damage, "4d4")
#assert.eq(cod-wl.damage-type, "Slashing")

// Wizard (no prepared-at): a bare magic-missile entry falls back to its own base level 1, so 3 darts.
#let wiz-mm = resolve(character(
  abilities: (str: 10, dex: 14, con: 13, int: 10, wis: 12, cha: 10),
  features: (class.wizard(level: 5),),
  effects: (eff-spellcasting("Wizard", "int", spells: (spell.magic-missile,)),),
)).spellcasting.find(s => s.source == "Wizard").spells-detail.find(s => s.name == "Magic Missile")
#assert.eq(wiz-mm.count, 3)
#assert.eq(wiz-mm.damage, "1d4+1")
#assert.eq(wiz-mm.damage-type, "Force")
#assert.eq(wiz-mm.damage-label, "per dart")

// Per-spell annotation (spell: s, slot: N) beats prepared-at source default.
// Warlock 4 (prepared-at: 2) but magic-missile overridden to slot 3 → 5 darts.
#let wl-override-mm = resolve(character(
  abilities: (str: 10, dex: 14, con: 13, int: 8, wis: 10, cha: 16),
  features: (
    class.warlock(level: 4, cantrips: (), spells: ((spell: spell.magic-missile, slot: 3),)),
  ),
)).spellcasting.first().spells-detail.find(s => s.name == "Magic Missile")
#assert.eq(wl-override-mm.count, 5)

// Cantrips use character level, separate from slot: eldritch-blast at level 5 gives 2 beams.
// Already tested above; confirm the slot param leaves cantrips alone.
#let eb-lvl5-slot-check = resolve(character(
  abilities: (str: 10, dex: 14, con: 13, int: 8, wis: 10, cha: 16),
  features: (class.warlock(level: 5, cantrips: (spell.eldritch-blast,), spells: ()),),
)).spellcasting.first().spells-detail.find(s => s.name == "Eldritch Blast")
#assert.eq(eb-lvl5-slot-check.count, 2)

// --- Finesse weapons: attack ability is the better of Str/Dex ----------------
// A Dex build swings a Finesse dagger off Dex; a Str build off Str — driven by the weapon's Finesse property, with no per-character wiring.
#let fin-dex = resolve(character(
  abilities: (str: 8, dex: 16, con: 10, int: 10, wis: 10, cha: 10),
  features: (class.rogue(level: 1), weapon.dagger),   // simple → proficient
))
#let fd = fin-dex.attacks.find(a => a.name == "Dagger")
#assert.eq(fd.bonus, 5)
#assert.eq(fd.damage, "1d4+3")
#let fin-str = resolve(character(
  abilities: (str: 16, dex: 10, con: 10, int: 10, wis: 10, cha: 10),
  features: (class.fighter(level: 1), weapon.dagger),
))
#let fs = fin-str.attacks.find(a => a.name == "Dagger")
#assert.eq(fs.bonus, 5)
#assert.eq(fs.damage, "1d4+3")
// Shortsword is martial: a sorcerer (simple only) lacks proficiency, so the attack bonus drops PB.
#let ss-sorc = resolve(character(
  abilities: (str: 8, dex: 16, con: 14, int: 8, wis: 10, cha: 16),
  features: (class.sorcerer(level: 1), weapon.shortsword),
))
#let ss = ss-sorc.attacks.find(a => a.name == "Shortsword")
#assert.eq(ss.bonus, 3)
#assert.eq(ss.damage, "1d6+3")

// --- Sorcerer: a Charisma full caster with full-caster slots ------------------
#let sorc = resolve(character(
  abilities: (str: 8, dex: 14, con: 14, int: 8, wis: 10, cha: 16),
  features: (
    class.sorcerer(level: 1, cantrips: (spell.sorcerous-burst,), spells: (spell.chromatic-orb,)),
  ),
))
#let ssc = sorc.spellcasting.find(s => s.source == "Sorcerer")
#assert.eq(ssc.ability, "cha")
#assert.eq(ssc.save-dc, 13)
#assert.eq(ssc.slots.at("1"), 2)
#let orb = ssc.spells-detail.find(s => s.name == "Chromatic Orb")
#assert.eq(orb.damage, "3d8")
#assert.eq(orb.damage-type, "Acid")
#let burst = ssc.spells-detail.find(s => s.name == "Sorcerous Burst")
#assert(burst.attack)
#assert.eq(burst.attack-bonus, 5)

// --- Fairy species: Small Fey with a Fairy Magic spellcasting source ----------
#let fae = resolve(character(
  abilities: (str: 8, dex: 15, con: 14, int: 8, wis: 10, cha: 15),
  features: (
    species.fairy(casting-ability: ability.cha),
    background.genie-touched(
      ability.cha, ability.dex,
      origin-feat: feat.magic-initiate(
        "Wizard",
        casting-ability: ability.cha,
        cantrips: (spell.message, spell.true-strike),
        spell: spell.mage-armor,
      ),
    ),
    class.sorcerer(level: 1, skills: (skill.arcana, skill.persuasion)),
  ),
))
#assert.eq(fae.size, "Small")
#assert.eq(fae.creature-type, "Fey")
#assert.eq(fae.abilities.cha, 17)
#assert.eq(fae.abilities.dex, 16)
#assert.eq(fae.ac, 13)
#assert.eq(fae.skills.deception.level, "proficient")
#assert.eq(fae.skills.perception.level, "proficient")
#assert(fae.proficiencies.tool.contains("glassblowers-tools"))
// Three Charisma sources (Fairy Magic, Magic Initiate, Sorcerer), all DC 13.
#assert.eq(fae.spellcasting.len(), 3)
#assert(fae.spellcasting.all(s => s.save-dc == 13))
#let fairy-src = fae.spellcasting.find(s => s.source == "Fairy Magic")
#assert(fairy-src.cantrips.contains("Druidcraft"))
// Magic Initiate's granted 1st-level spell is tracked as a free 1/Long Rest cast.
#assert(fae.limited-uses.any(r => r.name == "Mage Armor"))

// --- Limited-use resources -----------------------------------------------------
// An Orc Sorcerer 5 (PB 3): Adrenaline Rush (PB uses, Short-or-Long Rest) and
// Relentless Endurance (1, Long Rest) from the species, Innate Sorcery (2) from
// the class. Declaration order is preserved (species traits first).
#let lu = resolve(character(
  abilities: (str: 8, dex: 14, con: 14, int: 8, wis: 10, cha: 16),
  features: (
    species.orc(),
    class.sorcerer(level: 5, skills: (skill.arcana, skill.persuasion)),
  ),
))
#assert.eq(lu.limited-uses.len(), 4)
#let lu-ar = lu.limited-uses.find(r => r.name == "Adrenaline Rush")
#assert.eq(lu-ar.uses, 3)
#assert.eq(lu-ar.uses-label, "PB")
#assert.eq(lu-ar.recharge, "short-or-long")
#let lu-re = lu.limited-uses.find(r => r.name == "Relentless Endurance")
#assert.eq(lu-re.uses, 1)
#assert.eq(lu-re.recharge, "long")
#assert.eq(lu-re.uses-label, none)
#let lu-is = lu.limited-uses.find(r => r.name == "Innate Sorcery")
#assert.eq(lu-is.uses, 2)
// The eff-limited-use tracker above is orthogonal to the activation tag — a
// feature can carry both (a Resources row *and* a Bonus Action table row).
#assert.eq(lu.traits.find(t => t.name == "Adrenaline Rush").activation, "Bonus Action")
#assert.eq(lu.traits.find(t => t.name == "Innate Sorcery").activation, "Bonus Action")
#assert.eq(lu.traits.find(t => t.name == "Relentless Endurance").at("activation", default: none), none)
// `notes` may be a function of the same ctx as eff-limited-use's `uses`
// (pb/level/ability-mods) — the resolver evaluates it once, here to a THP
// count derived from PB 3 (level 5). Interpolate the expected value the same
// way (`#pb3`, not a literal `3`) so both sides build the same content
// sequence — a literal number in the markup produces a different node shape
// than an interpolated one, so `assert.eq` would spuriously fail otherwise.
#let pb3 = 3
#assert.eq(lu.traits.find(t => t.name == "Adrenaline Rush").notes, [Take the Dash action; gain #pb3 THP (#pb3/Short or Long Rest).])

// --- Metamagic (Sorcerer 2) --------------------------------------------------
// Font of Magic grants the Sorcery Points pool (level uses, Long Rest); the
// Metamagic parent nests the two chosen options, which flatten into traits.
#let mm = resolve(character(
  abilities: (str: 8, dex: 16, con: 14, int: 8, wis: 10, cha: 17),
  features: (
    class.sorcerer(
      level: 2,
      skills: (skill.arcana, skill.persuasion),
      cantrips: (spell.sorcerous-burst,),
      spells: (spell.chromatic-orb,),
      metamagic: (metamagic.empowered-spell, metamagic.seeking-spell),
    ),
  ),
))
#assert(mm.traits.any(t => t.name == "Font of Magic"))
#let mm-sp = mm.limited-uses.find(r => r.name == "Sorcery Points")
#assert.eq(mm-sp.uses, 2)
#assert.eq(mm-sp.recharge, "long")
#assert(mm.traits.any(t => t.name == "Metamagic"))
#let mm-emp = mm.traits.find(t => t.name == "Empowered Spell")
#assert(mm-emp.at("notes", default: none) != none)
#let mm-seek = mm.traits.find(t => t.name == "Seeking Spell")
#assert.eq(mm.metamagic.len(), 2)
#assert(mm.metamagic.any(m => m.name == "Empowered Spell"))
#assert(mm.metamagic.any(m => m.name == "Seeking Spell"))
#assert.eq(mm.metamagic.find(m => m.name == "Empowered Spell").at("cost", default: none), "1 SP")

// The level-5 Orc Sorcerer above also gains Sorcery Points from Font of Magic.
#let lu-sp = lu.limited-uses.find(r => r.name == "Sorcery Points")
#assert.eq(lu-sp.uses, 5)
#assert.eq(lu-sp.recharge, "long")

// A character with no limited-use feature yields an empty list.
#let lu-none = resolve(character(
  abilities: (str: 10, dex: 10, con: 10, int: 10, wis: 10, cha: 10),
  features: (species.human(),),
))
#assert.eq(lu-none.limited-uses.len(), 0)

// Wild Shape (2024 Druid, level 2) is a `long-short-regain` pool — regain all
// uses on a Long Rest and one on a Short Rest. It sorts into the Long Rest
// column (a Short Rest alone doesn't fully recharge it), not the Short Rest
// column, and is a Bonus Action activated feature (the card deck's Bonus
// Action table) carrying 2 uses at level 2. Wild Companion is a plain Magic
// action (Action) feature that borrows Wild Shape's pool or a spell slot, so it
// emits no eff-limited-use of its own.
#let goro2 = resolve(character(
  abilities: (str: 8, dex: 10, con: 15, int: 14, wis: 15, cha: 8),
  features: (species.tortle(size: "Small", skill: skill.perception),
    class.druid(level: 2, skills: (skill.insight, skill.nature),
      cantrips: (spell.produce-flame, spell.shape-water, spell.guidance),
      prepared: (spell.detect-magic, spell.entangle, spell.goodberry, spell.healing-word, spell.absorb-elements)),),
))
#let goro2-ws = goro2.limited-uses.find(u => u.name == "Wild Shape")
#assert.eq(goro2-ws.recharge, "long-short-regain")
#assert.eq(goro2-ws.uses, 2)
#assert.eq(goro2.traits.find(t => t.name == "Wild Shape").activation, "Bonus Action")
#let goro2-wc = goro2.traits.find(t => t.name == "Wild Companion")
#assert.eq(goro2-wc.activation, "Action")
#assert(not goro2.limited-uses.any(u => u.name == "Wild Companion"))
// A level-1 Druid has neither Wild Shape nor Wild Companion (level-gated).
#let goro1 = resolve(character(
  abilities: (str: 8, dex: 10, con: 15, int: 14, wis: 15, cha: 8),
  features: (class.druid(level: 1),),
))
#assert(not goro1.limited-uses.any(u => u.name == "Wild Shape"))
#assert(not goro1.traits.any(t => t.name == "Wild Companion"))

// --- Activated-ability parent/child splits -------------------------------------
// Shell Defense (Tortle): Action to enter, a nested "Emerge" trait Bonus Action
// to leave — each half keeps its own desc/notes so the letter sheet's Species
// Traits box (which lists every flattened trait independently) never repeats
// prose across the two.
#let sd = resolve(character(
  abilities: (str: 10, dex: 10, con: 10, int: 10, wis: 10, cha: 10),
  features: (species.tortle(),),
))
#assert.eq(sd.traits.find(t => t.name == "Shell Defense").activation, "Action")
#let sd-emerge = sd.traits.find(t => t.name == "Emerge")
#assert.eq(sd-emerge.activation, "Bonus Action")
#assert.eq(sd-emerge.kind, "trait")
#assert(sd-emerge.at("desc", default: none) != none)
#assert(sd-emerge.at("notes", default: none) != none)

// Telekinetic (feat): the Mage Hand grant stays passive; the nested
// "Telekinetic Shove" carries the Bonus Action tag, kind: "feat" so it still
// belongs to the letter's Feats box.
#let tk = resolve(character(
  abilities: (str: 10, dex: 10, con: 10, int: 10, wis: 10, cha: 14),
  features: (feat.telekinetic(ability.wis, casting-ability: ability.cha),),
))
#assert.eq(tk.traits.find(t => t.name == "Telekinetic").at("activation", default: none), none)
#let tk-shove = tk.traits.find(t => t.name == "Telekinetic Shove")
#assert.eq(tk-shove.activation, "Bonus Action")
#assert.eq(tk-shove.kind, "feat")
// The shove's save DC equals the "Telekinetic" spellcasting source's own save DC (12), computed the same way in both places.
// See the note above on why the expected value must also be interpolated.
#let tk-dc = 12
#assert.eq(tk-shove.notes, [Shove a creature 5 ft toward/away (STR #tk-dc save), range 30 ft.])
#assert.eq(tk.spellcasting.find(s => s.source == "Telekinetic").save-dc, 12)
// The feat's Mage Hand appends to the catalog note instead of restating it, so the two cannot drift.
// Its range and component changes carry no prose: the RANGE and COMP columns already show them.
#let tk-hand = tk.spellcasting.find(s => s.source == "Telekinetic").spells-detail.find(s => s.name == "Mage Hand")
#assert.eq(tk-hand.range, "60 ft")
#assert.eq(tk-hand.components, none)
#assert.eq(tk-hand.notes, [#spell.mage-hand.notes The hand can be Invisible.])

// Awakened Mind (Great Old One Warlock, level 3+): a subclass-feature with an
// activation tag, same as a class-feature/trait would carry.
#let gorlock = resolve(character(
  abilities: (str: 10, dex: 10, con: 10, int: 10, wis: 10, cha: 14),
  features: (class.warlock(level: 3, subclass: subclass.warlock.great-old-one),),
))
#let awakened = gorlock.traits.find(t => t.name == "Awakened Mind")
#assert(awakened != none)
#assert.eq(awakened.activation, "Bonus Action")
#assert.eq(awakened.kind, "subclass-feature")
// Great Old One Spells (level 3): the four level-3 rows of the table fold into
// the Pact Magic source; the level-5+ rows are still gated off.
#let goo-spells = gorlock.spellcasting.first().spells
#assert(goo-spells.contains("Detect Thoughts"))
#assert(goo-spells.contains("Tasha’s Hideous Laughter"))
#assert(not goo-spells.contains("Clairvoyance"))
#assert(not goo-spells.contains("Telekinesis"))
#assert.eq(gorlock.item-spells.len(), 0)

// --- Weapon-attack cantrips: Booming Blade + True Strike ---------------------
// A weapon-attack cantrip makes no *spell* attack of its own: its SPELLS-table row
// carries no HIT (attack: false) and no damage — the resolver expands it into a
// "<weapon> (<Spell>)" ATTACK line per weapon instead.
#let bb = resolve(character(
  abilities: (str: 16, dex: 10, con: 10, int: 10, wis: 10, cha: 10),
  features: (
    class.warlock(level: 1, cantrips: (spell.booming-blade, spell.eldritch-blast)),
    raw-feature("W1", kind: "weapon", source: "Test",
      effects: (eff-weapon("Longsword +1", category: "martial", kind: "melee", damage: "1d8", bonus: 1), eff-prof("weapon", "martial"))),
    raw-feature("W2", kind: "weapon", source: "Test",
      effects: (eff-weapon("Shortbow", category: "simple", kind: "ranged", damage: "1d6"),)),
  ),
))
// CANTRIPS row: no HIT of its own, no damage — just its rider note.
#let bb-detail = bb.spellcasting.first().spells-detail.find(s => s.name == "Booming Blade")
#assert.eq(bb-detail.attack, false)
#assert.eq(bb-detail.damage, none)
#assert(bb-detail.notes != none)
// Eldritch Blast stays a real spell attack (attack: true) with the +2 bonus.
#let eb-detail = bb.spellcasting.first().spells-detail.find(s => s.name == "Eldritch Blast")
#assert(eb-detail.attack)
#assert.eq(eb-detail.attack-bonus, 2)
// ATTACK expansion: the melee weapon gets a Booming Blade line with the same hit and damage as its normal attack plus a Notes rider; the ranged weapon gets none, and the line sits out of Extra Attack.
#let ls = attack-lines(bb, "Longsword +1").first()
#assert.eq(attack-lines(bb, "Longsword +1", via: "Booming Blade").len(), 1)
#let ls-bb = attack-lines(bb, "Longsword +1", via: "Booming Blade").first()
#assert.eq(ls-bb.bonus, ls.bonus)
#assert.eq(ls-bb.damage, ls.damage)
#assert.eq(ls-bb.bonus, 6)
#assert.eq(ls-bb.damage, "1d8+4")
#assert(ls-bb.at("note", default: none) != none)
#assert.eq(ls-bb.at("extra-attack", default: true), false)
#assert.eq(attack-lines(bb, "Shortbow", via: "Booming Blade").len(), 0)

// True Strike is also a weapon-attack cantrip: no HIT in its CANTRIPS row, but it
// still expands per proficient weapon (cast with the spell ability, Radiant).
#let ts = resolve(character(
  abilities: (str: 10, dex: 10, con: 10, int: 10, wis: 10, cha: 16),
  features: (
    class.warlock(level: 1, cantrips: (spell.true-strike,)),
    raw-feature("W", kind: "weapon", source: "Test",
      effects: (eff-weapon("Dagger", category: "simple", kind: "melee", damage: "1d4", properties: ("Finesse",)),)),
  ),
))
#let ts-detail = ts.spellcasting.first().spells-detail.find(s => s.name == "True Strike")
#assert.eq(ts-detail.attack, false)
#assert.eq(attack-lines(ts, "Dagger", via: "True Strike").len(), 1)
#let dag-ts = attack-lines(ts, "Dagger", via: "True Strike").first()
#assert.eq(dag-ts.damage-type, "Radiant")
#assert.eq(dag-ts.bonus, 5)

// --- Resolver string/collection helpers ------------------------------------
// `_signed`: the signed-modifier suffix — empty at zero, sign glyph otherwise.
#assert.eq(_signed(3), "+3")
#assert.eq(_signed(-2), "-2")
#assert.eq(_signed(0), "")

// `_pick-tier`: highest tier whose threshold ≤ level; the first tier applies
// below every threshold; a `none` level yields the fallback.
#let tiers = ((1, 1, "d10"), (5, 2, "d10"), (11, 3, "d10"))
#assert.eq(_pick-tier(tiers, 4), (1, 1, "d10"))
#assert.eq(_pick-tier(tiers, 5), (5, 2, "d10"))
#assert.eq(_pick-tier(tiers, 20), (11, 3, "d10"))
#assert.eq(_pick-tier(tiers, none), none)
#assert.eq(_pick-tier(tiers, none, fallback: tiers.first()), (1, 1, "d10"))

// `dedup-by`: first occurrence per key wins; order preserved.
#assert.eq(dedup-by(("a", "B", "A", "c"), k => lower(k)), ("a", "B", "c"))

// --- Kragor: Fighter 1 / Warlock 9 multiclass (new builder options) ---------
// Exercises the Fighter's Fighting Style + Second Wind, the multiclass Warlock's
// suppressed saves, Contact Patron folding Contact Other Plane, `magic-armor`,
// Lessons of the First Ones nesting the Tough feat, `asi()`, computed max HP
// (with Tough's level-scaled bonus), the Cloak of Protection's save bonus, the
// Rod of the Pact Keeper's scoped spellcasting bonus, and the auto-folded
// equipment list.
#let kragor = resolve(character(
  abilities: (str: 10, dex: 12, con: 14, int: 8, wis: 12, cha: 16),
  features: (
    species.orc(),
    class.fighter(level: 1, skills: (skill.persuasion, skill.perception),
      mastery: ("Battleaxe",), fighting-style: "Defense"),
    class.warlock(level: 9, subclass: subclass.warlock.great-old-one, saves: (),
      cantrips: (spell.eldritch-blast,), spells: (spell.suggestion,),
      invocations: (
        invocation.pact-of-the-tome(cantrips: (spell.guidance,), spells: (spell.detect-magic,)),
        invocation.agonizing-blast(spell.eldritch-blast),
        invocation.repelling-blast(spell.eldritch-blast),
        invocation.lessons-of-the-first-ones(feat.tough),
        invocation.eldritch-mind,
        invocation.one-with-shadows,
        invocation.visions-of-distant-realms,
      )),
    feat.telekinetic(ability.cha), // casting-ability defaults to the boosted Cha
    asi(ability.cha, 2),
    item.magic-armor("half-plate", bonus: 1, name: "Do-Maru Half Plate +1"),
    item.shield, item.cloak-of-protection,
    item.rod-of-the-pact-keeper(2),
  ),
  effects: (eff-ability(ability.dex, 2, kind: "background"), eff-ability(ability.cha, 1, kind: "background")),
  equipment: ("Bedroll",),
))
#assert.eq(kragor.level, 10)
#assert.eq(kragor.proficiency-bonus, 4)
#assert.eq(kragor.abilities.cha, 20)
// Computed max HP (no max-hp declared): Fighter d10 first level maxes the die, Warlock 9 levels of average, plus Con per level, plus Tough 2 per level.
#assert.eq(kragor.max-hp, 95)
// AC: Half Plate +1, capped Dex, shield, Cloak, Defense style.
#assert.eq(kragor.ac, 22)
// Multiclass Warlock grants no saves: only the starting Fighter's Str + Con.
#assert(kragor.saves.str.proficient and kragor.saves.con.proficient)
#assert(not kragor.saves.wis.proficient and not kragor.saves.cha.proficient)
// Cloak of Protection: +1 to every save, proficient or not.
#assert.eq(kragor.saves.str.bonus, 5)
#assert.eq(kragor.saves.cha.bonus, 6)
// Rod of the Pact Keeper +2 scopes to the Warlock source: its DC/attack gain
// the bonus; the Telekinetic feat's source keeps its own numbers.
#let kragor-pact = kragor.spellcasting.find(s => s.source == "Warlock")
#assert.eq(kragor-pact.save-dc, 19)
#assert.eq(kragor-pact.attack, 11)
#assert.eq(kragor-pact.modifier, 5)
#let kragor-tk = kragor.spellcasting.find(s => s.source == "Telekinetic")
#assert.eq(kragor-tk.save-dc, 17)
#assert.eq(kragor-tk.attack, 9)
// The rod's regain-a-slot power is a 1/Long-Rest pool.
#assert(kragor.limited-uses.any(u => u.name == "Regain Pact Slot"))
// Live gear lists as EQUIPPED (magic items starred, the mundane shield not);
// the declared strings stay INVENTORY. The split is semantic — equipped gear's
// effects are on the sheet, inventory is inert cargo.
#assert.eq(kragor.equipped, (
  "Do-Maru Half Plate +1*", "Shield", "Cloak of Protection*",
  "Rod of the Pact Keeper +2*",
))
#assert.eq(kragor.equipment, ("Bedroll",))
#assert(kragor.traits.any(t => t.name == "Second Wind"))
// Second Wind is a `long-short-regain` pool (2024 Fighter): regain all uses on a
// Long Rest and one on a Short Rest, so it sorts into the Long Rest column with
// a footnote (not the Short Rest column — a Short Rest alone doesn't fully
// recharge it).
#let kragor-sw = kragor.limited-uses.find(u => u.name == "Second Wind")
#assert.eq(kragor-sw.recharge, "long-short-regain")
#assert.eq(kragor-sw.uses, 2)
// The chosen Fighting Style is a *feat* (2024) nested under the desc-less
// "Fighting Style" class feature, so it flattens out as "Defense".
#let kragor-defense = kragor.traits.find(t => t.name == "Defense")
#assert.eq(kragor-defense.kind, "feat")
#assert.eq(kragor-defense.source, "Fighting Style Feat")
#assert.eq(kragor-defense.via-name, "Fighting Style")
#assert.eq(kragor-defense.class-source, "Fighter")
#assert(kragor.traits.any(t => t.name == "Tough"))
#assert(kragor.traits.any(t => t.name == "Clairvoyant Combatant"))
// Ancestry stamping (flatten-features): a subclass feature knows its class; a
// nested feat knows its granter; a top-level feature carries no ancestry.
#let kragor-cc = kragor.traits.find(t => t.name == "Clairvoyant Combatant")
#assert.eq(kragor-cc.class-source, "Warlock")
#assert.eq(kragor-cc.kind, "subclass-feature")
#let kragor-tough = kragor.traits.find(t => t.name == "Tough")
#assert.eq(kragor-tough.via-name, "Lessons of the First Ones")
#assert.eq(kragor-tough.via-kind, "invocation")
#assert.eq(kragor-tough.class-source, "Warlock")
#assert.eq(kragor.traits.find(t => t.name == "Orc").at("via-name", default: none), none)
// Invocations carry their own kind, for the ELDRITCH INVOCATIONS group.
#assert.eq(kragor.traits.find(t => t.name == "Eldritch Mind").kind, "invocation")
// Contact Patron (Warlock L9) folds a free Contact Other Plane cast into the pool.
#assert(kragor.limited-uses.any(u => u.name == "Contact Other Plane"))
// At Warlock 9 the full Great Old One Spells table is prepared (rows 3/5/7/9).
#let kragor-spells = kragor.spellcasting.find(s => s.source == "Warlock").spells
#assert(kragor-spells.contains("Dissonant Whispers"))
#assert(kragor-spells.contains("Hunger of Hadar"))
#assert(kragor-spells.contains("Summon Aberration"))
#assert(kragor-spells.contains("Telekinesis"))
// Pact slots cast Dissonant Whispers at 5th level: the resolver applies the spell's at-level scaling.
#let kw = kragor.spellcasting.find(s => s.source == "Warlock")
#assert.eq(kw.spells-detail.find(s => s.name == "Dissonant Whispers").damage, "7d6")
// Invocation-granted spells fold into the one Warlock source — no phantom
// "Pact of the Tome" / "One with Shadows" / "Visions of Distant Realms" rows
// (they cast with Warlock spellcasting; the Glamour rule). Only the Telekinetic
// feat adds a second, genuinely separate source.
#assert.eq(kragor.spellcasting.len(), 2)
#assert(kw.cantrips.contains("Guidance"))
#assert(kw.spells.contains("Detect Magic"))
// One with Shadows' Invisibility: pinned to its own level (a slotless cast has
// no slot to upcast with) — fixed-slot, grouped at 2nd, not the 5th pact slot.
#let kinv = kw.spells-detail.find(s => s.name == "Invisibility")
#assert.eq(kinv.cast-level, 2)
#assert(kinv.fixed-slot)
#assert(kw.spells-detail.find(s => s.name == "Arcane Eye").cast-level == 4)
#assert.eq(kragor.item-spells.len(), 0)

// --- Computed max HP (5.5e fixed rule) --------------------------------------
// Single class: Bard 4, Con 12 (+1). First level maxes the die; later levels take the average.
#let hp-bard = resolve(character(
  abilities: (con: 12,),
  features: (class.bard(level: 4),),
))
#assert.eq(hp-bard.max-hp, 27)
// Only the *first declared* class's first level grants the max die: Wizard-first
// Fighter 1 / Wizard 9 (d6 max first) vs the Fighter-first order.
#let hp-wf = resolve(character(
  abilities: (con: 14,),
  features: (class.wizard(level: 9), class.fighter(level: 1)),
))
#assert.eq(hp-wf.max-hp, 64)
#let hp-fw = resolve(character(
  abilities: (con: 14,),
  features: (class.fighter(level: 1), class.wizard(level: 9)),
))
#assert.eq(hp-fw.max-hp, 66)
// A declared max-hp overrides the computation (rolled HP)…
#assert.eq(resolve(character(
  max-hp: 31,
  abilities: (con: 12,),
  features: (class.bard(level: 4),),
)).max-hp, 31)
// …but eff-stat("hp") bonuses (Tough) still fold on top of either base.
#let hp-tough = resolve(character(
  abilities: (con: 12,),
  features: (class.bard(level: 4), feat.tough),
))
#assert.eq(hp-tough.max-hp, 35)

// --- languages: / tools: params, background.custom, magic-weapon -------------
#let idioms = resolve(character(
  abilities: (str: 10, dex: 14, con: 10, int: 10, wis: 10, cha: 10),
  features: (
    background.custom(
      "Guide",
      abilities: (ability.dex, ability.cha),
      skills: (skill.stealth, skill.survival),
      tools: (tool.cartographers-tools,),
      origin-feat: feat.lucky,
    ),
    class.fighter(level: 1, skills: (skill.athletics,)),
    magic-weapon(weapon.longsword, bonus: 1),
    magic-weapon(weapon.dagger, bonus: 2, name: "Fang of the North"),
  ),
  languages: ("Primordial", "Goblin"),
  tools: (tool.poisoners-kit,),
))
// The custom background applies its +2/+1, skills, tool, and origin feat.
#assert.eq(idioms.abilities.dex, 16)
#assert.eq(idioms.abilities.cha, 11)
#assert.eq(idioms.background, "Guide")
#assert(idioms.skills.stealth.level == "proficient")
#assert(idioms.skills.survival.level == "proficient")
#assert(idioms.traits.any(t => t.name == "Lucky"))
// languages:/tools: fold in beside feature-granted proficiencies.
#assert(idioms.proficiencies.language.contains("Primordial"))
#assert(idioms.proficiencies.language.contains("Goblin"))
#assert(idioms.proficiencies.tool.contains("poisoners-kit"))
#assert(idioms.proficiencies.tool.contains("cartographers-tools"))
// magic-weapon: default "+N" name, flat bonus on attack and damage; the base
// weapon's category/properties survive (Sap is Longsword mastery — stripped
// from properties as always, as is Versatile). Fighter is martial-proficient.
#let ls = idioms.attacks.find(a => a.name == "Longsword +1")
#assert.eq(ls.bonus, 3)
#assert.eq(ls.damage, "1d8+1")
#assert.eq(ls.versatile-damage, "1d10+1")
#assert(not ls.properties.contains("Sap"))
// A flavored name overrides; Finesse still picks the better of Str/Dex.
#let fang = idioms.attacks.find(a => a.name == "Fang of the North")
#assert.eq(fang.bonus, 7)
#assert.eq(fang.damage, "1d4+5")
// Both are magic (nonzero bonus), so both list as EQUIPPED, starred; nothing
// was declared or carried, so the inventory is empty.
#assert.eq(idioms.equipped, ("Longsword +1*", "Fang of the North*"))

// A magic weapon keeps the base weapon's identity for by-name matching, so the
// rename does not silently cost a Rogue its proficiency or its trained mastery.
// The Rogue gets martial Shortsword by name only; "Shortsword +1" must still
// match, or the attack loses PB and the Vex property vanishes.
#let magic-rogue = resolve(character(
  abilities: (str: 8, dex: 16, con: 10, int: 10, wis: 10, cha: 10),
  features: (
    class.rogue(level: 4, mastery: ("Shortsword",)),
    magic-weapon(weapon.shortsword, bonus: 1),
  ),
))
#let ss1 = magic-rogue.attacks.find(a => a.name == "Shortsword +1")
#assert.eq(ss1.bonus, 6) // Dex 3 + PB 2 + magic 1
#assert.eq(ss1.mastery, "Vex")
#assert.eq(idioms.equipment, ())

// --- carried(): gear in the pack is inert -----------------------------------
// The same items equipped vs carried: carried gear contributes NOTHING — no AC,
// no save bonus, no spellcasting bonus, no attack line, no traits, no resource
// pools — and lists under INVENTORY (starred) instead of EQUIPPED.
#let packrat = resolve(character(
  abilities: (str: 10, dex: 14, con: 10, int: 10, wis: 10, cha: 16),
  features: (
    class.warlock(level: 4, cantrips: (), spells: (), invocations: (
      invocation.agonizing-blast(spell.eldritch-blast),
      invocation.fiendish-vigor,
      invocation.eldritch-mind,
    )),
    carried(item.cloak-of-protection),
    carried(item.rod-of-the-pact-keeper(2)),
    carried(magic-weapon(weapon.longsword, bonus: 1)),
  ),
))
#assert.eq(packrat.ac, 12)
#assert.eq(packrat.saves.str.bonus, 0)
#let packrat-pact = packrat.spellcasting.find(s => s.source == "Warlock")
#assert.eq(packrat-pact.save-dc, 13)
#assert.eq(packrat-pact.attack, 5)
#assert(packrat.attacks.find(a => a.name == "Longsword +1") == none)
#assert(not packrat.limited-uses.any(u => u.name == "Regain Pact Slot"))
#assert(not packrat.traits.any(t => t.name.starts-with("Rod of the Pact Keeper")))
#assert.eq(packrat.equipped, ())
#assert.eq(packrat.equipment, (
  "Cloak of Protection*", "Rod of the Pact Keeper +2*", "Longsword +1*",
))

// --- Druid Primal Orders ----------------------------------------------------

#let test-magician = resolve(character(
  abilities: (str: 8, dex: 10, con: 15, int: 14, wis: 15, cha: 8),
  features: (
    class.druid(
      level: 2,
      primal-order: class.primal-order-magician(spell.message),
    ),
  ),
))
#assert.eq(test-magician.skills.arcana.bonus, 4)
#assert.eq(test-magician.skills.nature.bonus, 4)
#let magician-spellcasting = test-magician.spellcasting.find(s => s.source == "Druid")
#assert(magician-spellcasting.cantrips.contains("Message"))

#let test-warden = resolve(character(
  abilities: (str: 10, dex: 10, con: 10, int: 10, wis: 10, cha: 10),
  features: (
    class.druid(
      level: 1,
      primal-order: class.primal-order-warden,
    ),
  ),
))
#assert(test-warden.proficiencies.armor.contains("medium"))
#assert(test-warden.proficiencies.weapon.contains("martial"))
#assert(not test-warden.proficiencies.armor.contains("heavy"))

// --- Public API surface -----------------------------------------------------
// `feature()` is advertised as public API and is the core authoring primitive.
// These assertions go through the public name so a name clash in the package cannot silently break consumers.
// (Not compared against `raw-feature`: that import loads the working-tree module while `feature` comes from the installed package, so they are distinct closures even when identical in behaviour.)
#assert.eq(type(feature), function)

#let api-probe = feature("Probe", kind: "trait", source: "Test")
#assert.eq(api-probe.name, "Probe")
#assert.eq(api-probe.kind, "trait")
#assert.eq(api-probe.source, "Test")

// A feature built through the public constructor must resolve like any other.
#let api-char = resolve(character(
  name: "API Probe",
  abilities: (str: 10, dex: 10, con: 10, int: 10, wis: 10, cha: 10),
  features: (
    feature("Probe Trait", kind: "trait", source: "Test", effects: (eff-stat("speed", 10),)),
  ),
))
#assert.eq(api-char.speed, 40)
#assert(api-char.traits.map(t => t.name).contains("Probe Trait"))

// The Druid's Primal Order lives on the `class` namespace.
#assert.eq(type(class.primal-order-magician), function)
#assert.eq(class.primal-order-warden.name, "Primal Order (Warden)")

// --- Halfling, Farmer, and Circle of the Moon -------------------------------
#let moon = resolve(character(
  abilities: (str: 10, dex: 14, con: 13, int: 12, wis: 14, cha: 10),
  features: (
    species.halfling(),
    background.farmer(ability.wis, ability.con),
    class.druid(
      level: 4,
      subclass: subclass.druid.circle-of-the-moon,
      primal-order: class.primal-order-magician(spell.shillelagh),
      skills: (skill.perception, skill.insight),
    ),
  ),
))
// A 2024 species grants a size and a speed, never a language.
#assert.eq(moon.size, "Small")
#assert.eq(moon.speed, 30)
#assert.eq(moon.proficiencies.language.len(), 2)
#assert(moon.proficiencies.language.contains("Common"))
#assert(moon.proficiencies.language.contains("Druidic"))
// Brave is a conditional save advantage, thus it stays out of the save numbers.
#assert(moon.save-advantages.any(a => a.source == "Brave"))
#assert.eq(moon.saves.wis.bonus, 5)
#assert(moon.traits.map(t => t.name).contains("Naturally Stealthy"))

// Farmer grants +2/+1 from its trio, two skills, Carpenter's Tools, and Tough.
#assert.eq(moon.abilities.wis, 16)
#assert.eq(moon.abilities.con, 14)
#assert(moon.skills.animal-handling.level == "proficient")
#assert(moon.skills.nature.level == "proficient")
#assert(moon.proficiencies.tool.contains("carpenters-tools"))
// Tough adds twice the character level on top of the fixed-rule maximum.
#assert.eq(moon.max-hp, 8 + 3 * 5 + 2 * 4 + 2 * 4)

// Circle of the Moon's always-prepared spells fold into the Druid source, and the subclass adds no source of its own.
#assert.eq(moon.spellcasting.len(), 1)
#let moon-src = moon.spellcasting.first()
#assert.eq(moon-src.source, "Druid")
#assert.eq(moon.item-spells.len(), 0)
#assert(moon-src.spells.contains("Cure Wounds"))
#assert(moon-src.spells.contains("Moonbeam"))
#assert(moon-src.cantrips.contains("Starry Wisp"))
// The level-gated rows stay out until their Druid level.
#assert(not moon-src.spells.contains("Conjure Animals"))
#assert(moon.traits.map(t => t.name).contains("Circle Forms"))
// Circle Forms riders on Wild Shape, thus it costs no action of its own.
#assert.eq(moon.traits.find(t => t.name == "Circle Forms").at("activation", default: none), none)
// Moonlight Step arrives at level 10 with a Wisdom-modifier pool.
#let moon-10 = resolve(character(
  abilities: (str: 10, dex: 14, con: 13, int: 12, wis: 18, cha: 10),
  features: (class.druid(level: 10, subclass: subclass.druid.circle-of-the-moon),),
))
#assert.eq(moon-10.limited-uses.find(u => u.name == "Moonlight Step").uses, 4)

// --- Feat-granted spells collapse to one display row ------------------------
// A feat spell resolves twice: the feat's own pinned free cast, and the any-slot projection into a
// source that has slots. `all-spells` keeps only the slot cast, which both spell tables and the card
// deck's action routing consume.
#let feat-caster = resolve(character(
  abilities: (str: 10, dex: 14, con: 13, int: 12, wis: 14, cha: 10),
  features: (
    class.druid(level: 4, subclass: subclass.druid.circle-of-the-moon),
    feat.fey-touched(ability.wis, chosen-spell: spell.bless),
  ),
))
#let moon-rows = all-spells(feat-caster.spellcasting)
#let row-count = name => moon-rows.filter(s => s.name == name).len()
#assert.eq(row-count("Misty Step"), 1)
#assert.eq(row-count("Bless"), 1)
// The surviving row is the slot cast: it alone carries the upcast affordance.
#assert.eq(moon-rows.find(s => s.name == "Bless").fixed-slot, false)
#assert(moon-rows.find(s => s.name == "Bless").scaling != none)
// The free cast stays visible as its own Resources pool, so nothing is lost.
#assert(feat-caster.limited-uses.map(u => u.name).contains("Misty Step"))
#assert(feat-caster.limited-uses.map(u => u.name).contains("Bless"))
// A pool named by a spell is flagged as one (`eff-limited-use` took the spell object), so the
// resource table italicizes it; a pool named by a feature is not.
#assert.eq(feat-caster.limited-uses.find(u => u.name == "Misty Step").spell, true)
#assert.eq(feat-caster.limited-uses.find(u => u.name == "Bless").spell, true)
#assert.eq(feat-caster.limited-uses.find(u => u.name == "Wild Shape").spell, false)
// Both rows survive when the resolver produced no slot cast to prefer: a feat spell on a character
// with no slots of its own keeps its single fixed-slot row.
#let slotless = resolve(character(
  abilities: (str: 10, dex: 10, con: 10, int: 10, wis: 14, cha: 10),
  features: (feat.fey-touched(ability.wis, chosen-spell: spell.bless),),
))
#let slotless-rows = all-spells(slotless.spellcasting)
#assert.eq(slotless-rows.filter(s => s.name == "Misty Step").len(), 1)
#assert.eq(slotless-rows.find(s => s.name == "Misty Step").fixed-slot, true)
// An ordinary prepared spell is never touched by the collapse.
#assert.eq(row-count("Moonbeam"), 1)
#assert.eq(moon-rows.filter(s => s.name == "Starry Wisp").len(), 1)

// An item's `casts:` resolves to the same spell detail the spell tables use, so its action
// note never restates a number: the Rod of Magic Missiles reads 3 darts of 1d4+1 Force at
// 120 ft off spell.magic-missile's own slot-damage table.
#let wanded = resolve(character(
  abilities: (str: 10, dex: 10, con: 10, int: 10, wis: 10, cha: 18),
  features: (item.wand-of-magic-missiles(name: "Rod of Magic Missiles"),),
))
#let rod-cast = wanded.traits.find(t => t.name == "Rod of Magic Missiles").cast
#assert.eq(rod-cast.name, "Magic Missile")
#assert.eq(rod-cast.count, 3)
#assert.eq(rod-cast.damage, "1d4+1")
#assert.eq(rod-cast.damage-type, "Force")
#assert.eq(rod-cast.damage-label, "per dart")
#assert.eq(rod-cast.range, "120 ft")
// Charges, not slots, buy the level, so the cast carries no upcast affordance...
#assert.eq(rod-cast.cast-level, 1)
#assert.eq(rod-cast.fixed-slot, true)
// ...and the item is not a spellcasting source: no header row, no DC, no attack bonus.
#assert.eq(wanded.spellcasting.len(), 0)
#assert.eq(rod-cast.save-dc, none)
#assert.eq(rod-cast.attack-bonus, none)
// A bare spell entry (no pinned slot) casts at the spell's own level and computes no damage.
#let detector = resolve(character(
  abilities: (str: 10, dex: 10, con: 10, int: 10, wis: 10, cha: 10),
  features: (item.wand-of-magic-detection,),
))
#let wand-cast = detector.traits.find(t => t.name == "Wand of Magic Detection").cast
#assert.eq(wand-cast.name, "Detect Magic")
#assert.eq(wand-cast.cast-level, 1)
#assert.eq(wand-cast.damage, none)
// Goggles of Night grant Darkvision through the shared sense plumbing.
#let goggled = resolve(character(
  abilities: (str: 10, dex: 10, con: 10, int: 10, wis: 10, cha: 10),
  features: (item.goggles-of-night,),
))
#assert.eq(goggled.senses.find(s => s.name == "Darkvision").range, "60 ft")
// An item that casts nothing gains no `cast` field, so its note renders as it always has.
#assert.eq(goggled.traits.find(t => t.name == "Goggles of Night").at("cast", default: none), none)

// --- Check advantage (eff-check-advantage) ---------------------------------
// Boots of Elvenkind grant Advantage on every Dexterity (Stealth) check. Unlike
// a save advantage — which is condition-scoped prose in a footnote — this covers
// one whole skill, so it lands on that skill's own resolved entry and the layouts
// badge the row. It changes no bonus and no other skill.
#let booted = resolve(character(
  abilities: (str: 10, dex: 10, con: 10, int: 10, wis: 10, cha: 10),
  features: (item.boots-of-elvenkind,),
))
#assert.eq(booted.skills.stealth.advantage, true)
#assert.eq(booted.skills.stealth.bonus, 0)
#assert.eq(booted.skills.acrobatics.advantage, false)
#assert.eq(booted.save-advantages.len(), 0)
// Carried gear contributes nothing, the boots included.
#let packed = resolve(character(
  abilities: (str: 10, dex: 10, con: 10, int: 10, wis: 10, cha: 10),
  features: (carried(item.boots-of-elvenkind),),
))
#assert.eq(packed.skills.stealth.advantage, false)

// --- Human: Skillful and Versatile -----------------------------------------
// The chosen skill is a proficiency; the chosen Origin feat nests under Versatile,
// so `flatten-features` collects its effects at depth (Tough's HP bonus here).
#let hum = resolve(character(
  abilities: (str: 10, dex: 10, con: 10, int: 10, wis: 10, cha: 10),
  features: (species.human(skill: skill.survival, origin-feat: feat.tough), class.rogue(level: 3)),
))
#assert.eq(hum.skills.survival.level, "proficient")
#assert.eq(hum.skills.perception.level, none)
#assert(hum.traits.any(t => t.name == "Tough"))
// Rogue 3 d8: 8 + 5 + 5 = 18, Con mod 0, plus Tough's 2 per level.
#assert.eq(hum.max-hp, 18 + 2 * 3)

// --- Elf: Elven Lineage and Keen Senses ------------------------------------
// Wood Elf raises the Speed to 35 and knows Druidcraft; Keen Senses takes the
// chosen skill. The level 3/5 lineage spells stay prose (the Fairy limitation),
// so the source carries the cantrip alone.
#let wood = resolve(character(
  abilities: (str: 10, dex: 10, con: 10, int: 10, wis: 10, cha: 10),
  features: (species.elf(lineage: "wood-elf", skill: skill.survival, casting-ability: ability.wis),),
))
#assert.eq(wood.speed, 35)
#assert.eq(wood.skills.survival.level, "proficient")
#assert.eq(wood.skills.perception.level, none)
#assert.eq(wood.senses.find(s => s.name == "Darkvision").range, "60 ft")
#assert.eq(wood.save-advantages.len(), 1)
#let wood-src = wood.spellcasting.find(s => s.source == "Elven Lineage")
#assert.eq(wood-src.cantrips, ("Druidcraft",))
#assert.eq(wood-src.ability, "wis")
// Drow keeps Speed 30 and raises Darkvision to 120 ft: the base 60 ft sense and
// the lineage's 120 ft dedupe by name, longest range winning.
#let drow = resolve(character(
  abilities: (str: 10, dex: 10, con: 10, int: 10, wis: 10, cha: 10),
  features: (species.elf(lineage: "drow"),),
))
#assert.eq(drow.speed, 30)
#assert.eq(drow.senses.filter(s => s.name == "Darkvision").len(), 1)
#assert.eq(drow.senses.find(s => s.name == "Darkvision").range, "120 ft")

// --- Dragonborn: Draconic Ancestry -----------------------------------------
// The ancestry sets both the Breath Weapon damage type and the Damage
// Resistance; the pool is PB uses. Draconic Flight is gated on character level
// 5, which a species builder cannot see, so it emits no pool of its own.
#let drac = resolve(character(
  abilities: (str: 10, dex: 10, con: 14, int: 10, wis: 10, cha: 10),
  features: (species.dragonborn(ancestry: "silver"), class.fighter(level: 5)),
))
#assert.eq(drac.resistances.find(r => r.kind == "resistance").type, "Cold")
#assert.eq(drac.senses.find(s => s.name == "Darkvision").range, "60 ft")
#let breath = drac.limited-uses.find(u => u.name == "Breath Weapon")
#assert.eq(breath.uses, 3) // PB at level 5
#assert(not drac.limited-uses.any(u => u.name == "Draconic Flight"))
// A rider on the Attack action, so it stays out of the action tables.
#assert.eq(drac.traits.find(t => t.name == "Breath Weapon").at("activation", default: none), none)
// Its dice scale on total character level: 2d10 from level 5.
#let d5 = 2
#let pb5 = 3
#assert.eq(
  drac.traits.find(t => t.name == "Breath Weapon").notes,
  [Replace one attack: 15-ft Cone or 30-ft Line, DEX $#{8 + 3 + 2}$ save, $#{str(d5)}d 10$ Cold (half on a success) (#pb5/Long Rest).],
)

// --- Assassin (Rogue subclass) ---------------------------------------------
// Assassinate's extra damage equals the Rogue level, so its prose reads the
// resolved number. Interpolate it the same way the markup does (see the
// Adrenaline Rush note above) or the content node shapes differ.
#let assassin4 = resolve(character(
  abilities: (str: 8, dex: 15, con: 13, int: 10, wis: 14, cha: 12),
  features: (class.rogue(level: 4, subclass: subclass.rogue.assassin),),
))
#let rogue4 = 4
#assert.eq(
  assassin4.traits.find(t => t.name == "Assassinate").notes,
  [Advantage on Initiative. Round 1: Advantage against creatures yet to act; a Sneak Attack hit adds $#rogue4$ damage.],
)
#assert(assassin4.proficiencies.tool.contains("disguise-kit"))
#assert(assassin4.proficiencies.tool.contains("poisoners-kit"))
// Assassinate rides an attack, so it stays out of the action tables.
#assert.eq(assassin4.traits.find(t => t.name == "Assassinate").at("activation", default: none), none)

// --- Dual Wielder ----------------------------------------------------------
// The ASI is on the parent; Enhanced Dual Wielding is the nested Bonus Action.
#let dw = resolve(character(
  abilities: (str: 10, dex: 15, con: 10, int: 10, wis: 10, cha: 10),
  features: (feat.dual-wielder(ability.dex),),
))
#assert.eq(dw.abilities.dex, 16)
#assert.eq(dw.traits.find(t => t.name == "Enhanced Dual Wielding").activation, "Bonus Action")

// --- Ring of Comprehension -------------------------------------------------
// Charges, not slots, so the cast is fixed-slot and the item is no spellcasting source.
#let ringed = resolve(character(
  abilities: (str: 10, dex: 10, con: 10, int: 10, wis: 10, cha: 10),
  features: (item.ring-of-comprehension,),
))
#let ring-cast = ringed.traits.find(t => t.name == "Ring of Comprehension").cast
#assert.eq(ring-cast.name, "Comprehend Languages")
#assert.eq(ring-cast.range, "Self")
#assert.eq(ringed.spellcasting.len(), 0)
// The 1-charge dawn refill recharges on no rest, so the pool sorts with the
// long-rest bucket; the layouts footnote the row (`_recharge-notes`).
#let ring-pool = ringed.limited-uses.find(u => u.name == "Ring of Comprehension")
#assert.eq(ring-pool.uses, 3)
#assert.eq(ring-pool.recharge, "dawn")
// Sorted after every short-rest-recoverable pool, alongside the long-rest ones.
#let mixed = resolve(character(
  abilities: (str: 10, dex: 10, con: 10, int: 10, wis: 10, cha: 10),
  features: (item.ring-of-comprehension, species.orc()),
))
#assert.eq(
  mixed.limited-uses.map(u => u.recharge),
  ("short-or-long", "long", "dawn"), // Adrenaline Rush, Relentless Endurance, then the ring
)

// --- Cleric 4 / Light Domain ------------------------------------------------
// A full Wisdom caster. The domain's always-prepared spells fold into the
// Cleric source instead of a second one, Divine Order (Thaumaturge) adds the
// Wisdom modifier to Arcana and Religion, and Channel Divinity is the partial
// short-rest refill kind the layouts footnote.
#let therin = resolve(character(
  abilities: (str: 12, dex: 14, con: 14, int: 8, wis: 15, cha: 8),
  features: (
    species.dragonborn(ancestry: "gold"),
    background.acolyte(
      ability.wis, ability.cha,
      origin-feat: feat.magic-initiate(
        "Cleric",
        casting-ability: ability.wis,
        cantrips: (spell.thaumaturgy, spell.word-of-radiance),
        spell: spell.cure-wounds,
      ),
    ),
    class.cleric(
      level: 4,
      subclass: subclass.cleric.light,
      divine-order: class.divine-order-thaumaturge(spell.guidance),
      skills: (skill.medicine, skill.insight),
      cantrips: (spell.light, spell.sacred-flame, spell.toll-the-dead),
      prepared: (spell.bless, spell.aid),
    ),
    feat.fey-touched(ability.wis, chosen-spell: spell.bane),
    item.chain-shirt,
    item.sentinel-shield,
    weapon.mace,
  ),
))
#assert.eq(therin.abilities.wis, 18) // 15 base, +2 Acolyte, +1 Fey Touched
#assert.eq(therin.max-hp, 31)
#assert.eq(therin.ac, 17) // Chain Shirt 13, Dex 2 (capped), Shield 2
#let cleric-src = therin.spellcasting.find(s => s.source == "Cleric")
#assert.eq(cleric-src.save-dc, 14)
#assert.eq(cleric-src.attack, 6)
#assert.eq(cleric-src.slots, ("1": 4, "2": 3))
#assert.eq(cleric-src.cantrips, ("Light", "Sacred Flame", "Toll the Dead", "Guidance"))
// The four Light Domain spells belong to this source; the subclass adds none of its own.
#assert.eq(therin.spellcasting.filter(s => s.source == "Light Domain").len(), 0)
#for s in ("Burning Hands", "Faerie Fire", "Scorching Ray", "See Invisibility") {
  assert(cleric-src.spells.contains(s), message: s + " must fold into the Cleric source")
}
#assert.eq(therin.item-spells.len(), 0)
#let mi-cleric = therin.spellcasting.find(s => s.source == "Magic Initiate (Cleric)")
#assert.eq(mi-cleric.spells-detail.find(s => s.name == "Word of Radiance").area, (shape: "emanation", size: "5 ft"))
// Thaumaturge: Int mod plus the Wisdom modifier, and Religion also has proficiency.
#assert.eq(therin.skills.arcana.bonus, 3)
#assert.eq(therin.skills.religion.bonus, 5)
#assert.eq(therin.skills.medicine.bonus, 6)
#let cd = therin.limited-uses.find(u => u.name == "Channel Divinity")
#assert.eq(cd.uses, 2)
#assert.eq(cd.recharge, "long-short-regain")
#assert.eq(therin.limited-uses.find(u => u.name == "Warding Flare").uses, 4) // Wis mod
// The two Channel Divinity effects are the action rows; the parent carries no
// note, so it does not add a second row for the same feature.
#assert.eq(therin.traits.find(t => t.name == "Divine Spark").activation, "Action")
#assert.eq(therin.traits.find(t => t.name == "Turn Undead").activation, "Action")
#assert.eq(therin.traits.find(t => t.name == "Radiance of the Dawn").activation, "Action")
#assert.eq(therin.traits.find(t => t.name == "Warding Flare").activation, "Reaction")
#let therin-wis = 4
#assert.eq(therin.traits.find(t => t.name == "Warding Flare").notes, [Impose Disadvantage on the attack roll of a creature you can see within 30 ft (#therin-wis/Long Rest).])
#assert.eq(therin.traits.find(t => t.name == "Divine Spark").notes, [Restore $1d 8 + 4$ HP to a creature within 30 ft, or deal that much Necrotic or Radiant damage on a failed CON $14$ save (half on a success) (uses Channel Divinity).])
// The Mace is a simple weapon, so the attack carries PB; Sap stays hidden without trained mastery.
#let mace-line = therin.attacks.find(a => a.name == "Mace")
#assert.eq(mace-line.bonus, 3)
#assert.eq(mace-line.damage, "1d6+1")
#assert.eq(mace-line.at("mastery", default: none), none)

// --- Passive scores honour Advantage on the check ---------------------------
// The Sentinel Shield gives Advantage on Wisdom (Perception) checks, which
// raises the passive score by 5 (SRD 5.2.1 §Passive Perception). Perception
// itself is unproficient here, so the score is 10 + 4 + 5.
#assert(therin.skills.perception.advantage)
#assert.eq(therin.skills.perception.level, none)
#assert.eq(therin.passives.perception, 19)
#assert.eq(therin.passives.insight, 16)
#assert.eq(therin.passives.investigation, 9)

// --- Catalog: PHB Weapons ----------------------------------------------------
#let all-weapons-char = resolve(character(
  name: "Test Armorer",
  species: species.human(skill: skill.athletics, origin-feat: feat.alert),
  features: (
    class.fighter(level: 1, mastery: ("Glaive", "Greatsword")),
    weapon.club, weapon.dagger, weapon.greatclub, weapon.handaxe, weapon.javelin,
    weapon.light-hammer, weapon.mace, weapon.quarterstaff, weapon.sickle, weapon.spear,
    weapon.dart, weapon.crossbow-light, weapon.light-crossbow, weapon.shortbow, weapon.sling,
    weapon.battleaxe, weapon.flail, weapon.glaive, weapon.greataxe, weapon.greatsword,
    weapon.halberd, weapon.lance, weapon.longsword, weapon.maul, weapon.morningstar,
    weapon.pike, weapon.rapier, weapon.scimitar, weapon.shortsword, weapon.trident,
    weapon.warhammer, weapon.war-pick, weapon.whip, weapon.blowgun, weapon.hand-crossbow,
    weapon.crossbow-heavy, weapon.heavy-crossbow, weapon.longbow, weapon.musket, weapon.pistol,
  ),
))

#let get-eff(w-name) = {
  let f = all-weapons-char.traits.find(t => t.name == w-name)
  f.effects.first()
}

// Simple Melee
#assert.eq(get-eff("Club").category, "simple")
#assert.eq(get-eff("Club").kind, "melee")
#assert.eq(get-eff("Dagger").category, "simple")
#assert.eq(get-eff("Dagger").kind, "melee")
#assert.eq(get-eff("Dagger").thrown-range, "20/60 ft")
#assert.eq(get-eff("Greatclub").category, "simple")
#assert.eq(get-eff("Spear").category, "simple")
#assert.eq(get-eff("Spear").versatile, "1d8")

// Simple Ranged
#assert.eq(get-eff("Dart").category, "simple")
#assert.eq(get-eff("Dart").kind, "ranged")
#assert.eq(get-eff("Light Crossbow").category, "simple")
#assert.eq(get-eff("Light Crossbow").kind, "ranged")
#assert.eq(get-eff("Sling").category, "simple")
#assert.eq(get-eff("Sling").kind, "ranged")

// Martial Melee
#assert.eq(get-eff("Glaive").category, "martial")
#assert.eq(get-eff("Glaive").kind, "melee")
#assert.eq(get-eff("Glaive").range, "10 ft")
#assert.eq(get-eff("Greatsword").category, "martial")
#assert.eq(get-eff("Greatsword").kind, "melee")
#assert.eq(get-eff("Greatsword").damage, "2d6")
#assert.eq(get-eff("Whip").category, "martial")
#assert.eq(get-eff("Whip").kind, "melee")
#assert.eq(get-eff("Whip").range, "10 ft")
#assert.eq(get-eff("War Pick").category, "martial")
#assert.eq(get-eff("Trident").category, "martial")
#assert.eq(get-eff("Trident").versatile, "1d10")

// Martial Ranged
#assert.eq(get-eff("Blowgun").category, "martial")
#assert.eq(get-eff("Blowgun").kind, "ranged")
#assert.eq(get-eff("Blowgun").damage, "1")
#assert.eq(get-eff("Heavy Crossbow").category, "martial")
#assert.eq(get-eff("Heavy Crossbow").kind, "ranged")
#assert.eq(get-eff("Musket").category, "martial")
#assert.eq(get-eff("Musket").kind, "ranged")
#assert.eq(get-eff("Pistol").category, "martial")
#assert.eq(get-eff("Pistol").kind, "ranged")

// --- Staff of the Woodlands --------------------------------------------------
#let druid-woodlands = resolve(character(
  abilities: (str: 10, dex: 10, con: 10, int: 10, wis: 16, cha: 10),
  features: (
    class.druid(level: 2, cantrips: (spell.shillelagh,)),
    item.staff-of-the-woodlands,
  ),
))

// Equipped gear includes the starred magic item.
#assert(druid-woodlands.equipped.contains("Staff of the Woodlands*"))

// Spell attack bonus gains +2; save DC is unaffected.
#let dw-cast = druid-woodlands.spellcasting.find(s => s.source == "Druid")
#assert.eq(dw-cast.attack, 7) // PB 2 + Wis 3 + Staff 2
#assert.eq(dw-cast.save-dc, 13) // 8 + PB 2 + Wis 3 (no DC bonus)

// 6 charges, long-rest recharge tracking.
#let dw-charges = druid-woodlands.limited-uses.find(u => u.name == "Staff of the Woodlands")
#assert.eq(dw-charges.uses, 6)
#assert.eq(dw-charges.recharge, "long")

// Weapon attack: Quarterstaff +2 (Str 10 = +0 mod, PB 2, magic 2 -> bonus +4, 1d6+2).
#let dw-staff = druid-woodlands.attacks.find(a => a.name == "Staff of the Woodlands" and a.at("via-spell", default: none) == none)
#assert.eq(dw-staff.bonus, 4)
#assert.eq(dw-staff.damage, "1d6+2")
#assert.eq(dw-staff.damage-type, "Bludgeoning")
#assert.eq(dw-staff.versatile-damage, "1d8+2")

// Shillelagh variant: Wis 16 (+3), PB 2, magic 2 -> bonus +7, 1d8 + 3 (Wis) + 2 (Staff) = 1d8+5.
#let dw-shil = attack-lines(druid-woodlands, "Staff of the Woodlands", via: "Shillelagh").first()
#assert.eq(dw-shil.bonus, 7)
#assert.eq(dw-shil.damage, "1d8+5")
#assert.eq(dw-shil.damage-type, "Bludgeoning")

// Staff of the Woodlands item-spells table has 8 spells with charge costs.
#let dw-item-spells = druid-woodlands.item-spells.find(i => i.name == "Staff of the Woodlands")
#assert.eq(dw-item-spells.spells.len(), 8)
#let dw-sp = name => dw-item-spells.spells.find(s => s.name == name)
#assert.eq(dw-sp("Animal Friendship").charges, 1)
#assert.eq(dw-sp("Animal Friendship").save-dc, 13)
#assert.eq(dw-sp("Awaken").charges, 5)
#assert.eq(dw-sp("Awaken").casting-time, "8 hours")
#assert.eq(dw-sp("Barkskin").charges, 2)
#assert.eq(dw-sp("Barkskin").casting-time, "Bonus Action")
#assert.eq(dw-sp("Locate Animals/Plants").charges, 2)
#assert.eq(dw-sp("Pass without Trace").charges, 2)
#assert.eq(dw-sp("Speak with Animals").charges, 1)
#assert.eq(dw-sp("Speak with Animals").ritual, false)
#assert.eq(dw-sp("Locate Animals/Plants").ritual, false)
#assert.eq(dw-sp("Speak with Plants").charges, 3)
#assert.eq(dw-sp("Wall of Thorns").charges, 6)
#assert.eq(dw-sp("Wall of Thorns").damage, "7d8")
#assert.eq(dw-sp("Wall of Thorns").save-dc, 13)

// Staff of the Woodlands is a passive trait in Features & Traits (no action-table clutter).
#assert(druid-woodlands.traits.any(t => t.name == "Staff of the Woodlands"))
#assert(not druid-woodlands.traits.any(t => t.name == "Tree Form"))

// Two-handed grip on Staff of the Woodlands.
#let dw-2h = resolve(character(
  abilities: (str: 10, dex: 10, con: 10, int: 10, wis: 16, cha: 10),
  features: (
    class.druid(level: 2),
    two-handed(item.staff-of-the-woodlands),
  ),
))
#let dw-2h-staff = dw-2h.attacks.find(a => a.name == "Staff of the Woodlands")
#assert.eq(dw-2h-staff.damage, "1d8+2")
#assert.eq(dw-2h-staff.versatile-damage, "1d6+2")

// Carried (inert in inventory) Staff of the Woodlands.
#let dw-carried = resolve(character(
  abilities: (str: 10, dex: 10, con: 10, int: 10, wis: 16, cha: 10),
  features: (
    class.druid(level: 2),
    carried(item.staff-of-the-woodlands),
  ),
))
#assert(not dw-carried.equipped.contains("Staff of the Woodlands*"))
#assert(dw-carried.equipment.contains("Staff of the Woodlands*"))
#assert.eq(dw-carried.spellcasting.find(s => s.source == "Druid").attack, 5)
#assert(not dw-carried.attacks.any(a => a.name == "Staff of the Woodlands"))
#assert(not dw-carried.limited-uses.any(u => u.name == "Staff of the Woodlands"))
#assert.eq(dw-carried.item-spells.len(), 0)

// --- Staff of Power ----------------------------------------------------------
#let sorc-power = resolve(character(
  abilities: (str: 10, dex: 14, con: 12, int: 10, wis: 10, cha: 16),
  features: (
    class.sorcerer(level: 5, cantrips: (spell.fire-bolt,), spells: (spell.shield,)),
    item.staff-of-power,
  ),
))
#assert.eq(sorc-power.ac, 14) // 10 + Dex 2 + Staff 2
#assert.eq(sorc-power.saves.cha.bonus, 8) // PB 3 + Cha 3 + Staff 2
#assert.eq(sorc-power.spellcasting.find(s => s.source == "Sorcerer").attack, 8) // PB 3 + Cha 3 + Staff 2
#let sop-spells = sorc-power.item-spells.find(i => i.name == "Staff of Power")
#assert.eq(sop-spells.spells.len(), 9)
#let sop-sp = name => sop-spells.spells.find(s => s.name == name)
#assert.eq(sop-sp("Cone of Cold").charges, 5)
#assert.eq(sop-sp("Fireball").charges, 5)
#assert.eq(sop-sp("Fireball").damage, "10d6") // 5th-level Fireball
#assert.eq(sop-sp("Magic Missile").charges, 1)
#assert.eq(sop-sp("Wall of Force").charges, 5)

#set page(width: auto, height: auto, margin: 12pt)
All resolve-engine assertions passed.
