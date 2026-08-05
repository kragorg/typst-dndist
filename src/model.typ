// Character DSL and effect constructors.
// - A character is declared data plus a list of `features`.
// - Each feature carries tagged `effect` records.
// - `resolve.typ` folds the effects into the computed character.
// - This file describes only; it computes nothing.

// ---------------------------------------------------------------------------
// Effect constructors
//
// `source` policy:
// - Display-only effects carry a `source` (save advantages, senses, resistances, limited uses, cunning strikes, reach, unarmed overrides, AC candidates).
// - Numeric effects carry none; nothing displays their origin (abilities, proficiencies, stats, weapons).
// ---------------------------------------------------------------------------

// Normalize a game-object reference to its string id.
// - Accept an object with an `id` (ability / skill / tool) or a bare string.
#let id-of(ref) = if type(ref) == dictionary and "id" in ref { ref.id } else { ref }

// `id-of` for an optional reference; `none` stays `none`.
#let id-of-or-none(ref) = if ref == none { none } else { id-of(ref) }

// Ability score contribution.
// - `kind`: "base" | "background" | "bonus" add; "set" forces a fixed final score (highest precedence).
// - The additive kinds are tags only; the resolver folds them identically.
#let eff-ability(which, value, kind: "bonus") = (
  effect: "ability", which: id-of(which), kind: kind, value: value,
)

// Armor AC base and Dex cap.
// - `cap: none` = unlimited Dex bonus (light armor).
#let eff-ac-base(base, cap: none, source: none) = (
  effect: "ac", kind: "base", base: base, cap: cap, source: source,
)

// Alternate unarmored AC formula: `base` plus the modifiers of `abilities`.
// - Mage Armor = 13 + Dex; Unarmored Defense = 10 + Dex + Con.
// - Dex is not capped here.
// - The best candidate base wins at resolve time.
#let eff-ac-formula(base, abilities: ("dex",), source: none) = (
  effect: "ac", kind: "formula", base: base, abilities: abilities.map(id-of), source: source,
)

// Flat bonus that stacks on the chosen base (shield +2, ring +1).
#let eff-ac-bonus(value, source: none) = (
  effect: "ac", kind: "bonus", value: value, source: source,
)

// Force a fixed final AC; ignore all bases and formulas.
// - Flat bonuses still apply on top.
#let eff-ac-set(value, source: none) = (
  effect: "ac", kind: "set", value: value, source: source,
)

// Proficiency.
// - `category`: "skill" | "save" | "tool" | "language" | "armor" | "weapon".
// - `level`: "proficient" | "expertise" (skills and tools only).
#let eff-prof(category, key, level: "proficient") = (
  effect: "proficiency", category: category, key: id-of(key), level: level,
)

// Conditional advantage on a saving throw.
// - `note`: markup prose that states when the advantage applies.
// - Display-only; stays out of computed numbers.
// - Layouts footnote it with an "advantage" badge below the saves.
#let eff-save-advantage(note, source: none) = (
  effect: "save-advantage", note: note, source: source,
)

// Advantage on every check with one skill (Boots of Elvenkind: Dexterity (Stealth)).
// - Display-only; stays out of computed numbers.
// - Resolver stamps `advantage` on that skill; layouts badge the skill row.
// - The advantage covers the whole skill, thus the row states it and no prose is needed.
#let eff-check-advantage(skill, source: none) = (
  effect: "check-advantage", skill: id-of(skill), source: source,
)

// Damage response: Resistance / Immunity / Vulnerability to a damage type.
// - `kind`: "resistance" (default) | "immunity" | "vulnerability".
// - Display-only; stays out of computed numbers.
// - Resolver collects it into a flat `resistances` list.
// - Layouts show it in the Defenses & Senses footnote, grouped by kind, after the save advantages and before the senses.
#let eff-resistance(damage-type, kind: "resistance", source: none) = (
  effect: "resistance", type: damage-type, kind: kind, source: source,
)

