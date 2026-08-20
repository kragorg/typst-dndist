// Resolution layer: folds a character's feature effects into computed values.
// - Computed values: ability scores, proficiency bonus, AC, skills, saves, passives.
// - Renderers consume the result of `resolve`.

#import "data/abilities.typ": ability-ids
#import "data/skills.typ": skill-list
#import "data/constants.typ": weapon-mastery-names

// Standard 5e ability-modifier and proficiency-bonus formulas.
#let modifier(score) = calc.floor((score - 10) / 2)
#let prof-bonus(level) = 2 + calc.floor((level - 1) / 4)

// Signed-modifier suffix for a damage/healing string: "" when zero, else "+N"/"-N".
// - The resolver emits plain strings; display mathifies them.
// - Spell the minus explicitly; these strings stay ASCII.
#let _signed(n) = if n > 0 { "+" + str(n) } else if n < 0 { "-" + str(calc.abs(n)) } else { "" }

// Remove duplicates; keep the first occurrence for each key.
// - Insertion order (declaration order) stays.
#let dedup-by(items, key) = {
  let seen = (:)
  let out = ()
  for it in items {
    let k = key(it)
    if k not in seen { seen.insert(k, true); out.push(it) }
  }
  out
}

// Flatten a feature list depth-first, nested sub-features included.
// - Stamp each nested feature with plain-string ancestry; the layouts group and tag by it.
// - A top-level feature gets no ancestry.
// - `via-name` / `via-kind`: immediate parent's name and kind; lets a feat nested in an invocation know its granter.
// - Layouts hide the tag when the parent is only a structural container (background/class/class-feature).
// - `class-source`: nearest ancestor class's name; lets a subclass-feature (own `source` = subclass name) know its class group on a multiclass sheet.
// - Skip a `carried` feature (inert cargo, see `carried()` in model.typ) and its children; nothing about it is live.
// - Only the gear inventory, which reads `char.features` directly, sees a carried feature.
#let flatten-features(features, parent: none, class-source: none) = {
  let acc = ()
  for f in features.filter(f => not f.at("carried", default: false)) {
    let stamped = f
    if parent != none {
      stamped.insert("via-name", parent.name)
      stamped.insert("via-kind", parent.at("kind", default: none))
      if class-source != none { stamped.insert("class-source", class-source) }
    }
    acc.push(stamped)
    let cs = if f.at("kind", default: none) == "class" { f.name } else { class-source }
    acc += flatten-features(f.at("features", default: ()), parent: f, class-source: cs)
  }
  acc
}

// Collect the effects of every feature, sub-features included, plus the character-level ad-hoc effects.
// - Annotate `spellcasting` and `spell-any-slot` effects with the feature's
//   `class-source` so the resolver can inherit a class's item bonuses when a
//   feat-granted spell comes from a class feature (e.g., Magic Initiate via
//   Lessons of the First Ones → Warlock spells that inherit the Rod of the
//   Pact Keeper bonus). Background/origin feats have no class-source → no
//   item-bonus inheritance.
#let collect-effects(char) = {
  let effects = ()
  for f in flatten-features(char.features) {
    let cs = f.at("class-source", default: none)
    for e in f.at("effects", default: ()) {
      if cs != none and (e.effect == "spell-any-slot" or e.effect == "spellcasting") {
        effects.push(e + (class-source: cs))
      } else {
        effects.push(e)
      }
    }
  }
  effects += char.at("effects", default: ())
  effects
}

// Compute the final ability scores: base plus all additive contributions.
// - A "set" effect forces a fixed value.
#let resolve-abilities(base, effects) = {
  let scores = (:)
  for id in ability-ids {
    let v = base.at(id, default: 10)
    let forced = none
    for e in effects.filter(e => e.effect == "ability" and e.which == id) {
      if e.kind == "set" { forced = e.value } else { v += e.value }
    }
    scores.insert(id, if forced != none { forced } else { v })
  }
  scores
}

// AC = best candidate base plus all flat bonuses.
// - A candidate comes from armor or from an alternate formula.
// - A "set" effect overrides the base.
#let resolve-ac(scores, effects) = {
  let acs = effects.filter(e => e.effect == "ac")
  let bonus = acs.filter(e => e.kind == "bonus").map(e => e.value).sum(default: 0)
  let dexmod = modifier(scores.dex)

  let sets = acs.filter(e => e.kind == "set")
  if sets.len() > 0 {
    return calc.max(..sets.map(e => e.value)) + bonus
  }

  // Default candidate: unarmored 10 + Dex, no cap.
  let candidates = (10 + dexmod,)
  for e in acs.filter(e => e.kind == "base") {
    let dex = if e.cap == none { dexmod } else { calc.min(dexmod, e.cap) }
    candidates.push(e.base + dex)
  }
  for e in acs.filter(e => e.kind == "formula") {
    let extra = e.abilities.map(a => modifier(scores.at(a))).sum(default: 0)
    candidates.push(e.base + extra)
  }
  calc.max(..candidates) + bonus
}

// Compute the bonus for each skill, with expertise, proficiency, and Jack of All Trades.
#let resolve-skills(scores, effects, pb) = {
  let jack = effects.any(e => e.effect == "skill-rule" and e.rule == "jack-of-all-trades")
  let reliable = effects.any(e => e.effect == "skill-rule" and e.rule == "reliable-talent")
  let profs = effects.filter(e => e.effect == "proficiency" and e.category == "skill")
  // Skill ids with advantage on every check (see `eff-check-advantage`).
  let advantaged = effects.filter(e => e.effect == "check-advantage").map(e => e.skill)

  let result = (:)
  for sk in skill-list {
    let abil-mod = modifier(scores.at(sk.ability))
    let level = none
    for p in profs.filter(p => p.key == sk.id) {
      if p.level == "expertise" { level = "expertise" }
      else if level != "expertise" { level = "proficient" }
    }

    let bonus = abil-mod
    let joat = false
    if level == "expertise" { bonus += 2 * pb }
    else if level == "proficient" { bonus += pb }
    else if jack { bonus += calc.floor(pb / 2); joat = true }

    // Add flat or ability-derived per-skill bonuses (Primal Order Magician).
    for e in effects.filter(e => e.effect == "skill-bonus" and e.which == sk.id) {
      bonus += e.value
      if e.ability != none {
        let m = modifier(scores.at(e.ability))
        if e.min-value != none and m < e.min-value { m = e.min-value }
        bonus += m
      }
    }

    result.insert(sk.id, (
      bonus: bonus,
      level: level,
      joat: joat,
      reliable: reliable and level != none,
      advantage: advantaged.contains(sk.id),
    ))
  }
  result
}

// Compute the saving-throw bonus for each ability.
// - Flat `eff-save-bonus` effects (Cloak of Protection) apply to every save.
#let resolve-saves(scores, effects, pb) = {
  let profs = effects
    .filter(e => e.effect == "proficiency" and e.category == "save")
    .map(p => p.key)
  let flat = effects
    .filter(e => e.effect == "save-bonus")
    .map(e => e.value)
    .sum(default: 0)
  let result = (:)
  for id in ability-ids {
    let m = modifier(scores.at(id))
    let proficient = profs.contains(id)
    result.insert(id, (
      bonus: m + if proficient { pb } else { 0 } + flat,
      proficient: proficient,
    ))
  }
  result
}

// Collect the deduplicated proficiency keys of a non-skill/save category.
#let collect-profs(effects, category) = dedup-by(
  effects
    .filter(e => e.effect == "proficiency" and e.category == category)
    .map(p => p.key),
  k => k,
)

// Select the highest damage/healing tier whose level threshold is not more than `level`.
// - Tiers are (threshold, count, die, ...) rows in ascending order.
// - The first tier applies also when its threshold is above `level`.
// - A `none` level (no effective casting level) gives `fallback`.
#let _pick-tier(tiers, level, fallback: none) = {
  if level == none { return fallback }
  let t = tiers.first()
  for tt in tiers { if tt.at(0) <= level { t = tt } }
  t
}

// Project a spell object to the display fields the spell tables need.
// - Put the source's save DC and attack bonus on every spell; the HIT/SAVE column shows "WIS 14" for a save spell or "+5" for a spell-attack spell.
// - `level` (character level) drives cantrip scaling through the `damage` tiers.
// - `slot` (effective casting slot level) drives leveled-spell scaling through the `slot-damage` tiers.
// - With no slot, a leveled spell has no computed damage.
#let _spell-detail(s, source, save-dc, attack-bonus, level, spell-bonuses, slot: none, fixed-slot: false, cast-mod: 0) = {
  let is-cantrip = s.at("level", default: 0) == 0
  // A weapon-attack cantrip (True Strike, Booming Blade) makes a weapon attack instead of a spell attack.
  // - `resolve-attacks` expands it into one `<weapon> (<Spell>)` line for each weapon.
  // - Its SPELLS-table row shows no HIT/SAVE and no damage; only its name and note.
  let weapon-attack = s.at("weapon-attack", default: false)
  let tiers = if is-cantrip { s.at("damage", default: none) }
               else           { s.at("slot-damage", default: none) }
  let effective-level = if is-cantrip { level } else { slot }
  let is-beam = s.at("damage-bonus-per", default: "flat") == "beam"
  let tier = if tiers == none { none } else { _pick-tier(tiers, effective-level) }
  // Keep damage as separate plain-data fields, like the attack table's damage and damage-type.
  // - Fields: the dice/mod expression, the damage type, and the beam/dart label.
  // - Display mathifies only the dice; keeps the type and label upright; no string parsing.
  let dmg = none
  let dmg-type = none
  let dmg-label = none
  if tier != none {
    let count = tier.at(1)
    let die   = tier.at(2)
    let dtype = tier.at(3)
    let bonus = spell-bonuses.at(lower(s.name), default: 0)
    // A spell tagged "casting-mod" adds the source's casting ability modifier (Healing Word +Wis).
    // - This modifier adds on top of any external spell-damage bonus.
    if s.at("damage-bonus", default: none) == "casting-mod" { bonus += cast-mod }
    // Beam spell shows per-beam damage; its own dice plus the per-beam bonus.
    // - For a beam spell, `die` is the complete per-beam expression ("1d10", "2d10"), already prefixed.
    // - The ×N in the SPELL column gives the beam count.
    // - A non-beam spell shows the total dice, count × die ("2d10").
    let dice-str = if is-beam { die } else { str(count) + die }
    dmg = dice-str + _signed(bonus)
    dmg-type = if dtype == "" or dtype == none { none } else { dtype }
    // `damage-per-label: none` means the default label "per beam".
    // - Label only a multi-beam spell that shows per-beam damage (Magic Missile → "per dart").
    if is-beam and count > 1 {
      let label-raw = s.at("damage-per-label", default: none)
      dmg-label = if label-raw != none { label-raw } else { "per beam" }
    }
  }
  // Effective cast level: the given slot (a warlock's pact slot) or the spell's own level.
  let cast-lv = if is-cantrip { 0 } else if slot != none { slot } else { s.at("level", default: 1) }
  // Fixed-slot upcast (a pact slot above the spell's base level): evaluate the spell's `at-level` function and overlay its field overrides.
  // - An override gives computed scaling prose in place of the per-slot delta, and/or the structured fields the scaling changes (duration/concentration/area).
  // - `scaling-computed` marks that `at-level` wrote the scaling channel.
  // - The renderer's drop-heuristics must not remove the computed prose.
  let at-lv = s.at("at-level", default: none)
  let upcast = fixed-slot and cast-lv > s.at("level", default: 0)
  let ov = if upcast and type(at-lv) == function {
    let r = (at-lv)(cast-lv)
    if type(r) == dictionary { r } else { (:) }
  } else { (:) }
  (
    name: s.name,
    level: s.at("level", default: 0),
    cast-level: cast-lv,
    source: source,
    school: s.at("school", default: none),
    casting-time: s.at("casting-time", default: none),
    range: s.at("range", default: none),
    area: ov.at("area", default: s.at("area", default: none)),
    components: s.at("components", default: none),
    duration: ov.at("duration", default: s.at("duration", default: none)),
    concentration: ov.at("concentration", default: s.at("concentration", default: false)),
    ritual: s.at("ritual", default: false),
    save: s.at("save", default: none),
    // A check to resist (a saving throw uses the `save` field instead): authored prose that names the ability or skill check.
    // - The effect cell adds the resolved DC (Minor Illusion's Investigation against your spell save DC).
    // - Display-only.
    check: s.at("check", default: none),
    // A weapon-attack cantrip makes no spell attack; its HIT/SAVE column stays blank.
    // - Its per-weapon lines are in the ATTACK table.
    attack: s.at("attack", default: false),
    trigger: s.at("trigger", default: none),
    material-cost: s.at("material-cost", default: false),
    notes: s.at("notes", default: none),
    scaling: ov.at("scaling", default: s.at("scaling", default: none)),
    scaling-computed: "scaling" in ov,
    fixed-slot: fixed-slot,
    damage: dmg,
    damage-type: dmg-type,
    damage-label: dmg-label,
    healing: if s.at("healing", default: none) == none { none } else {
      let h-tiers = s.at("healing")
      let h-tier = _pick-tier(h-tiers, effective-level, fallback: h-tiers.first())
      let h-bonus = spell-bonuses.at(lower(s.name), default: 0)
      if s.at("damage-bonus", default: none) == "casting-mod" { h-bonus += cast-mod }
      str(h-tier.at(1)) + h-tier.at(2) + _signed(h-bonus)
    },
    // Beam/dart count of a multi-beam spell when more than 1, for "Eldritch Blast ×2".
    count: if tier != none and is-beam and tier.at(1) > 1 { tier.at(1) } else { none },
    save-dc: save-dc,
    attack-bonus: attack-bonus,
    weapon-attack: weapon-attack,
  )
}