// Special sense: Darkvision, Blindsight, Truesight, Tremorsense.
// - `range`: a reach string ("60 ft") or `none` for a rangeless sense.
// - Display-only; stays out of computed numbers.
// - Layouts list it below the saves in the NOTES section.
// - Senses with the same name merge; the resolver keeps the longest range.
#let eff-sense(name, range: none, source: none) = (
  effect: "sense", name: name, range: range, source: source,
)

// Limited-use resource: a feature with bounded uses that recharge on a rest.
// - `uses`: int or function `(ctx) => int`; the resolver evaluates the function with `ctx = (pb, level, ability-mods)`.
// - Function form derives the count from PB, an ability modifier, or the level.
// - `uses-label`: optional derivation label ("PB", "CHA mod", "½ level").
// - The label shows beside the diamonds. Use `none` for a literal count.
// - `recharge`: "long" | "short" | "short-or-long" | "long-short-regain" | "dawn".
// - "long"/"short"/"short-or-long": regain all uses on the named rest.
// - "long-short-regain": regain all uses on a Long Rest and one expended use on a Short Rest (Wild Shape, Second Wind).
// - "dawn": regain 1 expended use each dawn, on no rest at all (a charged magic item).
// - A pool that regains a *rolled* amount at dawn (a wand's 1d6+1) is not this kind: the note states a fixed 1, so that item keeps "long" and its own desc carries the dice.
// - The last two sort into the Long Rest column, which cannot state their partial refill; the layout footnotes each (see `_recharge-notes`).
// - Display-only; no numeric resolver reads it.
// - The count is still computed.
// - Both layouts render the `limited-uses` list as a diamond tracker labelled by the feature `name` alone.
// - `name` takes a **spell object** as readily as a string (the `id-of` idiom): a pool that tracks a free cast passes `spell.misty-step`, never the name typed out again. The object form sets `spell: true`, and the resource tables italicize that row — a spell reads as a spell wherever the sheet names one.
#let eff-limited-use(name, uses, recharge: "long", uses-label: none, source: none) = (
  effect: "limited-use",
  name: if type(name) == str { name } else { name.name },
  spell: type(name) != str,
  uses: uses, recharge: recharge,
  uses-label: uses-label, source: source,
)

// Flat bonus to all saving throws (Cloak/Ring of Protection +1).
// - Folds into every computed save.
#let eff-save-bonus(value, source: none) = (
  effect: "save-bonus", value: value, source: source,
)

// Bonus to a spellcasting source's attack bonus and/or save DC (Rod of the Pact Keeper).
// - `source-name`: apply the bonus only to the source with that display name ("Pact Magic").
// - `source-name: none`: apply the bonus to every source.
// - Scope the bonus when a character has several sources; a feat's DC must not gain a warlock rod's bonus.
#let eff-spellcasting-bonus(attack: 0, dc: 0, source-name: none) = (
  effect: "spellcasting-bonus", attack: attack, dc: dc, source-name: source-name,
)

// Class skill rules: "reliable-talent" or "jack-of-all-trades".
#let eff-skill-rule(rule) = (effect: "skill-rule", rule: rule)

// Bonus to one skill.
// - `ability`: also add that ability's modifier, raised to `min-value` if set.
// - Powers Primal Order (Magician): +Wis mod (min +1) to Arcana and Nature.
#let eff-skill-bonus(which, value: 0, ability: none, min-value: none, source: none) = (
  effect: "skill-bonus",
  which: id-of(which),
  value: value,
  ability: id-of-or-none(ability),
  min-value: min-value,
  source: source,
)