// Unpack a spell-list entry into (spell, pinned slot level): a bare spell object, or the `(spell: s, slot: N)` form that pins a cast level.
// - The one reader of that shape: `eff-spellcasting`'s `spells:` and a feature's `casts:` (a magic item's granted cast) take the same entry, so they read it the same way.
#let _unpack-spell-entry(entry) = if type(entry) == dictionary and "spell" in entry {
  (entry.spell, entry.at("slot", default: none))
} else {
  (entry, none)
}

// Compute one record for each granted spellcasting source.
// - Derive the save DC and attack bonus from the casting ability.
// - Keep the granted cantrip and spell names for the compact lines.
// - Keep the full per-spell detail for the rich tables.
// - Keep any expendable slots.
#let resolve-spellcasting(effects, mods, pb, level) = {
  // Collect per-spell damage bonuses from `eff-spell-damage-bonus` effects.
  // - Keys are lowercased spell display names; values are the summed bonuses.
  let spell-bonuses = (:)
  for e in effects.filter(e => e.effect == "spell-damage-bonus") {
    let v = if e.ability != none { mods.at(e.ability) } else { e.value }
    // Normalize the key to lowercase, with spaces for hyphens, to match the display names.
    let key = lower(e.spell).replace("-", " ")
    spell-bonuses.insert(key, spell-bonuses.at(key, default: 0) + v)
  }

  // One source's save DC and attack bonus: 8 + PB + mod, PB + mod, plus item bonuses.
  // - Item bonuses come from `eff-spellcasting-bonus` (Rod of the Pact Keeper).
  // - An effect with a `source-name` applies only to the source with that display name.
  // - An effect with no `source-name` applies to every source.
  // - The any-slot projection below computes the same pair, thus it lives here once.
  let source-stats = (source-name, amod) => {
    let b = effects.filter(x => x.effect == "spellcasting-bonus"
      and (x.source-name == none or x.source-name == source-name))
    (
      dc: 8 + pb + amod + b.map(x => x.dc).sum(default: 0),
      attack: pb + amod + b.map(x => x.attack).sum(default: 0),
    )
  }

  let sources = effects.filter(e => e.effect == "spellcasting").map(e => {
    let amod = mods.at(e.ability)
    let (dc, attack: atk) = source-stats(e.source, amod)
    // If this spellcasting source came from a class feature (class-source set),
    // also include item bonuses scoped to that class.  E.g., Magic Initiate
    // via Lessons of the First Ones is a Warlock spell — the Rod of the Pact
    // Keeper applies to its own free cast as well.
    // - Skip when cs == e.source: the class's own spellcasting source already
    //   matched via source-stats (source-name == "Warlock" filters the same
    //   bonus), so adding it again would double-count.
    let cs = e.at("class-source", default: none)
    if cs != none and cs != e.source {
      let class-bonus = effects.filter(x =>
        x.effect == "spellcasting-bonus"
        and x.source-name != none
        and x.source-name == cs
      )
      dc += class-bonus.map(x => x.dc).sum(default: 0)
      atk += class-bonus.map(x => x.attack).sum(default: 0)
    }
    // Source-level default slot, such as the warlock pact slot level.
    // - A spell entry can override it with (spell: s, slot: N).
    // - A bare entry uses this default, or the spell's own base level when there is none.
    let source-slot = e.at("prepared-at", default: none)

    (
      source: e.source,
      ability: e.ability,
      // Keep the casting ability's own modifier here; `attack` can include item bonuses (Rod of the Pact Keeper), so display reads this field directly.
      modifier: amod,
      kind: e.at("kind", default: "innate"),
      save-dc: dc,
      attack: atk,
      cantrips: e.cantrips.map(s => s.name),
      spells: e.spells.map(entry => _unpack-spell-entry(entry).first().name),
      spells-detail: e.cantrips.map(s => _spell-detail(s, e.source, dc, atk, level, spell-bonuses, cast-mod: amod))
        + e.spells.map(entry => {
            let (s, per-spell-slot) = _unpack-spell-entry(entry)
            let slot = if per-spell-slot != none { per-spell-slot }
                       else if source-slot != none { source-slot }
                       else { s.at("level", default: 1) }
            let fixed = per-spell-slot != none or source-slot != none
            _spell-detail(s, e.source, dc, atk, level, spell-bonuses, slot: slot, fixed-slot: fixed, cast-mod: amod)
          }),
      slots: e.at("slots", default: (:)),
      // Keep `default-slot` only for the any-slot projection below.
      // - Display skips this field.
      default-slot: source-slot,
    )
  })

  // A feat-granted spell can also be cast with any spell slot the character has (Magic Initiate, Fey Touched — `eff-spell-any-slot`).
  // - Project such a spell into every other spellcasting source that has slots.
  // - Resolve it as a bare spell entry of that source: the source's `default-slot`, or the spell's own base level for a multi-level caster.
  // - Take the DC and attack from the granting feat's own ability; a borrowed slot keeps the spell's owner.
  // - Inherit the host source's item bonuses (e.g., Rod of the Pact Keeper +2 for
  //   Warlock) only when the granting feature came from that class (class-source
  //   matches the host source's name — e.g., Magic Initiate via Lessons of the
  //   First Ones). Background/origin-feat spells have no class-source and keep
  //   the feat's own numbers.
  let any-slot = effects.filter(e => e.effect == "spell-any-slot")
  if any-slot.len() == 0 { sources } else {
    sources.map(src => {
      if src.slots.len() == 0 { return src }
      let extra = any-slot.filter(e => e.source != src.source).map(e => {
        let amod = mods.at(e.ability)
        let (dc, attack: atk) = source-stats(e.source, amod)
        // Inherit item bonuses scoped to the host source when the spell
        // originated from a feature of that class (e.g., Warlock invocation).
        let host-dc = 0
        let host-atk = 0
        if e.at("class-source", default: none) == src.source {
          let host-bonus = effects.filter(x =>
            x.effect == "spellcasting-bonus"
            and x.source-name != none
            and x.source-name == src.source
          )
          host-dc = host-bonus.map(x => x.dc).sum(default: 0)
          host-atk = host-bonus.map(x => x.attack).sum(default: 0)
        }
        let slot = if src.default-slot != none { src.default-slot } else { e.spell.at("level", default: 1) }
        _spell-detail(e.spell, e.source, dc + host-dc,
          atk + host-atk, level, spell-bonuses,
          slot: slot, fixed-slot: src.default-slot != none, cast-mod: amod)
      })
      src + (spells-detail: src.spells-detail + extra)
    })
  }
}