// Wielded weapon; the resolver turns it into a computed attack line.
// - `category`: "simple" | "martial"; drives proficiency.
// - `kind`: "melee" | "ranged"; sets the default attack ability (Str/Dex) when `ability` is none.
// - `damage`: dice string ("1d8"); the resolver appends the signed ability modifier.
// - `range`: the range the attack is made at — a melee weapon's reach ("5 ft"), a ranged weapon's projectile range ("80/320 ft").
// - `thrown-range`: the Thrown property's own range ("20/60 ft"), separate from `range` so a Thrown melee weapon keeps its reach and reach bonuses apply to that reach alone.
// - `bonus`: flat magic bonus to attack roll and damage (1 for a +1 weapon).
// - `base-name`: the catalog weapon's own name, which by-name proficiency and mastery match against. It defaults to `name` and survives a `magic-weapon` rename, so a "Shortsword +1" still counts as a Shortsword.
// - `true-strike: false` marks a weapon the True Strike cantrip cannot use (a Shadow Blade).
// - When the character knows True Strike, `resolve-attacks` adds a second attack line for each eligible proficient weapon.
// - `shillelagh: true` marks a weapon the Shillelagh cantrip can imbue; the spell names only the Club and the Quarterstaff.
// - When the character knows Shillelagh, `resolve-attacks` adds a second attack line for each such weapon.
// - `versatile`: the damage die a Versatile weapon deals in two hands ("1d10" for a Longsword). Weapon data: every Versatile weapon carries it, whatever grip a character uses.
// - `two-handed`: the grip this character wields the weapon in, set by `two-handed()` (weapons.typ). It picks which of the two dice the attack line rolls.
#let eff-weapon(
  name,
  category: "simple",
  kind: "melee",
  ability: none,
  damage: "",
  damage-type: none,
  range: none,
  thrown-range: none,
  properties: (),
  bonus: 0,
  base-name: auto,
  true-strike: true,
  shillelagh: false,
  versatile: none,
  two-handed: false,
) = (
  effect: "weapon",
  name: name,
  base-name: if base-name == auto { name } else { base-name },
  category: category,
  kind: kind,
  ability: id-of-or-none(ability),
  damage: damage,
  damage-type: damage-type,
  range: range,
  thrown-range: thrown-range,
  properties: properties,
  bonus: bonus,
  true-strike: true-strike,
  shillelagh: shillelagh,
  versatile: versatile,
  two-handed: two-handed,
)

// Weapon mastery training: the weapon names (bare strings) a character mastered.
// - A weapon's mastery property (Nick, Vex, Topple, ...) shows on its attack line only when the weapon is named here.
// - Matching is case-insensitive.
#let eff-weapon-mastery(..weapons) = (
  effect: "weapon-mastery",
  weapons: weapons.pos().flatten().map(lower),
)

// Bonus to melee reach, in feet; stacks across sources.
// - Extends the range shown for each melee attack whose range is a plain reach ("5 ft" -> "10 ft").
// - A weapon with a throw or ranged range ("20/60 ft") stays unchanged; that number is a throwing range.
// - Powers the Bugbear's Long-Limbed trait (+5 ft reach on melee attacks).
#let eff-reach(value, source: none) = (effect: "reach", value: value, source: source)

// Cunning Strike option (2024 Rogue, level 5): a non-damage rider added to a Sneak Attack hit for `cost` Sneak Attack dice.
// - `cost`: a literal dice string ("1d6"); rendered with `fmt-dice`.
// - `note`: markup content that describes the rider.
// - `save-ability`: the target's save, or `none` for a rider with no save (Withdraw).
// - Cunning Strike's DC is always Dex-based; `save-ability` names the target's save only.
// - Display-only, except for its own DC.
#let eff-cunning-strike(name, note, cost: "1d6", save-ability: none, source: none) = (
  effect: "cunning-strike",
  name: name,
  note: note,
  cost: cost,
  save-ability: id-of-or-none(save-ability),
  source: source,
)

// Pact of the Blade (Warlock invocation).
// - Names no weapon; the bonded weapon can change from turn to turn.
// - The resolver treats each melee weapon and each magic weapon (nonzero `bonus`) as proficient.
// - The resolver uses the warlock's spellcasting `ability` (normally Cha); this overrides the weapon's own attack ability.
#let eff-pact-blade(ability) = (effect: "pact-blade", ability: id-of(ability))

// Override the universal unarmed strike.
// - Each creature has an unarmed strike (1 + Str bludgeoning, always proficient).
// - The resolver seeds that strike and folds these overrides in; a Tortle's Claws replace the damage and add no second attack line.
// - A field left `none` keeps the default.
#let eff-unarmed(damage: none, damage-type: none, ability: none, name: none, source: none) = (
  effect: "unarmed",
  damage: damage,
  damage-type: damage-type,
  ability: id-of-or-none(ability),
  name: name,
  source: source,
)

// Miscellaneous numeric stat.
// - `which`: "hp" | "temp-hp" | "speed" | "initiative".
// - `kind`: "bonus" (adds) | "set" (overrides) | "proficiency" (adds the proficiency bonus and ignores `value`; Alert's +PB Initiative).
// - `value`: int or function `(ctx) => int` of the computed context (Tough's HP bonus is `ctx => 2 * ctx.level`).
#let eff-stat(which, value, kind: "bonus") = (
  effect: "stat", which: which, kind: kind, value: value,
)

// Spellcasting source: a class, a feat, or a species trait.
// - `source`: display name; `ability`: the one casting ability.
// - `cantrips` / `spells`: spell objects the source grants.
// - `slots`: level→count dict ("1": 2) of expendable slots.
// - `kind`: separate a full-caster class source from an innate or feat grant.
// - The resolver derives the save DC and the attack bonus once, from the ability.
// - `prepared-at`: optional default slot level for every non-cantrip spell of this source (2 for a warlock whose pact slots are all 2nd level).
// - A spell in `spells` overrides that level with the `(spell: s, slot: N)` form.
#let eff-spellcasting(source, ability, cantrips: (), spells: (), slots: (:), kind: "innate", prepared-at: none) = (
  effect: "spellcasting",
  source: source,
  ability: id-of(ability),
  cantrips: cantrips,
  spells: spells,
  slots: slots,
  kind: kind,
  prepared-at: prepared-at,
)

// Feat-granted spell that its rule text also casts with any spell slot the character has (Magic Initiate, Fey Touched).
// - Additional to the feat's free once-per-Long-Rest cast, which stays a separate `eff-limited-use` pool on the same feature.
// - `source`: the granting feature's name ("Magic Initiate (Wizard)").
// - `source` scopes a matching `eff-spellcasting-bonus` item bonus only; the ability stays the feat's own.
// - The resolver projects `spell` into every other spellcasting source that has slots, at that source's own default cast level.
// - The cast behaves like any other prepared spell of that source, not like a pinned one.
#let eff-spell-any-slot(spell, ability, source) = (
  effect: "spell-any-slot",
  spell: spell,
  ability: id-of(ability),
  source: source,
)

// Number of attacks per Attack action (Extra Attack).
// - The resolver takes the maximum across all sources.
#let eff-extra-attack(count) = (effect: "extra-attack", count: count)

// Damage bonus for one named spell.
// - `spell`: the spell's display name or its kebab-case id; the resolver normalizes both.
// - `ability`: add that ability's modifier at resolve time.
// - `value`: fixed fallback bonus.
// - For a multi-beam spell (Eldritch Blast), the spell's `damage-bonus-per: "beam"` field multiplies the bonus by the beam count.
#let eff-spell-damage-bonus(spell, value: none, ability: none) = (
  effect: "spell-damage-bonus",
  spell: spell,
  value: value,
  ability: id-of-or-none(ability),
)

// ---------------------------------------------------------------------------
// Feature constructor
// ---------------------------------------------------------------------------