// Resolve spells cast from magic items (e.g. Staff of the Woodlands, Staff of Power).
// - Each equipped feature with a non-empty `spells:` list projects into an item spell table.
// - Uses the character's spell save DC and spell attack bonus (from spellcasting sources or ability mods).
#let resolve-item-spells(features, sources, level, mods, pb, effects) = {
  let spell-bonuses = (:)
  for e in effects.filter(e => e.effect == "spell-damage-bonus") {
    let v = if e.ability != none { mods.at(e.ability) } else { e.value }
    let key = lower(e.spell).replace("-", " ")
    spell-bonuses.insert(key, spell-bonuses.at(key, default: 0) + v)
  }

  let item-features = features.filter(f => f.at("kind", default: none) == "magic-item" and f.at("spells", default: ()).len() > 0)
  item-features.map(f => {
    let (dc, atk) = if sources.len() > 0 {
      let src = if f.at("source-name", default: none) != none {
        sources.find(s => s.source == f.source-name)
      } else { none }
      if src != none {
        (src.save-dc, src.attack)
      } else {
        (sources.map(s => s.save-dc).fold(0, calc.max), sources.map(s => s.attack).fold(0, calc.max))
      }
    } else {
      let max-mod = mods.values().fold(0, calc.max)
      let b = effects.filter(x => x.effect == "spellcasting-bonus" and x.source-name == none)
      (
        8 + pb + max-mod + b.map(x => x.dc).sum(default: 0),
        pb + max-mod + b.map(x => x.attack).sum(default: 0),
      )
    }

    let projected = f.spells.map(entry => {
      let (s, slot, charges) = if type(entry) == dictionary and "spell" in entry {
        (entry.spell, entry.at("slot", default: none), entry.at("charges", default: 1))
      } else {
        (entry, none, 1)
      }
      let eff-slot = if slot != none { slot } else { s.at("level", default: 1) }
      let detail = _spell-detail(s, f.name, dc, atk, level, spell-bonuses, slot: eff-slot, fixed-slot: true)
      detail + (charges: charges, ritual: false)
    })
    (
      name: f.name,
      spells: projected,
    )
  })
}

// Increase a melee attack's reach by the reach bonus in feet.
// - A melee weapon's `range` is its reach, so it always increases; a Thrown weapon's throw range lives in its own `thrown-range` field and stays unchanged.
#let _apply-reach(range, reach) = {
  if reach == 0 or range == none { return range }
  let m = range.match(regex("^(\d+)\s*ft$"))
  if m == none { return range }
  str(int(m.captures.at(0)) + reach) + " ft"
}

// One damage string: the dice with the signed ability modifier and magic bonus. A net +0 does not show.
// - Shared by `_attack-line` and the Versatile alternative grip, which shows the same arithmetic for the die the character is not rolling.
#let _damage-string(damage-dice, ability, scores, magic-bonus) = (
  damage-dice + _signed(modifier(scores.at(ability)) + magic-bonus)
)

// Build one computed attack line, shared by the unarmed strike and every weapon.
// - Attack bonus = ability modifier + magic bonus, plus PB when proficient.
#let _attack-line(name, ability, damage-dice, damage-type, range, properties, proficient, scores, pb, magic-bonus: 0, kind: "melee", thrown-range: none) = {
  let amod = modifier(scores.at(ability))
  let dmg = _damage-string(damage-dice, ability, scores, magic-bonus)
  (
    name: name,
    ability: ability,
    bonus: amod + if proficient { pb } else { 0 } + magic-bonus,
    damage: dmg,
    damage-type: damage-type,
    range: range,
    thrown-range: thrown-range,
    properties: properties,
    proficient: proficient,
    extra-attack: true,
    kind: kind,
  )
}

// Build the True Strike variant of a weapon.
// - The cantrip attacks with the weapon, but uses the caster's spellcasting `ability` for attack and damage, and deals Radiant damage.
// - Proficiency is necessary; the attack bonus is PB + that ability modifier + the magic bonus.
// - Extra Radiant dice scale with level: +1d6 at 5, +2d6 at 11, +3d6 at 17.
// - `dice` is the weapon's damage die in the grip the character wields it in (see `resolve-attacks`), since the cantrip attacks with that weapon.
#let _true-strike-line(e, ability, scores, pb, level, properties, dice) = {
  // Always proficient, thus `_attack-line` adds PB; the damage type is the cantrip's own.
  let line = _attack-line(
    e.name, ability, dice, "Radiant", e.range, properties, true, scores, pb,
    magic-bonus: e.at("bonus", default: 0), kind: e.kind, thrown-range: e.thrown-range,
  )
  let extra = if level >= 17 { "3d6" } else if level >= 11 { "2d6" } else if level >= 5 { "1d6" } else { none }
  line + (
    via-spell: "True Strike",
    extra-attack: false,
    damage: if extra != none { line.damage + " + " + extra } else { line.damage },
  )
}

// Build the Shillelagh variant of a weapon.
// - The cantrip imbues a Club or Quarterstaff the caster holds; the weapon keeps making a weapon attack.
// - Attack and damage use the caster's spellcasting `ability` instead of Strength.
// - The weapon's damage die becomes a d8, growing at levels 5 (d10), 11 (d12), and 17 (2d6).
// - The damage type stays the weapon's own; the caster may choose Force instead on a hit.
#let _shillelagh-line(e, ability, scores, pb, level, properties, proficient) = {
  let die = if level >= 17 { "2d6" } else if level >= 11 { "1d12" } else if level >= 5 { "1d10" } else { "1d8" }
  _attack-line(
    e.name, ability, die, e.damage-type, e.range, properties, proficient, scores, pb,
    magic-bonus: e.at("bonus", default: 0), kind: e.kind, thrown-range: e.thrown-range,
  ) + (via-spell: "Shillelagh", extra-attack: false)
}