// Feature: a name with the effects it contributes.
// - `features`: nested child features; the resolver collects their effects too.
// - Nesting is how a class carries Jack of All Trades, or a background carries its origin feat.
// - The optional fields (kind, subclass, level, hit-die, source) let the resolver recognise classes, species and more.
// - `casts`: the spell this feature casts from itself (a wand's Magic Action). Takes `eff-spellcasting`'s own `spells:` entry shape — a bare spell, or `(spell: s, slot: N)` to pin the level a charge buys. The resolver projects it to `cast`, a spell detail, and the action note reads its range and damage from there, so the feature's own prose never restates them.
// - Extra named arguments merge in unchanged.
#let feature(name, effects: (), features: (), kind: none, source: none, ..rest) = (
  name: name,
  kind: kind,
  source: source,
  effects: effects,
  features: features,
  ..rest.named(),
)

// Feature whose single effect is a limited-use pool named after the feature (Bardic Inspiration, Innate Sorcery, a magic item's charges).
// - The `eff-limited-use` takes the feature's own name and source; neither is restated.
// - Other feature fields (kind / desc / activation / notes) pass through named.
// - A pool named differently from its feature (Lucky's "Luck Points", a feat's free cast) declares its own `eff-limited-use`.
#let limited-use-feature(name, uses, recharge: "long", uses-label: none, source: none, ..rest) = feature(
  name,
  source: source,
  effects: (eff-limited-use(name, uses, recharge: recharge, uses-label: uses-label, source: source),),
  ..rest.named(),
)

// Ability Score Improvement: +`value` to one ability.
// - Call it twice for the +1/+1 split.
// - Named feature so a build reads as the game concept.
// - Carries no `desc` and its own `kind`; it contributes its effect and renders nowhere (the layouts' trait and feat predicates skip this kind).
#let asi(which, value) = feature(
  "Ability Score Improvement",
  kind: "asi",
  effects: (eff-ability(which, value),),
)

// Mark a gear feature as carried (inert cargo; it lists in INVENTORY only).
// - The resolver skips it and everything nested in it: no effects, no traits, no attack lines, no resource pools.
// - EQUIPPED is the default; a bare gear feature applies its effects. Remove the wrapper to equip.
#let carried(f) = f + (carried: true)

// ---------------------------------------------------------------------------
// Character constructor
// ---------------------------------------------------------------------------

// - `abilities`: base scores, e.g. (str: 9, dex: 16, ...).
// - `features`: everything else — species, classes, items, spells.
// - `max-hp: auto` (default) computes the maximum from the hit dice (the 5.5e fixed rule) plus Con; pass an int to override (rolled HP).
// - `languages` / `tools`: extra proficiencies beyond the ones features grant (objects or ids).
// - `effects`: escape hatch for a one-off effect not worth a named feature.
// - Every character knows Common automatically.
// - 2024 PHB "Choose Languages": species and background grant no language; only a class or feat feature grants one (Druidic, Thieves' Cant, a granted spell's free cast).
// - Author the character's other chosen languages with `languages:`.
// - `equipment` (list of strings) and `currency` are display-only inventory; the engine reads neither.
// - The resolver prepends `carried(...)` gear to `equipment`; declare only unmodelled kit here.
// - `backstory`: display-only roleplay prose, given as the trailing content block (`character(...)[…]`).
// - The block may carry emphasis, lists, and inline math.
// - Omit the block for a character with no backstory.
#let character(
  name: "",
  player: none,
  alignment: none,
  background: none,
  faction: none,
  abilities: (:),
  max-hp: auto,
  speed: 30,
  level: 1,
  features: (),
  effects: (),
  languages: (),
  tools: (),
  equipment: (),
  currency: none,
  ..rest
) = (
  name: name,
  player: player,
  alignment: alignment,
  background: background,
  faction: faction,
  abilities: abilities,
  max-hp: max-hp,
  speed: speed,
  level: level,
  features: features,
  effects: effects
    + (eff-prof("language", "Common"),)
    + languages.map(l => eff-prof("language", l))
    + tools.map(t => eff-prof("tool", t)),
  equipment: equipment,
  currency: currency,
  backstory: rest.pos().at(0, default: none),
  ..rest.named(),
)