// Build the universal unarmed strike (1 + Str bludgeoning, always proficient), then one line for each wielded weapon.
// - An `eff-unarmed` effect overrides the unarmed strike's fields (Tortle Claws → 1d6 slashing); it does not add a line.
// - Three weapon-attack cantrips expand into more lines here. Each keeps the weapon's own `name` and carries the cantrip in `via-spell`; the layout composes the "<weapon> (<Spell>)" label and italicizes the spell half, so the split stays a display concern.
// - True Strike (`ts-ability` = its casting ability): each proficient weapon gets a line cast with that ability, which deals Radiant damage (see `_true-strike-line`).
// - Booming Blade (`bb-note` = its authored rider prose): each melee weapon gets a line that reuses the weapon's own hit and damage, because Booming Blade makes a normal weapon attack.
// - `bb-note` fills that line's Notes cell; the booming rider does no guaranteed on-hit damage, so it stays out of the Damage column.
// - Shillelagh (`sh-ability` = its casting ability): each eligible weapon (Club, Quarterstaff) gets a line cast with that ability and a larger die (see `_shillelagh-line`).
#let resolve-attacks(effects, scores, pb, weapon-profs, pact-blade-ability, level, ts-ability, mastered, bb-note: none, sh-ability: none, reach: 0) = {
  let u = (name: "Unarmed Strike", ability: "str", damage: "1", damage-type: "Bludgeoning")
  for e in effects.filter(e => e.effect == "unarmed") {
    if e.damage != none { u.damage = e.damage }
    if e.damage-type != none { u.damage-type = e.damage-type }
    if e.ability != none { u.ability = e.ability }
    if e.name != none { u.name = e.name }
  }

  let unarmed = _attack-line(u.name, u.ability, u.damage, u.damage-type, _apply-reach("5 ft", reach), (), true, scores, pb)

  let lines = (unarmed,)
  for e in effects.filter(e => e.effect == "weapon") {
    // Pact of the Blade: for a melee or magic weapon, the bond gives proficiency and lets the warlock attack with the spellcasting ability.
    // - This applies whatever the weapon's category or its own default ability is.
    // - The bonded weapon can change each turn, so this is not keyed to a name.
    let is-magic = e.at("bonus", default: 0) != 0
    let pact = pact-blade-ability != none and (e.kind == "melee" or is-magic)

    // Default attack ability: Pact of the Blade spellcasting ability first, then an explicit ability, then Dex for ranged and Str for melee.
    // - A Finesse weapon with no explicit ability and no pact uses the better of Str and Dex.
    let abil = if pact { pact-blade-ability } else if e.ability != none { e.ability } else if e.kind == "ranged" { "dex" } else { "str" }
    if not pact and e.ability == none and e.properties.map(lower).contains("finesse") {
      abil = if modifier(scores.dex) >= modifier(scores.str) { "dex" } else { "str" }
    }
    // Proficient when the pact applies, or when the character is trained with the weapon's category ("martial") or its specific name.
    // - The 2024 Rogue gets its martial-finesse and light weapons by name.
    // - Match the catalog name, not the display name: a "Shortsword +1" is still a Shortsword.
    let base-name = lower(e.at("base-name", default: e.name))
    let proficient = (pact
      or weapon-profs.contains(e.category)
      or weapon-profs.map(lower).contains(base-name))
    // Versatile: the weapon deals its `versatile` die in two hands, its own `damage` die in one.
    // - `two-handed` is the declared grip, so it picks the die every line for this weapon rolls; the True Strike and Booming Blade lines attack with the same weapon.
    let versatile = e.at("versatile", default: none)
    let two-handed = e.at("two-handed", default: false)
    let dice = if two-handed { versatile } else { e.damage }
    let magic = e.at("bonus", default: 0)
    // Show a weapon's mastery property only when the character has trained mastery with that weapon; then keep it in its own `mastery` field as a plain string.
    // - Keep the mastery out of `properties`, so display can set it apart from the ordinary properties.
    // - Drop the mastery fully when the character is untrained with the weapon.
    // - Versatile leaves `properties` too, for the same reason: what it says depends on the character. It comes back as `versatile-damage`, the full damage of the grip the character is not using, and `versatile-grip`, naming that grip. The Damage column gives the grip in use; the Notes cell gives the other one, modifier included.
    let props = e.properties.filter(p => not weapon-mastery-names.contains(p) and p != "Versatile")
    let mastery = if mastered.contains(base-name) {
      e.properties.find(p => weapon-mastery-names.contains(p))
    } else { none }
    // The alternative damage takes the ability the line attacks with: True Strike swings the same weapon off the caster's spellcasting ability, so its line shows a Wis- or Cha-based alternative like its own damage.
    let versatile-fields = a => if versatile == none { (:) } else {
      (
        versatile-damage: _damage-string(if two-handed { e.damage } else { versatile }, a, scores, magic),
        versatile-grip: if two-handed { "one-handed" } else { "two-handed" },
      )
    }
    // A melee attack gets the reach bonus (Bugbear Long-Limbed); a ranged attack, and a Thrown weapon's throw range, do not.
    let rng = if e.kind == "melee" { _apply-reach(e.range, reach) } else { e.range }
    let wline = (.._attack-line(e.name, abil, dice, e.damage-type, rng, props, proficient, scores, pb, magic-bonus: magic, kind: e.kind, thrown-range: e.thrown-range), mastery: mastery, ..versatile-fields(abil))
    lines.push(wline)
    // True Strike works only with a proficient weapon worth at least 1 CP; the weapon carries that eligibility.
    // - The line is still an attack with that weapon, so its mastery property applies and shows the same.
    if ts-ability != none and proficient and e.at("true-strike", default: true) {
      lines.push((.._true-strike-line(e, ts-ability, scores, pb, level, props, dice), mastery: mastery, ..versatile-fields(ts-ability)))
    }
    // Booming Blade: a normal melee weapon attack, with the same hit and damage as `wline`.
    // - Put the booming rider in the Notes cell.
    // - Add the line for melee weapons only.
    if bb-note != none and e.kind == "melee" {
      lines.push((..wline, via-spell: "Booming Blade", extra-attack: false, note: bb-note))
    }
    // Shillelagh imbues only a Club or a Quarterstaff; the weapon carries that eligibility.
    // - The line is still an attack with that weapon, so its mastery property applies and shows the same.
    if sh-ability != none and e.at("shillelagh", default: false) {
      lines.push((.._shillelagh-line(e, sh-ability, scores, pb, level, props, proficient), mastery: mastery))
    }
  }
  lines
}

// Apply the additive and override numeric stat effects to a starting value.
// - A "proficiency"-kind effect adds the proficiency bonus (Alert's +PB Initiative).
// - Evaluate a function `value` against `ctx` (pb / level / ability-mods); Tough's `ctx => 2 * ctx.level` HP bonus.
#let resolve-stat(effects, which, start, pb: 0, ctx: none) = {
  let v = start
  for e in effects.filter(e => e.effect == "stat" and e.which == which) {
    let value = if type(e.value) == function { (e.value)(ctx) } else { e.value }
    if e.kind == "set" { v = value }
    else if e.kind == "proficiency" { v += pb }
    else { v += value }
  }
  v
}

// Compute the maximum HP by the 5.5e fixed rule.
// - The first level of the first declared class gives the die's maximum.
// - Every other level gives die/2 + 1.
// - The Con modifier applies for each character level.
// - Tough and related features arrive as `eff-stat("hp")` bonuses; the caller folds them in.
#let fixed-max-hp(class-features, con-mod, level) = {
  let hp = 0
  let first = true
  for cls in class-features {
    let die = int(cls.at("hit-die", default: "d8").slice(1))
    let lv = cls.at("level", default: 0)
    if lv <= 0 { continue }
    let per-level = calc.floor(die / 2) + 1
    hp += if first { die + (lv - 1) * per-level } else { lv * per-level }
    first = false
  }
  hp + con-mod * level
}

// Find the weapon-attack cantrips' inputs to `resolve-attacks` in the spellcasting sources' cantrip lists.
// - True Strike gives the ability of the source that knows it, for the per-weapon lines.
// - Booming Blade gives its authored rider prose, for each melee line's Notes cell.
// - Shillelagh gives the ability of the source that knows it, for the Club and Quarterstaff lines.
#let _weapon-cantrip-inputs(effects) = {
  let source-of = name => effects.find(e =>
    e.effect == "spellcasting" and e.cantrips.any(s => s.name == name))
  let ts-source = source-of("True Strike")
  let bb-source = source-of("Booming Blade")
  let sh-source = source-of("Shillelagh")
  (
    ts-ability: if ts-source != none { ts-source.ability } else { none },
    bb-note: if bb-source != none {
      bb-source.cantrips.find(s => s.name == "Booming Blade").at("notes", default: none)
    } else { none },
    sh-ability: if sh-source != none { sh-source.ability } else { none },
  )
}

// Attacks per Attack action: the largest `eff-extra-attack` count, or 1 by default.
#let resolve-attacks-per-action(effects) = {
  effects
    .filter(e => e.effect == "extra-attack")
    .fold(1, (apa, e) => calc.max(apa, e.count))
}

// ---------------------------------------------------------------------------
// Display-only collectors: each folds one display-only effect family into the flat list its layout surface renders.
// - None of them changes a computed number, except where noted.
// ---------------------------------------------------------------------------

// Conditional save advantages, one entry for each effect (see `eff-save-advantage`).
#let resolve-save-advantages(effects) = {
  effects
    .filter(e => e.effect == "save-advantage")
    .map(e => (note: e.note, source: e.source))
}

// Damage responses: Resistance, Immunity, Vulnerability.
// - Dedupe by (kind, type); two sources of the same response give one line.
// - Declaration order stays.
#let resolve-resistances(effects) = dedup-by(
  effects
    .filter(e => e.effect == "resistance")
    .map(e => (type: e.type, kind: e.kind, source: e.source)),
  r => r.kind + "/" + lower(r.type),
)

// Special senses (Darkvision, Blindsight, ...).
// - Senses with the same name do not stack; keep the one with the longest range.
// - Parse the range from the leading integer of the range string.
// - A rangeless sense counts as 0.
#let resolve-senses(effects) = {
  let by-name = (:)
  for e in effects.filter(e => e.effect == "sense") {
    let key = lower(e.name)
    let r = if e.range == none { 0 } else {
      let m = e.range.match(regex("[0-9]+"))
      if m == none { 0 } else { int(m.text) }
    }
    let prev = by-name.at(key, default: none)
    if prev == none or r > prev.range-val {
      by-name.insert(key, (name: e.name, range: e.range, source: e.source, range-val: r))
    }
  }
  by-name.values().map(s => (name: s.name, range: s.range, source: s.source))
}

// Limited-use resources (Innate Sorcery, Lucky, Wails from the Grave, ...).
// - `uses` may be a literal int or a function of the computed context (pb / level / ability-mods); evaluate it now to a concrete count so the tracker renders a fixed number of diamonds.
// - Sort order (shared by both layouts): short-rest pools before long-rest pools.
// - Within a group, the most scarce (fewest uses) comes first.
// - Ties break alphabetically.
// - `short-or-long` recharges on a short rest, so it groups with short.
// - `long-short-regain` and `dawn` do not recharge on a short rest, so both group with long; the partial refill each adds is conveyed by a footnote in the layout, not by the column.
// - Built as one padded string key ("<rank>-<uses>-<name>") so a single string compare orders all three levels.
#let resolve-limited-uses(effects, ctx) = {
  let rank = ("short": 0, "short-or-long": 1, "long": 2, "long-short-regain": 2, "dawn": 2)
  effects
    .filter(e => e.effect == "limited-use")
    .map(e => (
      name: e.name,
      spell: e.at("spell", default: false),
      uses: if type(e.uses) == function { (e.uses)(ctx) } else { e.uses },
      uses-label: e.uses-label,
      recharge: e.recharge,
      source: e.source,
    ))
    .sorted(key: e => (
      str(rank.at(e.recharge, default: 9))
        + "-" + (if e.uses < 10 { "0" } else { "" }) + str(e.uses)
        + "-" + lower(e.name)
    ))
}

// Cunning Strike options (2024 Rogue, level 5), display-only except for the DC.
// - Not a spellcasting source; gets its own step rather than going through `eff-spellcasting`.
// - DC = 8 + PB + Dex mod (the Rogue's own DC; fixed across every option's target save), computed once and stamped on every option.
// - Declaration order preserved.
#let resolve-cunning-strikes(effects, pb, mods) = {
  let dc = 8 + pb + mods.dex
  effects
    .filter(e => e.effect == "cunning-strike")
    .map(e => (
      name: e.name, cost: e.cost, save-ability: e.save-ability,
      save-dc: dc, note: e.note, source: e.source,
    ))
}

// Top-level entry point: declared character -> fully computed record.
#let resolve(char) = {
  let effects = collect-effects(char)
  let scores = resolve-abilities(char.abilities, effects)
  let mods = (:)
  for id in ability-ids { mods.insert(id, modifier(scores.at(id))) }

  // Total level is the sum of class-feature levels; fall back to declared level.
  let class-features = char.features.filter(f => f.at("kind", default: none) == "class")
  let level = class-features.map(f => f.at("level", default: 0)).sum(default: 0)
  if level == 0 { level = char.at("level", default: 1) }
  let pb = prof-bonus(level)

  // Shared computed context for feature-authored functions.
  // - `eff-limited-use`'s `uses`, `eff-stat`'s `value`, and a trait's `notes`/`desc` all accept either a literal value or a function of (pb, level, ability-mods), evaluated once resolved values exist.
  let ctx = (pb: pb, level: level, ability-mods: mods)

  let skills = resolve-skills(scores, effects, pb)
  // A passive score is 10 plus the skill's check bonus, raised by 5 with Advantage on that check (SRD 5.2.1 §Passive Perception; `eff-check-advantage` stamps the flag).
  let passive = which => {
    let sk = skills.at(which)
    10 + sk.bonus + if sk.advantage { 5 } else { 0 }
  }

  let weapon-profs = collect-profs(effects, "weapon")
  // Pact of the Blade's spellcasting ability (none if the character lacks it); the resolver treats melee/magic weapons as proficient + cast-ability attacks.
  let pact-blade = effects.find(e => e.effect == "pact-blade")
  let pact-blade-ability = if pact-blade != none { pact-blade.ability } else { none }
  // Weapon names (lowercased) the character has trained mastery with.
  let mastered = effects.filter(e => e.effect == "weapon-mastery").map(e => e.weapons).flatten()
  // Total melee-reach bonus (in feet), stacking across sources.
  let reach = effects.filter(e => e.effect == "reach").fold(0, (a, e) => a + e.value)
  let species = char.features.find(f => f.at("kind", default: none) == "species")

  // Weapon-attack cantrips (True Strike / Booming Blade) expand into per-weapon attack lines (see `_weapon-cantrip-inputs` / `resolve-attacks`).
  let wc = _weapon-cantrip-inputs(effects)

  let attacks = resolve-attacks(effects, scores, pb, weapon-profs, pact-blade-ability, level, wc.ts-ability, mastered, bb-note: wc.bb-note, sh-ability: wc.sh-ability, reach: reach)

  // A feature that casts a spell from itself (a wand's Magic Action) declares `casts:`, and resolves to the same `_spell-detail` the spell tables use, under `cast`. The layouts' action note reads its range and damage from there instead of restating them as prose.
  // - The entry takes `eff-spellcasting`'s own `spells:` shape: a bare spell, or `(spell: s, slot: N)` to pin the cast level a charge buys.
  // - `fixed-slot`: charges, not slots, set that level, so the note must not offer the upcast affordance.
  // - No save DC and no attack bonus: an item is not a spellcasting source (see items.typ), and an item that needed its own DC would have to carry it. Nothing reads those fields for a cast — `item-action-note` takes only the name, count, range and damage.
  // - No `spell-bonuses` either: an `eff-spell-damage-bonus` is the character's, and the wand's darts are the wand's.
  let with-cast = t => {
    let c = t.at("casts", default: none)
    if c == none { return t }
    let (s, slot) = _unpack-spell-entry(c)
    t + (cast: _spell-detail(s, t.name, none, none, level, (:), slot: slot, fixed-slot: true) + (ritual: false))
  }
  let traits = dedup-by(
    flatten-features(char.features).map(t => {
      let n = t.at("notes", default: none)
      let d = t.at("desc", default: none)
      let t = if type(n) == function { t + (notes: (n)(ctx)) } else { t }
      let t = if type(d) == function { t + (desc: (d)(ctx)) } else { t }
      with-cast(t)
    }),
    t => t.name
  )

  // Gear splits into two lists by whether its effects are live.
  // - The split carries meaning: EQUIPPED gear shapes the sheet (armor sets AC, a rod raises DCs, a weapon makes an attack line); INVENTORY gear is inert cargo.
  // - A bare gear feature is equipped (its effects apply); `carried(...)` marks the inert case (skipped by `flatten-features`, so nothing about it is live); the declared `equipment:` strings are inert by construction.
  // - Top-level features only; a nested magic-item child (the Rod's activated power) is a sub-feature of its item, separate from an item itself.
  // - Magic gear carries the `*` marker in both lists: any magic-item feature, or a weapon with a magic attack bonus.
  let gear-entry = f => {
    let magic = (f.at("kind", default: none) == "magic-item"
      or f.at("effects", default: ()).any(e => e.effect == "weapon" and e.at("bonus", default: 0) != 0))
    f.name + if magic { "*" } else { "" }
  }
  let is-gear = f => ("weapon", "armor", "shield", "magic-item").contains(f.at("kind", default: none))
  let equipped = char.features
    .filter(f => is-gear(f) and not f.at("carried", default: false))
    .map(gear-entry)
  let carried-gear = char.features
    .filter(f => is-gear(f) and f.at("carried", default: false))
    .map(gear-entry)

  // Max HP: `auto` (default) computes the 5.5e fixed-rule maximum; a declared int overrides it (rolled HP).
  // - Either way `eff-stat("hp")` bonuses (Tough) fold on top.
  let base-hp = {
    let declared = char.at("max-hp", default: auto)
    if declared == auto { fixed-max-hp(class-features, mods.con, level) } else { declared }
  }

  (
    name: char.name,
    player: char.at("player", default: none),
    alignment: char.at("alignment", default: none),
    species: species,
    size: if species != none { species.at("size", default: none) } else { none },
    creature-type: if species != none { species.at("creature-type", default: none) } else { none },
    background: {
      let bg = char.features.find(f => f.at("kind", default: none) == "background")
      if bg != none { bg.name } else { char.at("background", default: none) }
    },
    classes: class-features,
    faction: char.faction,
    // Every named feature/trait, sub-features included (for display). `notes` functions have been evaluated against `ctx` above.
    traits: traits,
    level: level,
    proficiency-bonus: pb,
    abilities: scores,
    ability-mods: mods,
    ac: resolve-ac(scores, effects),
    initiative: resolve-stat(effects, "initiative", mods.dex, pb: pb, ctx: ctx),
    speed: resolve-stat(effects, "speed", char.at("speed", default: 30), ctx: ctx),
    max-hp: resolve-stat(effects, "hp", base-hp, ctx: ctx),
    temp-hp: resolve-stat(effects, "temp-hp", 0, ctx: ctx),
    skills: skills,
    saves: resolve-saves(scores, effects, pb),
    passives: (
      perception: passive("perception"),
      investigation: passive("investigation"),
      insight: passive("insight"),
    ),
    proficiencies: (
      armor: collect-profs(effects, "armor"),
      weapon: collect-profs(effects, "weapon"),
      tool: collect-profs(effects, "tool"),
      language: collect-profs(effects, "language"),
    ),
    spellcasting: resolve-spellcasting(effects, mods, pb, level),
    item-spells: resolve-item-spells(flatten-features(char.features), resolve-spellcasting(effects, mods, pb, level), level, mods, pb, effects),
    attacks: attacks,
    attacks-per-action: resolve-attacks-per-action(effects),
    equipped: equipped,
    equipment: carried-gear + char.at("equipment", default: ()),
    currency: char.at("currency", default: none),
    backstory: char.at("backstory", default: none),
    // The display-only collections (see the collectors above).
    save-advantages: resolve-save-advantages(effects),
    resistances: resolve-resistances(effects),
    senses: resolve-senses(effects),
    limited-uses: resolve-limited-uses(effects, ctx),
    cunning-strikes: resolve-cunning-strikes(effects, pb, mods),
    metamagic: traits.filter(t => t.at("via-name", default: none) == "Metamagic"),
    raw: char,
  )
}
