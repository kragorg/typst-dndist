# CLAUDE.md

Guidance for working in this repo. See `README.md` for user-facing docs.

## What this is

`dndist` is a **Typst package, delivered as a Nix flake**, for defining
and rendering printable **D&D 5.5e** character sheets. All tooling,
fonts, and dependencies are encapsulated in the flake.

**The repo root is the package root.** `typst.toml`, `dndist.typ`,
`src/`, and `template/` are what ships; `tests/`, `flake.nix`,
`typst-strict.pl`, `.github/`, `docs/`, and the docs sit beside them and
do not. That split is enforced by the `packageFileset` allow-list in
`flake.nix` --- see Commands.

## Commands

``` sh
nix flake check                    # assertions + render fixtures + template + package contents
nix build                          # build the Typst package (default output = .#dndist)
nix develop                        # shell where bare `typst` finds fonts + @preview/dndist
nix fmt -- --ci                    # formatting check
nix run .#docs-images              # regenerate the README screenshots in docs/
```

Inside the devShell:

``` sh
typst compile --root . tests/resolve-test.typ /tmp/t.pdf          # the engine assertions
typst-strict --root . tests/example.typ /tmp/e.pdf --input layout=card
typst-strict --root . tests/example.typ /tmp/e-lg.pdf --input layout=card-lg  # any of the four
```

**`--root .` matters.** `tests/resolve-test.typ` reaches relatively into
`../src/resolve.typ` and `../src/model.typ` for unexported internals,
which escapes its own directory; the devShell exports `TYPST_ROOT` for
the same reason, and the flake checks pass `--root "$src"` explicitly.
Typst 0.14.2 has no subpath package-import syntax
(`@preview/name:ver/file.typ` errors as an invalid version), which is
why that reach-in stays a relative import rather than going through
`@preview`.

### What ships, and how that is enforced

`buildTypstPackage` is a plain `cp -r` of its `src` and **ignores
`typst.toml`'s `exclude`**, so with the repo root and the package root
being the same directory, the `packageFileset` allow-list in `flake.nix`
is the *only* control over package contents. It is an allow-list on
purpose: a new file at the repo root must not be able to leak into a
published package by default. **Adding a file the package must ship
means adding it to `packageFileset`.** The `package-contents` check
asserts both directions (required files present, tooling absent) and
fails the build otherwise. `typst.toml`'s `exclude` list is kept in sync
by hand and is load-bearing only for a direct Universe upload from this
directory.

**Renders go through `typst-strict.pl`.** The `render` and `template`
checks invoke it (as the wrapped `typst-strict` binary the flake
exports); it adds `--ignore-system-fonts` and then **fails** if the
compile output mentions an unresolved font family. This exists because
Typst treats a missing family as a *warning*, substitutes an embedded
face, and exits 0 --- and there is no CLI flag that makes it an error.
Since the layout is calibrated to ETBembo/Montserrat/Euler Math
(synthesized bold, synthesized small caps, metric-tuned wrap caps), a
substitution could yield a subtly wrong sheet rather than an obviously
broken one, so it has to fail loudly at the build layer. The exported
`typstEnv` additionally hard-`--set`s `TYPST_IGNORE_SYSTEM_FONTS`, so a
host-installed face cannot quietly satisfy a family either.

The flake exports `typstEnv`, `typst-strict`, and
`legacyPackages.fontPaths` so consumers get the compiler, the guard, and
the font list without restating any of them. **Never duplicate the font
list downstream.**

**The repo's scripting language is Perl, not shell** ---
`typst-strict.pl`, `docs-images.pl`, `fonts.pl`. A shell script would add
a second scripting dependency for nothing. The first two are wrapped for
the flake by one `makeWrapper` call that supplies its `PATH` (`typstEnv`
for the font guard; the guard plus `poppler-utils` for the screenshots),
so neither script hunts for a tool. `fonts.pl` is deliberately *not*
wrapped: it runs on a machine that has no flake, so it uses **core Perl
only** (`Digest::SHA` for hashing) and shells out to `curl`/`wget` and
`tar`.

**Fonts are downloaded on demand, never vendored.** `perl fonts.pl`
fetches the three families into `./fonts` (gitignored) so a clone plus
`typst` renders a correct sheet; the repo must not carry font binaries
(third-party artifacts with their own upstream, and 1.6 MB of git
history). **Every file is pinned by sha256**, taken from the same
revisions nixpkgs pins (`edwardtufte/et-book` @ `7e8f02d`,
`JulietaUla/montserrat` @ `v9.000`, CTAN `euler-math`), so a download is
byte-identical to what the flake renders with --- the pin *is* the
mechanism: a family that resolves to a different build produces a subtly
wrong sheet and Typst reports nothing, which is the same failure
`typst-strict` exists to catch. Only the weights the layout asks for are
downloaded (Montserrat Regular/Medium/Bold; the other fifteen are dead
weight). The `font-pins` check hashes the flake's own font files and
fails if any pinned hash is absent, so a nixpkgs bump is a red build, not
a silent drift; `perl fonts.pl --check` re-verifies an existing `./fonts`
the same way. **Re-pinning means re-checking the layout**, not just
swapping a hash.

**The setup for a user without Nix is one committed symlink, not a
script** --- `packages/preview/dndist/1.0.0 -> ../../..`. Typst resolves
`@<namespace>/<name>:<version>` from
`<root>/<namespace>/<name>/<version>` on disk before it reaches for the
network, so `TYPST_PACKAGE_PATH=$PWD/packages` (or `--package-path
packages`) is the entire install: nothing is copied, and dndist is
unpublished yet `@preview/dndist:<version>` --- the import in every file
here and in everything `typst init` writes --- resolves unchanged, now
and after publication. The `preview` namespace is the point; do not
"correct" it to `local`, which would force an edit to every import. A
package cannot read outside its own root, so a plain shim directory
re-exporting `../../../../dndist.typ` is *not* an option (Typst denies
the escape) --- the symlink is what makes the repo root the package root
a second time. `packages/` is excluded from what ships (it is absent from
`packageFileset`, and named in `typst.toml`'s `exclude` for the manual
upload path); a published package would carry a symlink to itself
otherwise. The `bare-typst` check runs `typst init --package-path
packages` with an **empty** `TYPST_PACKAGE_CACHE_PATH`, so the committed
symlink is the only thing that can satisfy the package and a broken link
fails the build.

**The README screenshots are generated, not hand-cropped.**
`nix run .#docs-images` re-renders `template/main.typ` and writes
`docs/card-deck.png` (card page 2, the core card, at 150 dpi) and
`docs/letter-sheet.png` (letter page 1 at 100 dpi) into the working
tree. It is an **app**, not a package or a check: it writes to the
source tree, which a derivation cannot do. The page and resolution of
each image live in `docs-images.pl` alone, so a regenerated screenshot
differs only where the layout did. Regenerate whenever a change moves
what those two pages show, and commit the images with it.

Do not assume `pdftoppm`/`pdftotext` is available. To inspect rendered
output, use nix for access to these tools (then `Read` the PNG):

``` sh
nix shell nixpkgs#poppler-utils --command pdftoppm -png -r 200 out.pdf /tmp/out
```

## Architecture: declare → resolve → render

A character is **declared data + composable feature objects**; features
contribute tagged **effects**; the resolver folds effects into computed
values; renderers consume the result. Adding rules (species, classes,
subclasses, backgrounds, items, spells, feats) means adding features
that emit effects --- **never** special-casing the resolver or
renderers.

    dndist.typ              Public API: re-exports + namespaces (ability, skill, tool,
                            species, class, subclass, invocation, background, item,
                            weapon, spell, feat);
                            sheet(char) dispatches card/letter from `--input layout=`
    src/model.typ           character(), feature(), limited-use-feature() (a feature whose
                            one effect is a pool named after itself), asi() (an Ability
                            Score Improvement as a named, non-rendering feature), carried()
                            (marks gear as inert pack cargo — INVENTORY, no effects),
                            id-of(), and the eff-* effect constructors
    src/resolve.typ         The computation engine (see below)
    src/data/abilities.typ  ability objects (id, abbr, name); ability-ids, ability-names
    src/data/skills.typ     skill objects (id, name, ability); skill-list
    src/data/tools.typ      tool objects (built from the name lists in constants.typ)
    src/data/constants.typ  languages, tool name lists, alignment codes, armor table
    src/features/           species.typ, classes.typ, subclasses/, invocations.typ,
                            backgrounds.typ, items.typ, weapons.typ, spells.typ, feats.typ
    src/layout/             layouts.typ (the layout registry: page geometry, scale,
                            fixed-scale, scale-1 margins for card, card-lg, card-5x8
                            and letter — named once, read by dndist.typ and common.typ),
                            common.typ (components, fonts, proficiency icons, the
                            sheet-table/stacked-lines rhythm builders, keep-together +
                            spell/attack tables, feature boxes, the limited-use-lines
                            diamond tracker for the letter's narrow Resources box
                            (`single-column: true`, two labelled groups stacked), and
                            `resource-tables` for the card deck — two side-by-side
                            `sheet-table`s (Short Rest | Long Rest) of diamonds that
                            travel together as the Actions card's tail),
                            card.typ (themed deck
                            w/ overflow continuation + a foldable placard card #1;
                            the Actions card holds the action economy — Attack,
                            Cunning Strike, then the Action/Bonus Action/Reaction/
                            Other tables (activated abilities); actionable *spells* fold
                            into those same tables, routed by casting time (see
                            the Action/Bonus Action/Reaction spell-routing note
                            below); the limited-use resource tables (Short Rest /
                            Long Rest) follow Other as the card's tail. The Features &
                            Traits card holds one passive Features & Traits section —
                            grouped by source under tiny eyebrow sub-headers, the
                            feats folded in as a Feats subsection (see the
                            source-grouping note);
                            a Backstory card when declared),
                            letter.typ (a fixed one-page core + a roleplay section
                            that flows over as many pages as it needs — 3 pages for
                            a level-2 druid, 7 for a level-10 warlock; overflow-prone
                            boxes — spells, class features, species traits, feats —
                            repeat their title tagged "(continued)"; the Class
                            Features and Species Traits boxes group by source like
                            the card deck; page-1 columns balanced to fit one page;
                            the Resources box lives on the roleplay page)
    tests/                  resolve-test.typ (assert()-based engine tests) + the
                            render fixtures/demos. These are not played characters;
                            each fixture exists to exercise a layout edge case:
                            example.typ (the worked
                            example — a simplified Elara), sage.typ (Mira, wizard —
                            Magic Initiate + first-slice spellcasting),
                            multiclass.typ (Valda, Fighter 1 / Wizard 9 —
                            letter-sheet per-class identity rows), empty.typ (the
                            copyable template), kragor-mm.typ (Magic Missile at
                            2nd-level pact slots), kragor-5.typ (level 5, Thirsting
                            Blade / Extra Attack), wizard-test.typ (a Wizard 5
                            slot-display fixture: Magic Missile at base slot, no
                            prepared-at), longshort-dedup.typ (a Fighter 1 / Druid 2
                            fixture exercising the shared-footnote dedup — both Second
                            Wind and Wild Shape are `long-short-regain` pools, so one
                            note at the page foot serves two `*` markers)

### Game objects are the DSL leaves

Abilities, skills, tools, and spells are **objects** with an `id`,
reached through namespaces: `ability.cha`, `skill.sleight-of-hand`,
`tool.thieves-tools`, `spell.fire-bolt`. The `id-of` helper
(`model.typ`) normalizes any of them to its id, and **every
effect/feature that names one accepts the object *or* a bare string id
interchangeably**. The one exception is the score-input dict, which
stays id-keyed because dict keys can't be objects:
`abilities: (str: 9, dex: 15, …)`.

### Effect & feature model (`src/model.typ`)

A feature is `(name, kind, source, effects, features, …)`. The
`features` field nests **child features** (traits / sub-features); the
resolver recurses (`flatten-features` → `collect-effects`). This is how
a class carries named features (Jack of All Trades, Unarmored Defense),
a subclass folds its level-gated features into its class, and a
background carries its origin feat. Two more conventional-but-optional
fields flow through the same `..rest` passthrough as `desc` (no change
to `feature()`'s signature): `activation` --- one of
`"Action"`/`"Bonus Action"`/`"Reaction"`, `none` meaning passive,
reusing the exact vocabulary `spells.typ`'s `casting-time` already uses
--- and `notes`, markup content holding terse row prose for the card
deck's ACTION/BONUS ACTION/REACTION tables (see `card.typ` below).
`notes` is deliberately **separate from `desc`**: `desc` stays the full
prose shown in the passive Traits/Feats lists and the letter sheet
(unaffected by `activation`), while `notes` is authored tighter and
skips restating the activation type the table's column header already
gives it. Like `eff-limited-use`'s `uses`, `notes` **and `desc` may each
independently be a function of the same computed `ctx`
(`pb`/`level`/`ability-mods`)** rather than a literal --- `resolve()`
evaluates whichever is a function once, right where it builds `traits`,
so a row (or the passive Traits/Feats prose itself) can show a derived
number instead of vague prose (Adrenaline Rush:
`ctx => [Take the Dash action; gain #ctx.pb THP.]`; Telekinetic Shove:
computes its Strength save DC from `ctx.pb` + the caster's own ability
modifier, the identical `8 + PB + mod` formula `eff-spellcasting` uses
for its save DC --- "STR 12 save", not a restated formula; Aasimar's
Celestial Revelation computes its extra damage --- equal to Proficiency
Bonus --- as
`ctx => […dealing $#{ctx.pb}$ extra radiant/necrotic damage…]` for
`desc`, mirrored in its `notes`, rather than restating "equal to your
Proficiency Bonus" as static prose the way `desc`-only traits like
Adrenaline Rush and Healing Hands still do --- reach for a computed
`desc` when the trait's own display line (not just its action-table row)
should show the actual number). A feature with two different activation
costs (Tortle's Shell Defense --- an Action to enter, a Bonus Action to
emerge) is modelled as a parent feature plus a nested child feature (the
same `features:` nesting used for any other sub-trait) ---
e.g. `species.typ`'s "Shell Defense" (`activation: "Action"`) nests an
"Emerge" child (`activation: "Bonus Action"`), each with its own trimmed
`desc` so the letter's flattened trait list never repeats prose across
the two. `feat.typ`'s `telekinetic` uses the same split for its passive
Mage Hand grant vs. its nested "Telekinetic Shove". A third passthrough field, `casts`, names
**the spell a feature casts out of itself** (a wand's Magic Action),
taking `eff-spellcasting`'s own `spells:` entry shape --- a bare spell,
or `(spell: s, slot: N)` to pin the level a charge buys. `resolve()`
projects it through `_spell-detail` (the same projection the spell
tables use) into a `cast` field on the trait, and `item-action-note`
leads that row's Notes with it, so the wand's range and dart count come
off `spell.magic-missile` instead of the author's fingers. The cast
carries **no save DC and no attack bonus** --- an item is not a
spellcasting source (see `items.typ`), and nothing reads those fields
for a cast --- and no `spell-bonuses`, since an
`eff-spell-damage-bonus` is the character's and the wand's darts are the
wand's. It is always `fixed-slot`: charges rather than slots set the
level, so the ▲ upcast affordance stays off. Reach for `casts` only
where the feature casts the spell **as the catalog describes it** --- the
Druid's Wild Companion overrides Find Familiar's casting time *and* its
Material cost, so its note stays authored prose. A fourth such field,
`spell-schools` (a list of school-name strings,
e.g. `("Enchantment", "Illusion")`), marks a feature whose rule text
reads "when you cast a `<school>` spell..." --- Great Old One's Psychic
Spells, College of Glamour's Beguiling Magic. It's read only at layout
time (`spell-school-notes`, `layout/common.typ`), never by the resolver:
the SPELLS table cross-references every spell's `school` (now carried on
each `spells-detail` entry, a plain passthrough of the spell's own
`school` field) against every trait's `spell-schools` and marks a match
--- no per-spell or per-character authoring, and no engine change when a
new such feature is added.

Effects are tagged dicts the resolver folds (all `eff-*`):

- `eff-ability(which, value, kind)` --- kind `base`/`background`/`bonus`
  add; `set` forces a fixed score.
- `eff-ac-base(base, cap, source)` --- armor base + Dex cap
  (`none`=unlimited/light, `2`=medium, `0`=heavy).
- `eff-ac-formula(base, abilities, source)` --- alternate unarmored base
  (Mage Armor 13+Dex; Unarmored Defense 10+Dex+Con/Wis). The **best**
  candidate base wins.
- `eff-ac-bonus(value, source)` --- flat, stacks on top (shield +2, ring
  +1). `eff-ac-set` forces AC.
- `eff-prof(category, key, level)` --- category
  `skill`/`save`/`tool`/`language`/`armor`/`weapon`; level
  `proficient`/`expertise`.
- `eff-save-advantage(note, source)` --- a **conditional advantage on a
  saving throw**, e.g. Fey Ancestry ("to avoid or end the Charmed
  condition"), War Caster ("on Constitution saves to maintain
  concentration"). `note` is authored **markup content** stating exactly
  when the advantage applies --- there is *no* ability field,
  deliberately: the advantage rarely covers *all* saves of an ability
  (charmed is condition-scoped; War Caster only concentration), so it's
  never badged on a save box. Purely display-only (never touches a
  number); the resolver collects it into a flat `save-advantages` list
  that both layouts footnote beneath the saves with an "advantage"
  hexagon badge (see the marker note).
- `eff-check-advantage(skill, source)` --- **advantage on every check
  with one skill** (Boots of Elvenkind: Dexterity (Stealth)). The
  counterpart to `eff-save-advantage`, and the shape difference is the
  whole point: a save advantage is condition-scoped, so it carries
  authored `note` prose and lives in a footnote; a check advantage of
  this kind is unconditional and covers exactly one skill, so it carries
  **no prose at all** and lives on that skill. Display-only (never
  touches a number). There is no flat top-level list --- the resolver
  stamps `advantage: bool` on the skill's own entry in `skills`, because
  that is where a skill's facts live, and `skill-row` (`common.typ`,
  shared by the card's skills grid and the letter's ability rail) trails
  the name with the same hexagon badge. Emitted by
  `item.boots-of-elvenkind`. See the marker note for why the badge sits
  on the row here and never on a save box there.
- `eff-sense(name, range, source)` --- a **special sense**: Darkvision,
  Blindsight, Truesight, Tremorsense. `name` is the display name (a
  string); `range` is an authored range string (`"60 ft"`) or `none` for
  a rangeless sense. Display-only like `eff-save-advantage` (never
  touches a number). The resolver collects it into a flat `senses` list,
  **deduped by name keeping the longest range** (same-named senses don't
  stack --- Darkvision 120 ft supersedes Darkvision 60 ft; range parsed
  from its leading integer, rangeless = 0). Both layouts list it in the
  same Defenses & Senses footnote as the save advantages, senses
  **last** (after the advantages and resistances --- see the marker
  note). Emitted by the species Darkvision traits (Orc 120 ft, Bugbear
  60 ft) alongside their display prose.
- `eff-resistance(damage-type, kind, source)` --- a **damage response**:
  `kind` `"resistance"` (default) / `"immunity"` / `"vulnerability"` to
  a `damage-type` string (`"Fire"`). Display-only like
  `eff-save-advantage` (never touches a number). The resolver collects
  it into a flat `resistances` list, **deduped by (kind, type)**. Both
  layouts list it in the Defenses & Senses footnote, one plain-text line
  per kind (`Resistance: Fire, Cold`), placed **after the save
  advantages and before the senses** (both are defenses; see the marker
  note). No feature emits one yet --- the plumbing is ready for the
  first that does.
- `eff-limited-use(name, uses, recharge, uses-label, source)` --- a
  **limited-use resource**: a feature with a bounded number of uses that
  recharge on a rest (Innate Sorcery 2/Long Rest, Lucky's Luck Points
  PB/Long Rest, Wails from the Grave DEX-mod/Long Rest, a Magic Initiate
  free 1/Long Rest cast). `name` takes a **spell object** as readily as
  a string --- the `id-of` idiom --- and a pool tracking a free cast
  must use that form (`eff-limited-use(spell.misty-step, 1, …)`, never
  the name typed out again): it sets `spell: true`, which is what makes
  the resource table italicize the row like every other spell name.
  `uses` is a literal int **or a function
  `(ctx) => int`** the resolver evaluates with
  `ctx = (pb, level, ability-mods)` --- so the count derives from PB
  (`ctx => ctx.pb`), an ability modifier
  (`ctx => calc.max(1, ctx.ability-mods.cha)`), level, half-level, etc.
  (parenthesise the call: `(e.uses)(ctx)`, else Typst parses it as a
  dict method). `uses-label` is optional display prose naming the
  derivation (`"PB"`, `"CHA mod"`), shown as a tiny accent eyebrow
  **inline, just left of** the diamonds on the same row (rendered
  smaller than the diamonds so its presence never grows the row height
  --- rows with and without a label keep identical spacing); `recharge`
  is
  `"long"`/`"short"`/`"short-or-long"`/`"long-short-regain"`/`"dawn"`.
  The last two are **partial refills the rest column cannot state**, and
  they are the only kinds carrying a footnote:
  `"long-short-regain"` is the 2024 partial-recharge pattern (Wild
  Shape, Second Wind) --- regain *all* uses on a Long Rest and *one*
  expended use on a Short Rest; `"dawn"` is a charged magic item
  regaining **1** use each dawn, on no rest at all (Ring of
  Comprehension). A pool regaining a *rolled* amount at dawn (a wand's
  `1d6+1`) is deliberately **not** the `"dawn"` kind --- the note states
  a fixed 1, so that item stays `"long"` and its own `desc` carries the
  dice. Both sort into the **Long Rest** column (that column names the
  recharge that refills the pool; the footnote adds what it leaves out),
  and the layout renders that kind's superscript symbol on each such
  pool's row with its note at the page bottom (see the resource-tables
  note). **`_recharge-notes` (`common.typ`) is the one table mapping a
  recharge kind to its fixed symbol and note text**, read by both
  `_recharge-mark` (the row marker) and `recharge-footer` (the note); a
  kind absent from it needs no note, because its column already says
  everything. The two buckets are defined once as "short-rest
  recoverable" and "everything else", so a new kind lands in Long Rest
  with no layout change.
  **Deliberately no note/description field** --- the tracker is labelled
  by feature `name` alone; the feature's effect is already described in
  its traits/feats section, so repeating it here is noise. (A recharge
  footnote is *recharge* mechanics, not the feature's effect --- that's
  why it's a layout footnote keyed by recharge kind, not a per-row prose
  field.) **Display-only** --- not read by any numeric resolver, so it
  never changes a sheet stat (like `eff-sense`); **but the count is a
  computed value** (evaluated at resolve time, where PB/level/ mods are
  in scope, and stored as a concrete int). The resolver collects it into
  a flat `limited-uses` list --- **sorted** short-rest-recoverable pools
  before long-rest (short-or-long groups with short; long-short-regain
  and dawn group with long), then scarcest
  (fewest uses) first, then alphabetical --- that both layouts render as
  a **diamond tracker** (see the marker note): split into two columns
  (left = regainable on a short rest, right = long rest) when both
  buckets are non-empty, else a single labelled column. Emitted by
  Innate Sorcery/ Magical Cunning (class), Adrenaline Rush/ Relentless
  Endurance (Orc), Wails from the Grave (Phantom), Lucky (feat), and
  Magic Initiate / Fey Touched (their granted 1st-level spell's free
  1/Long-Rest cast) --- each keeping its display prose. The free-cast
  pool is emitted by the **granting feature**, never by the spell
  object: a spell reached through a spellcasting source
  (`eff-spellcasting`'s `spells:`) contributes data, not effects, so a
  free cast that comes from a feat lives on that feat. **Not** emitted
  by Fairy Magic: its innate casts are gained at character levels 3/5,
  and a species builder can't see total character level (level lives on
  the class feature), so gating isn't expressible --- left as prose.
- `eff-skill-rule("reliable-talent" | "jack-of-all-trades")`.
- `eff-skill-bonus(which, value, ability, min-value, source)` --- adds
  `value` plus, when `ability` is given, that ability's modifier (raised
  to `min-value`) to one skill. Powers Primal Order (Magician): +Wis mod
  (min +1) to Arcana & Nature.
- `eff-stat(which, value, kind)` ---
  `hp`/`temp-hp`/`speed`/`initiative`. `kind` `bonus` (adds `value`)/
  `set` (overrides)/`proficiency` (adds the proficiency bonus, ignoring
  `value` --- powers Alert's +PB Initiative; `resolve-stat` takes `pb`).
  Like `eff-limited-use`'s `uses`, `value` may be a **function
  `(ctx) => int`** of the computed context --- Tough's
  `eff-stat("hp", ctx => 2 * ctx.level)`.
- `eff-save-bonus(value, source)` --- a **flat bonus to all saving
  throws** (Cloak/Ring of Protection's `+1`), folded into every computed
  save, proficient or not.
- `eff-spellcasting-bonus(attack:, dc:, source-name:)` --- a bonus to a
  spellcasting source's attack bonus and/or save DC (Rod of the Pact
  Keeper). `source-name` scopes it to the source with that display name
  (`"Warlock"`); `none` applies to every source. Scoping matters on a
  multi-source character: the rod must not inflate a feat's own DC
  (Telekinetic Shove keeps its 17 while the pact DC reads 19). Because
  `attack` can now exceed PB + mod, each resolved source carries its
  true ability `modifier` explicitly --- **display must never re-derive
  the modifier as attack − PB** (the spellcasting header reads
  `s.modifier`). Scoping is also what keeps the rod's source *visible*:
  `spellcasting-head` (`layout/common.typ`, both layouts) **merges
  sources sharing all four displayed values --- ability, modifier,
  attack, save DC --- into one row, names joined by `" / "`**, in
  first-occurrence order (the `trait-groups` grouping idiom). Elara's
  four Charisma sources collapse to one row; the template character's
  Warlock and Telekinetic sources, whose attack and DC the Rod of the
  Pact Keeper separates, stay two rows, so the rod's effect reads as the
  split it is. Each name is `box`ed so a wrap in the letter's narrower Source
  column breaks at a separator, never through a name. **The merge is
  display-only** --- `c.spellcasting` stays per-source for
  `spell-table`, `merge-slots`, the card front face's
  `.first()`, and the `eff-spell-any-slot` projection.
- `eff-spellcasting(source, ability, cantrips, spells, slots, kind)` ---
  a spellcasting source; `slots` is a level→count dict (`"1": 2`),
  `kind` is `"class"`/`"innate"`/etc. The resolver derives its save DC
  and attack once, and projects each spell to display detail for the
  spell tables (each detail entry also carries the source's
  `save-dc`/`attack-bonus`, so a spell's HIT/SAVE cell reads `+5` or
  `WIS 14`).
- `eff-spell-any-slot(spell, ability, source)` --- a feat-granted spell
  that, per its own rule text, can ALSO be cast using any spell slot the
  character has (Magic Initiate, Fey Touched), on top of the feat's own
  free once-per-Long-Rest cast (still a separate `eff-limited-use` pool
  on the same feature). `resolve-spellcasting` projects `spell` into
  every *other* spellcasting source that actually has slots --- Warlock
  Pact Magic, a full caster's own slots, whatever the character happens
  to have --- resolved exactly like a bare spell entry of that source
  (its own `prepared-at` default, or the spell's own base level for a
  real multi-level caster), so it inherits that source's ordinary upcast
  behavior rather than a special case. **The projection makes the spell
  resolve twice** --- the feat's own pinned (`fixed-slot`) free cast plus
  the slot cast --- which is correct in the data but reads as a duplicate
  row on the sheet: the spell tables carry no source column, and the two
  rows are character-for-character identical whenever the spell has no
  upcast scaling (Misty Step). `all-spells` (`layout/common.typ`, the one
  door both the SPELLS tables and the card deck's action-economy routing
  go through) therefore **drops the fixed-slot row when a slot cast of the
  same name and level is also present**, keeping the strictly more
  informative row --- only the slot cast carries the ▲ upcast affordance
  --- while the free cast stays visible as its own Resources pool, so
  nothing is lost. A group whose rows are *all* fixed-slot (a warlock
  casting everything at pact-slot level) or all slot casts is left alone:
  there the rows differ in cast level and each says something the other
  does not. DC/attack always come from the
  granting feat's own `ability` --- "cast with a slot" doesn't change
  whose spell it is --- including a matching `eff-spellcasting-bonus`
  scoped to `source` (never to the host source: a Rod of the Pact Keeper
  scoped to `"Warlock"` must not boost a Wizard-list Magic Initiate
  spell just because it borrows a pact slot). The mechanism doesn't care
  how the granting feat is attached to the character --- top-level, from
  a background's origin feat, or nested inside an Eldritch Invocation
  (`lessons-of-the-first-ones`) --- since `flatten-features` already
  collects effects regardless of nesting depth; a Warlock can take Magic
  Initiate/Fey Touched normally, not only through that invocation. The
  feat's own dedicated source pins its granted spell(s) to their own
  base level via the `(spell: s, slot: N)` per-entry form (mirroring how
  the at-will invocation grants --- One with Shadows, Visions of Distant
  Realms --- are folded into Pact Magic): a free once-per-Long-Rest cast
  has no headroom to upcast, so it must resolve `fixed-slot: true` or
  the layout's ▲/scaling-prose heuristic (see the `spell.*` scaling
  note) would wrongly suggest it can be upcast.
- `eff-weapon(name, category, kind, ability, damage, damage-type, range, thrown-range, properties)`
  --- a wielded weapon; the resolver computes its attack bonus (ability
  mod + PB if proficient) and damage string (dice + signed ability mod).
  **`range` is the range the attack is made at, and it follows the
  weapon table's own columns**: a melee weapon's *reach* (`"5 ft"`, or
  `"10 ft"` for a `Reach` weapon), a ranged weapon's projectile range
  (the range on its Ammunition property, `"80/320 ft"`). A Thrown
  weapon's throw range is its **own `thrown-range` field**
  (`"20/60 ft"`), never folded into `range` --- a Dagger is a melee
  weapon that keeps its 5 ft reach, so the reach stays representable,
  `eff-reach` extends it (and only it), and the attack table's RANGE
  column can state both. Both render in that column
  (`_attack-range-cell`, `layout/common.typ`) as bare numbers joined by
  a middot --- `5 ft · 20/60 ft` --- with the **`Thrown` property in the
  Notes cell naming the second one**, rather than a qualifier word in
  the cell itself. That is a width decision, not a style one: RANGE is
  an `auto` column, so its widest cell sizes it for every row, and the
  letter's Weapons box is only ≈309pt wide --- a spelled-out
  `5 ft · 20/60 ft thrown` squeezed NOTES hard enough to hyphen-break
  `Two-Handed`. Keep new RANGE content terse for the same reason.
  **Proficient** if the character has a weapon proficiency matching the
  weapon's `category` ("martial") **or its name** (case-insensitively
  --- the 2024 Rogue is proficient with specific martial-finesse/light
  weapons granted by name, e.g. `"Scimitar"`), **or via Pact of the
  Blade** (see `eff-pact-blade`). **Both by-name matches --- proficiency
  and `eff-weapon-mastery` --- read `base-name`, not `name`.** `name` is
  the display name, which `magic-weapon` rewrites ("Shortsword +1", or a
  flavored "Fang of the North"); `base-name` is the catalog weapon's own
  name, defaulted from `name` in `eff-weapon` and preserved through that
  rewrite (`magic-weapon` overrides `name` alone). Matching on the
  display name is why a Rogue's Shortsword +1 once lost both its
  Proficiency Bonus and its Vex property --- a new by-name weapon lookup
  belongs on `base-name` for the same reason. `kind` `melee`/`ranged` sets the
  default ability (Str/Dex), unless a `Finesse` property (with no
  explicit `ability`) makes the resolver pick the better of Str/Dex. A
  weapon's mastery property (one of the eight in `constants.typ`
  `weapon-mastery-names`: Cleave/Graze/ Nick/Push/Sap/Slow/Topple/Vex)
  lives among its `properties`, but the resolver **always strips it from
  the displayed properties**: with trained mastery it rides the attack
  line as its own plain-string `mastery` field (the attack table renders
  it *italicized* after the ordinary properties --- typographic
  emphasis, not a new marker glyph); untrained, it is dropped entirely
  (see below). The **Versatile** property leaves `properties` the same
  way, for the same reason --- what it says depends on the character.
  Two fields carry it: `versatile`, the damage die the weapon deals in
  two hands (weapon data --- every Versatile weapon in the catalog
  declares it, and `_weapon` asserts the die and the property come
  together), and `two-handed`, the grip *this* character wields it in,
  set by `two-handed()` (see the weapons catalog note). The grip picks
  the die every line for that weapon rolls --- the True Strike and
  Booming Blade lines attack with the same weapon --- and the resolver
  puts the other grip's **full damage**, modifier included, on the line
  as `versatile-damage`, with `versatile-grip` naming that grip. The
  attack table's Notes cell reads `Versatile (1d10+4 two-handed)` beside
  a one-handed `1d8+4` in DAMAGE, so a player who switches grips
  mid-fight reads the new damage off the sheet. Shillelagh's line
  carries neither field: that cantrip sets the damage die itself, and
  the grip does not change it.
- `eff-weapon-mastery(..weapons)` --- the weapon names (bare strings,
  matched case-insensitively) a character has mastered. Emitted by the
  martial classes' `mastery:` param
  (`class.fighter(..., mastery: ("Dagger",))`; also barbarian, rogue)
  --- via a nested **"Weapon Mastery" class feature** that carries the
  effect *and* a `desc` naming the chosen weapons (they can change on a
  Long Rest), so the feature is visible on the sheet, not just its
  consequences. The resolver reveals a weapon's mastery property in the
  attack table only when the weapon is named here.
- `eff-pact-blade(ability)` --- Pact of the Blade (Warlock invocation).
  Names **no** weapon (the bonded weapon can change turn to turn): the
  resolver treats **every melee weapon and every magic weapon** (a
  nonzero magic `bonus`) as proficient and cast with the warlock's
  spellcasting `ability` (Cha), overriding the weapon's own default
  attack ability. So a Longsword +1 declared with no `ability:` shows a
  Cha-based, proficient attack; a mundane martial *ranged* weapon
  (neither melee nor magic) is left untouched. Emitted by
  `invocation.pact-of-the-blade`; the pact weapon is still declared as
  its own weapon feature (its `eff-weapon` supplies the attack line ---
  no `ability:` needed, the pact provides it).
- `eff-reach(value)` --- a melee-reach bonus in feet, stacking across
  sources. The resolver extends the `range` of every **melee** attack
  (the unarmed strike + `kind: "melee"` weapons), which by the
  `eff-weapon` rule above *is* that attack's reach --- so it always
  applies (`"5 ft"` → `"10 ft"`), a Thrown weapon included. A ranged
  weapon's projectile range and any weapon's `thrown-range` are left
  untouched: reach extends what you swing, not what you loose or hurl.
  Powers the Bugbear's Long-Limbed trait (+5 ft reach on melee attacks).
- `eff-cunning-strike(name, note, cost:, save-ability:, source:)` --- a
  Cunning Strike option (2024 Rogue, level 5): a non-damage rider added
  to a Sneak Attack hit by forgoing `cost` Sneak Attack dice (a dice
  string, `"1d6"`, rendered through `fmt-dice` like a weapon's damage
  --- not authored math). `note` is authored markup content describing
  the rider. `save-ability` is the **target's** saving-throw ability
  (Poison → Con, Trip → Dex) or `none` for a no-save rider (Withdraw)
  --- **not** the ability that drives the DC; Cunning Strike's own DC is
  always Dexterity-based regardless of which save a given rider imposes
  (see `resolve`). Display-only like `eff-save-advantage`/`eff-sense`
  except for its own DC. Named after the feature itself, like
  `eff-weapon-mastery`/`eff-reach`, rather than generically --- the
  cost+save+rider shape doesn't recur outside this one 2024 Rogue
  feature, unlike `eff-limited-use`'s uses/recharge shape, which many
  unrelated features share.

### Resolver (`src/resolve.typ`)

`resolve(char)` returns a computed record with: `name`, `player`,
`alignment`, `background`, `species`, `classes`, `traits` (all nested
features flattened, for display --- each dict's `activation`/ `notes`
fields, if authored, ride through unchanged, a `casts:` entry resolves
to a `cast` spell detail beside them, and `flatten-features`
stamps each *nested* feature with plain-string **ancestry**:
`via-name`/`via-kind` (the immediate parent's name and kind --- how a
feat nested in an invocation knows its granter) and `class-source` (the
nearest ancestor class's name --- how a `subclass-feature`, whose own
`source` is the subclass name, knows which class group it belongs to on
a multiclass sheet); a top-level feature carries none of them. The
resolver does no activation- or group-related computation of its own,
unlike `limited-uses`/`cunning-strikes` below --- bucketing traits into
the card deck's Action/Bonus Action/Reaction tables is layout-level
filtering: `card.typ`'s `_partition-features(c, char)` does all the
deck's bucketing in one place (returning a dict of buckets +
`has-actions`/`has-gear` flags that `_actions-card`/`card-sheet`
consume), while `letter.typ` keeps its own, deliberately different
partition (class features / species traits / feats as separate boxes).
The two layouts share the *predicates* --- `feature-kind`,
`activation-of`, `is-trait-kind`, `is-feat-kind`,
`is-class-feature-kind`, and the source-grouping trio
`trait-group-of`/`trait-groups`/`feature-tags` (`common.typ`, see the
source-grouping note) --- never the partition. **Actionable spells fold
into those same card tables the same way** --- pure layout-level
filtering in `_partition-features` over the flattened
`spellcasting[*].spells-detail`, keyed off each spell's `casting-time`:
an **Action** spell that makes an attack roll (`attack`), or does damage
*and* forces a save, joins the weapon **ATTACK** table (via
`attack-table`'s new `spells:` param --- a spell row shares the SPELLS
table's own cells rather than restating them: `_spell-hit-cell` for its
attack bonus or `fmt-save` DC, and `_spell-range-cell` (AoE glyph
included) for the RANGE column, so a spell reads identically in both
tables. Its damage fills the Damage column, and a multi-beam cantrip
keeps its `×N` beam count in the name cell like the spell table's SPELL
column (`spell-name-cell`, below). Those cells and `_aoe-icon` are
therefore defined **above**
`attack-table` in `common.typ`, since Typst evaluates a module
top-to-bottom); every **Bonus Action** / **Reaction** spell joins its
`activation-table` as a `(name, notes)` pseudo-item. The note is built
by `spell-action-note` (`common.typ`): an italic level marker --- the
word `"Cantrip."` for a cantrip, else the level in **degree notation**
(`"1°."`/`"2°."`/`"5°."`), its digit drawn from `text-font` so it opts
out of `body-font`'s Euler `covers` (Euler has no italic face, so a
covered digit would stay upright beside the italic `"Cantrip."`; ETBembo
italic sets it as an old-style figure) --- then, for
the 2-column Bonus Action/Reaction tables only (no Damage column), the
damage/healing, then the spell's own `notes`, then finally (trailing the
whole note) the filled up-triangle ▲ mark when the spell is upcastable
(`_upcastable` --- the mark *only*, never the `scaling` prose; these
rows stay terse); the ATTACK note omits damage (its own column has it).
To-hit/save-DC is *not* restated in the note. A **feature** in one of
those three tables gets its Notes cell from `item-action-note`
(`common.typ`, called by `activation-table` so all three share it): its
own `notes` prose, led --- when the feature declares `casts:` --- by the
spell it casts, read off the resolved `cast` detail as
`Cast _<Spell>_ ×N (<range>): <damage>.` The name (`×N` included) and
the range are the attack/spell tables' own cells (`spell-name-cell`,
`_spell-range-cell` with its AoE glyph), so a spell reads alike
wherever it appears; there is no level
marker, because that marker names a *slot* spent and an item cast spends
charges. This is why the Rod of Magic Missiles' note states 3 darts of
1d4+1 Force at 120 ft without any of it being authored: **an item's own
prose must never restate a number belonging to its spell.**
**A spell's name is set in italic wherever the sheet names one** ---
one rule, no exceptions, so the mark always means "this is a spell".
It matters most in these tables, the only ones that mix spells with
weapons, features, feats and magic items, where the level marker
leading the Notes cell (`1°.`) is far too easy to miss on its own. The
mark is applied at every site a name reaches the page:
`spell-name-cell` for a whole spell row's name column and for the
spell `item-action-note` says a feature casts; the cantrip half of a
weapon-attack cantrip's label in `attack-table`; the bold label of a
Short/Long Rest resource pool that tracks a free cast (see
`eff-limited-use`'s spell-object form); and `_…_`/`#emph(…)` in every
hand-authored `notes` and `desc` that names a spell (Wild Companion's
Find Familiar, Shield's Magic Missile, the Elven Lineage's three, the
computed lists in Magic Initiate and Fey Touched). The **one**
exception is the SPELLS tables' own SPELL column: there every row is a
spell, so the mark would carry no information and is left off. A
**weapon-attack
cantrip** (`weapon-attack: true` --- True Strike, Booming Blade,
Shillelagh) never
routes here as a spell row: it makes a *weapon* attack, so the resolver
has already expanded it into per-weapon lines in `c.attacks` and its own
spell row carries `attack: false` and no damage (so it fails this filter
by construction --- no skip needed). Such a line keeps the **weapon's
own `name`** and carries the cantrip in **`via-spell`**; the label
`<weapon> (<Spell>)` is composed in `attack-table`, which is what lets
the spell half be italic. Because the name no longer distinguishes the
two lines for a weapon, `via-spell` is what tells them apart (see
`attack-lines` in `resolve-test.typ`). Utility
Action spells (no attack, no damage+save) route nowhere here --- they
stay on the Spells card. **Card-deck only**; the letter has no such
tables), `level`, `proficiency-bonus`, `abilities`, `ability-mods`,
`ac`, `initiative`, `speed`, `max-hp`, `temp-hp`, `skills` (each
`bonus`/`level`/`joat`/`reliable`/`advantage` --- `advantage` from
`eff-check-advantage`, badged on the skill's own row), `saves`, `passives`
(Perception/Investigation/Insight --- `10 +` the skill's own bonus, plus **`5`
more when that skill carries `advantage`**, per the SRD's Passive Perception
rule; the Sentinel Shield's Perception advantage is what makes that term
visible), `proficiencies`
(`armor`/`weapon`/`tool`/`language` --- tool/language as ids),
`spellcasting` (per source:
`save-dc`/`attack`/`modifier`/`cantrips`/`spells`/`spells-detail`/`slots`/`kind`
--- `modifier` is the casting ability's own mod, carried because
`attack`/`save-dc` may include `eff-spellcasting-bonus` item bonuses, so
display never re-derives it as attack − PB), `attacks` (per weapon:
`bonus`/`damage`/`damage-type`/`range`/`thrown-range`/`properties`/`mastery`,
plus `versatile-damage`/`versatile-grip` on a Versatile weapon
--- `range` is the reach or projectile range with any `eff-reach` bonus
already folded in and `thrown-range` the separate throw range (see
`eff-weapon`); the trained mastery property as its own plain string, or
`none`; never merged into `properties`; `damage` is the damage of the
grip the character wields the weapon in and `versatile-damage` the other
grip's, both with the modifier folded in), `size`, `creature-type`, the display-only
gear pair `equipped`/`equipment` --- **two lists with different
meanings; never merge them**: `equipped` is the gear whose effects are
**live** on the sheet (every top-level weapon/armor/shield/magic-item
feature not marked `carried`, by display name, in declaration order ---
armor is setting the AC, a rod its DCs, a weapon its attack line), while
`equipment` is the **inert cargo** (`carried(...)` gear first, then the
declared `equipment:` strings --- authored as the unmodelled kit only).
Magic gear is suffixed `*` in both lists (any magic-item, or a weapon
with a nonzero magic `bonus`). `carried(f)` (model.typ) marks a gear
feature as in-the-pack: `flatten-features` skips it and everything
nested in it, so it contributes **nothing** (no effects, traits, attack
lines, or pools) and lists under INVENTORY --- the affordance for a
spare Rod of the Pact Keeper that must not boost anything; drop the
wrapper to equip it. Both layouts render the split (the card's Gear card
as EQUIPPED + INVENTORY sections; the letter's Equipment box as two
stacked eyebrow-labelled groups)/`currency`/`backstory`,
`save-advantages` (a flat list of `(note, source)`, one per
`eff-save-advantage` --- display-only like `backstory`; both layouts
footnote it beneath the saves), `resistances` (a flat list of
`(type, kind, source)` from `eff-resistance`, deduped by (kind, type)
--- Resistance/Immunity/Vulnerability, footnoted in the same Defenses &
Senses block between the save advantages and the senses), `senses` (a
flat list of `(name, range, source)` from `eff-sense`, deduped by name
keeping the longest range --- Darkvision/Blindsight/..., footnoted last
in that block), `limited-uses` (a flat list of
`(name, spell, uses, uses-label, recharge, source)` from
`eff-limited-use`,
**sorted** short-recoverable-then-long / scarcest-first / alphabetical
(`long-short-regain` groups with long) --- display-only; `uses` already
evaluated to a concrete int, so a function `uses` is resolved against
the computed context here; both layouts render a **diamond tracker**
grouped by recharge (short rest / long rest): the card deck as the
**tail of the Actions card** --- `resource-tables` (`common.typ`): two
side-by-side 2-column `sheet-table`s titled "Short Rest" / "Long Rest"
(title in the first-column header, mirroring
`activation-table("Action", …)` so they read as the final peers in the
action sequence after Other), the diamonds kept in the Uses cell with
any derivation label inline-left of them, the pair travelling together
inside one `keep-together` so neither bucket orphans across a card
break; **when any pool carries a footnoted recharge kind** (`_recharge-notes`
--- `long-short-regain` for Wild Shape and Second Wind, `dawn` for the
Ring of Comprehension), that kind's superscript symbol
(`_recharge-mark`, a fifth marker notation outside the
circle/diamond/hexagon/triangle vocabulary, reading as a footnote
reference and nothing else) marks each such pool's row via an invisible
metadata anchor carrying the kind, and the page's own footer
(`recharge-footer`) queries for those anchors and renders each distinct
kind's note once --- regardless of how many pools on the page carry the
same mark (a Fighter/Druid has both Second Wind and Wild Shape). This is
deliberately *not* a real Typst `#footnote`: nested inside
`resource-tables`'s `keep-together` (the whole-group card-bump
mechanism), Typst's measure/retry pass for a unit that doesn't fit the
current card can realize the footnote on the page the retry ran on while
the marked row renders on the page before it --- reproduced directly as
an "Actions (continued)" card with nothing on it but the stranded
footnote; the school-synergy marker hit the identical failure mode for
the identical reason (see `school-notes-footer`), hence the shared fix;
the letter as a single narrow **Resources box** on the roleplay page
(`limited-use-lines`, `single-column: true`, the box being too tight for
two `sheet-table`s) that **stacks** the two labelled groups vertically
instead (the marker rides each row the same way; the note lands at the
page bottom via the same query-based footer). `cunning-strikes` (a flat
list of `(name, cost, save-ability, save-dc, note, source)` from
`eff-cunning-strike`, declaration order preserved --- display-only
except for `save-dc`, computed once as `8 + PB + Dex mod` --- the
Rogue's own DC, not derived from any spellcasting source, since Cunning
Strike isn't spellcasting and doesn't go through
`eff-spellcasting`/`resolve-spellcasting` --- and stamped on every
option; both layouts render it as a **Cunning Strike table** directly
beneath the attack table, shown only when non-empty), and `raw`.
`backstory` is authored roleplay prose, given as `character()`'s
**trailing content block** (`character(...)[…]`, so it may carry
emphasis/lists/inline math; omit the block for a character with no
backstory) --- display-only, never read by the engine; the card deck
renders it as its own **Backstory card** (last in the deck) and the
letter sheet fills its **Backstory & Personality** box with it (both
only when declared; the box stays a blank printable field otherwise).
Each `spells-detail` entry carries its damage as **separate plain-data
fields** --- `damage` (the dice/mod string, `"3d10"`), `damage-type`
(`"Fire"`), and
damage-label`(the beam/dart annotation, else`none`) — mirroring`attacks`'`damage`/`damage-type`so display mathifies the dice and leaves the type upright without re-parsing a composed string. It also carries`school`(a plain passthrough of the spell's own`school`field, e.g.`"Illusion"`) — read only by the SPELLS table's school-synergy marker (`spell-schools`, above), not by the resolver. For a **fixed-slot upcast** (pact slots above the spell's base level), the resolver evaluates the spell's`at-level(level)`function and overlays its returned field overrides on the detail:`scaling`(computed-effect prose, replacing the per-slot delta), or`duration`/`concentration`/`area`(structured fields the scaling modifies — Major Image drops Concentration and lasts "until dispelled" at 4th+, Confusion's Sphere grows). A`scaling-computed`flag marks that`at-level\`
authored the scaling channel, so the renderer's drop-heuristics don't
clobber the computed prose.

Key formulas: `modifier = floor((score-10)/2)`;
`prof-bonus = 2 + floor((level-1)/4)`; total level = sum of
class-feature levels. **Max HP** (`fixed-max-hp`): computed by the 5.5e
fixed rule when `max-hp: auto` (the default) --- the first level of the
*first declared class* grants the die's maximum, every other level
grants `die/2 + 1`, plus Con mod × total level; a declared int overrides
the computation (rolled HP); either way `eff-stat("hp")` bonuses (Tough)
fold on top. Declaration order of classes therefore matters (it already
encodes the starting class for saves). **AC engine**: collect candidate
bases (default unarmored 10+Dex, armor bases with capped Dex, alternate
formula bases), take the max, then add flat bonuses. **Saves**: per
ability, `mod (+ PB if proficient)` plus any flat `eff-save-bonus`
(Cloak of Protection). **Spellcasting**: per source,
`DC = 8 + PB + ability mod`, `attack = PB + ability mod`, each plus any
matching `eff-spellcasting-bonus`. **Attacks**: per weapon,
`bonus = ability mod (+ PB if proficient with the category)`, damage =
dice + signed ability mod (`_damage-string`, which the Versatile
alternative grip runs through too, so both dice read the same
arithmetic). A weapon's attack ability defaults to Str
(melee) / Dex (ranged), but a **Finesse** weapon (with no explicit
`ability`) uses the **better of Str/Dex** --- so
`weapon.dagger`/`weapon.shortsword` swing off Dex for a Dex build and
Str for a Str build with no per-character wiring. Each resolved attack
line also carries a `kind` ("melee"/"ranged", the Unarmed Strike always
"melee"), read by `_apply-reach` and by the **weapon-attack cantrip**
expansion below.

**Weapon-attack cantrips** (`weapon-attack: true` --- True Strike,
Booming Blade, Shillelagh) don't make a spell attack; they make a *weapon* attack.
So the resolver **expands each into one extra attack line per applicable
weapon** in `resolve-attacks` (alongside the normal weapon lines,
`extra-attack: false` so they're excluded from Extra Attack). Such a
line keeps the **weapon's own `name`** and names the cantrip in
**`via-spell`**; `attack-table` composes the `<weapon> (<Spell>)` label
and sets the spell half in italic, so the split is a display concern and
`via-spell` --- not the name --- is what tells the line from the plain
weapon attack. Their own SPELLS-table row shows **no HIT/SAVE
(`attack: false`) and no damage** --- just their name and note. The three
differ in how the line is built: - **True Strike** (`_true-strike-line`,
keyed by `ts-ability` = the source that knows it): one line per
*proficient* weapon, cast with the **spellcasting ability** and dealing
**Radiant** damage + level- scaled dice. - **Booming Blade** (keyed by
`bb-note` = its authored rider prose): one line per **melee** weapon
that **reuses the weapon's own hit and damage** (it's a normal weapon
attack) --- the booming rider (no guaranteed on-hit damage, so it stays
out of the Damage column) rides in the line's `note`, which
`attack-table` renders as that row's *whole* Notes cell, displacing the
properties --- the row still shows its range, that being its own
column. The same prose is the cantrip's SPELLS-table note. - **Shillelagh** (`_shillelagh-line`, keyed
by `sh-ability` = the source that knows it): one line per weapon flagged
`shillelagh: true` (the Club and the Quarterstaff --- the only two the
spell names, so eligibility is weapon data, exactly like `true-strike`),
cast with the **spellcasting ability** for both attack *and* damage, the
die replaced by a level-scaled one (d8 → d10 at 5, d12 at 11, 2d6 at 17)
and the **weapon's own damage type** kept (the Force option is the
caster's choice on a hit, so it stays in the cantrip's prose rather than
the Damage column). Unlike True Strike it does **not** gate on
proficiency --- the spell imbues a weapon you hold, and PB rides the line
only when the character is already proficient. There is **no**
`weapon-attack-bonus`/`weapon-attack-name` threading and no best-melee
computation --- the per-weapon lines carry everything, so nothing needs
to be traced back to a single row.

### Feature catalogs (builder patterns)

Each lives under `src/features/` and follows the same shape --- a small
private builder plus named entries. Entries that involve **player
choices are functions**; those without are plain values (mirrors
`item.studded-leather` vs `class.bard(level: 4)`). **`species.*` is the
one deliberate exception: *every* species is a function, argument-less
ones included.** The convention buys a signal at the call site; in this
catalog it costs API stability, which is worth more. Most 2024 species
carry a lineage or ancestry choice, so a species modelled as a value
becomes a function the moment it is modelled properly --- and that
conversion is *breaking*, forcing a major bump and an edit to the
`@preview/dndist:<version>` import of every consumer file. An elf
character must not break because someone modelled the dragonborn. With
a uniform function shape, each later addition is a **named parameter
with a default**, which is additive and breaks nothing. Do not "fix"
`species.dwarf()` back into a value. Cross-catalog
builders live at the right altitude rather than per file: the subclass
builders (`sub-feature`, `subclass`) are shared from
`subclasses/common.typ` (each subclass file imports them under
`_`-prefixed names); species traits all go through one
source-parameterized `_trait(source, name, desc, ..rest)` (species.typ);
the caster classes build their Spellcasting/Pact Magic sub-feature via
`_spellcasting-feature` (classes.typ --- source, ability, cantrips,
spells, slots, plus `name:`/`prepared-at:` for the Warlock); and a
feature whose single effect is a same-named `eff-limited-use` pool
(Bardic Inspiration, Innate Sorcery, Magical Cunning, a magic item's
charges) uses `limited-use-feature` (model.typ) so the name/source
aren't restated --- a pool named *differently* from its feature (Lucky's
"Luck Points", a feat's granted-spell free cast) still declares its own
effect. - `species.*` --- `_species`; grants speed and trait skills ---
**never a language** (2024: languages are their own character-creation
step, entirely independent of species/background; see the languages note
below). **All are functions** (see the exception above).
`dwarf()`/`tiefling()`/`gnome()` are not modelled yet --- speed, size
and creature type only; `dwarf` is the one species with no
character-creation choice, so it keeps an empty signature even once its
traits land. `elf(lineage, skill, casting-ability)` requires its
lineage: the row (`_elven-lineages`) sets the level-1 cantrip, the
Darkvision range and the Speed (Wood Elf 35 ft), and Keen Senses takes
the chosen skill. Only that cantrip becomes an `eff-spellcasting`; the
level 3/5 lineage spells are gated on **total character level**, which a
species builder cannot see, so they stay prose --- the Fairy Magic
limitation. Drow emits Darkvision at 120 ft *beside* the base trait's 60
ft and lets the resolver's longest-range dedupe settle it, so both
traits' prose stays true (the `goggles-of-night` idiom).
`dragonborn(ancestry)` requires its ancestry (`_draconic-ancestries`
maps the ten dragons to a damage type), which drives both the Breath
Weapon damage and an `eff-resistance`; Breath Weapon is a PB-use pool
whose dice scale on character level and whose DC is Con-based, so its
`desc`/`notes` are `ctx` functions, and it carries **no `activation`**
--- it replaces one attack of the Attack action rather than being its
own action, the Cunning Strike reasoning --- while Draconic Flight's
level-5 gate keeps it prose with no pool. The **argument-less**
`orc()`, `aasimar()`, `bugbear()`, and `halfling()` have no player
choice --- `aasimar` is a Humanoid nesting Celestial
Resistance → `eff-resistance` Necrotic/Radiant, Darkvision →
`eff-sense`, Light Bearer → an `eff-spellcasting` Light-cantrip source
off Cha, plus Healing Hands and Celestial Revelation `eff-limited-use`
pools, each keeping its display prose; `bugbear` is a Medium goblinoid
Humanoid whose Sneaky trait grants Stealth proficiency, most of the rest
(Powerful Build/Goblinoid/Surprise Attack) display-only traits, except
Darkvision (emits `eff-sense("Darkvision", range: "60 ft")` --- Orc's is
120 ft), Fey Ancestry (emits `eff-save-advantage`), and Long-Limbed
(emits `eff-reach(5)` extending melee attack ranges) --- each keeps its
display prose *and* emits its effect (see the effect notes above);
`halfling` is a Small Humanoid whose Brave trait emits an
`eff-save-advantage` (Frightened) --- badged in the Defenses & Senses
footnote, so it deliberately carries no `notes` row, unlike Halfling
Nimbleness / Luck / Naturally Stealthy, which are display-only combat
affordances and do), and
the **functions** (player choices): `human(skill, origin-feat)` ---
the 2024 Human's Skillful skill and Versatile Origin feat, the feat
**nested** on the species feature so `flatten-features` collects its
effects and the FEATS list tags it `ORIGIN · HUMAN`; Resourceful's
Heroic Inspiration changes no computed stat and stays prose;
`tortle(size, skill)` ---
natural-armor formula (base 17, no Dex), chosen skill, `desc`-bearing
trait sub-features (Shell Defense splits into a parent,
`activation: "Action"`, and a nested "Emerge" child,
`activation: "Bonus Action"` --- see the effect/feature model note
above); and `fairy(casting-ability)` --- a Small Fey whose Fairy Magic
trait emits an `eff-spellcasting` (a species spellcasting source) for
the Druidcraft cantrip, plus a display-only Flight trait. -
`class.*(level, subclass, skills, expertise)` (functions) --- `_class`;
PB source, hit die, proficiencies (incl. `tools`), and named
sub-features (`jack-of-all-trades`, `unarmored-defense`,
`reliable-talent`). A non-empty `mastery:` also nests the **"Weapon
Mastery" class feature** (see `eff-weapon-mastery`). `subclass` may be
an object or a string.
`fighter(level, subclass, skills, mastery,   fighting-style)` grants
Second Wind (a `long-short-regain` limited-use Bonus-Action pool, 2 uses
at L1 → 3 at 4 → 4 at 10 --- regain all on a Long Rest and one on a
Short Rest), a chosen `fighting-style` (2024: **Fighting Styles are
feats**, category "Fighting Style" --- so `_fighting-style` is a
desc-less "Fighting Style" container class feature nesting the chosen
style as a `kind: "feat"`, `source: "Fighting Style Feat"` feature; it
flattens into the FEATS list tagged FIGHTING STYLE. Only Defense
contributes a mechanical `eff-ac-bonus(1)`; extend `_fighting-styles`
for more), and Extra Attack from level 5.
`bard(level, subclass, skills, expertise,   cantrips, spells)` is a full
Cha caster (Spellcasting sub-feature + `_full-caster-slots`, Musical
Instrument tool proficiency) plus Bardic Inspiration
(`activation: "Bonus Action"`, an `eff-limited-use` pool of
`ctx => max(1, CHA mod)` uses, recharging long-rest below level 5 and
short-or-long from 5).
`cleric(level, subclass, skills,   divine-order, cantrips, prepared)` is
a full Wis caster (Spellcasting sub-feature + `_full-caster-slots`) whose
level-1 Divine Order is the Primal Order shape, and so lives on the `class`
namespace beside `class.cleric(...)`: `divine-order-thaumaturge(cantrip)`
(the extra cantrip rides a `cantrips:` field the builder folds into its own
source, plus the Arcana/Religion `eff-skill-bonus` of +Wis mod, min +1) or
`divine-order-protector` (Martial weapons + Heavy armor training). Level 2
adds Channel Divinity, a `long-short-regain` pool (2 uses, 3 at L6, 4 at
L18) whose two effects --- Divine Spark and Turn Undead, each
`activation: "Action"` with `ctx`-computed dice and save DC --- **nest as
children that spend the parent's pool**, so the parent carries a `desc` but
deliberately **no `notes`**: its children hold the action rows, and a note
here would add a second OTHER-table row for the same feature. Modelled
through level 4 (what the played cleric has): Sear Undead (L5), Blessed
Strikes (L7, a player choice needing its own param) and Divine Intervention
(L10) are not in the catalog yet.
`druid(level, subclass, skills,   primal-order, cantrips, prepared)` is
a full Wis caster: a Spellcasting sub-feature emits an
`eff-spellcasting` with `slots` (`_full-caster-slots`, the shared
full-caster table) and always-prepared Speak with Animals; Primal Order
(Magician) emits the Arcana/Nature `eff-skill-bonus`. Level 2 adds Wild
Shape (a `long-short-regain` `eff-limited-use` Bonus-Action pool --- 2
uses at L2--5, 3 at L6--16, 4 at L17+; the known-forms count, CR cap,
and Fly-Speed allowance scale at L4/L8, so the desc and table notes stay
level-accurate) and Wild Companion (a plain Magic-action Action feature
that casts Find Familiar without Material components by expending a
spell slot or a Wild Shape use --- it borrows the pool rather than
carrying its own, so it emits no `eff-limited-use`, and Find Familiar is
cast *through* it, not added to the prepared list).
`sorcerer(level, subclass, skills, cantrips, spells)` is a full Cha
caster the same way (Spellcasting sub-feature + `_full-caster-slots`),
plus an Innate Sorcery feature (`activation: "Bonus Action"` --- the
card deck's Bonus Action table).
`rogue(level,   subclass, skills, expertise, mastery)` grants simple +
the martial-finesse/light weapons **by name** (Hand Crossbow / Rapier /
Scimitar / Shortsword / Whip), Thieves' Tools, and level-gated
sub-features (Sneak Attack w/ level-scaled `#ceil(level/2)d6`, Thieves'
Cant granting the language, Cunning Action ≥2 and Steady Aim ≥3 (both
`activation: "Bonus Action"`), Cunning Strike ≥5 (2024 Rogue --- one
feature emitting three `eff-cunning-strike` riders,
Poison/Trip/Withdraw, with no `desc:` of its own since the Cunning
Strike table is its display surface, mirroring how the Spellcasting
sub-feature also carries no `desc:`; Cunning Strike itself carries no
`activation` either --- it's a rider on an attack you're already making,
not a separate action, so it never moves into the Action/Bonus
Action/Reaction tables), Uncanny Dodge ≥5 (`activation: "Reaction"`,
display-only --- halving incoming damage isn't modeled), Reliable Talent
≥7 (2024 table --- not the 2014 PHB's 11th level)). Also
`warlock(level, subclass, saves, skills, cantrips, spells, invocations)`
--- a Cha "short-rest" caster (Pact Magic sub-feature, `_pact-slots`), a
display-only Magical Cunning feature (its own rule text names no
Action/Bonus Action/Reaction, so it stays untagged, unlike Innate
Sorcery above), a level-9 **Contact Patron** feature (folds a free
Contact Other Plane cast into the pact source, like Druid's Speak with
Animals, plus a 1/Long-Rest `eff-limited-use`), and an **Eldritch
Invocations** container feature nesting the chosen `invocation.*` (see
below). The container carries no `desc`, so it renders no line of its
own --- only the invocations show. The builder asserts the invocation
**count** matches the 2024 Warlock progression (`_invocations-known`: 1
at L1, then 3/5/6/7/8/9/10) --- an empty list is allowed (omit them;
focused tests needn't enumerate the set). `saves` defaults to the
single-class Warlock's Wis + Cha; **pass `saves: ()` when Warlock is a
multiclass (non-starting) class** --- only the starting class grants
save proficiencies (the template character is Fighter-first). - `subclass.<class>.*`
--- see the gotcha below. `subclass.bard.glamour` (value --- 2024
College of Glamour: Beguiling Magic, an `eff-limited-use` rider pool,
and Mantle of Inspiration `activation:   "Bonus Action"`). **A
subclass's always-prepared spells belong to the class source, not a
phantom subclass source, and they are subclass data, never re-declared
per character:** Beguiling Magic's Charm Person / Mirror Image are Bard
spells cast with Bard spellcasting, so the granting sub-feature carries
them as plain `spells:`/`cantrips:` fields --- the same shape
invocation-granted spells use --- and every caster builder folds them
into its own source (`_subclass-grants`, classes.typ). A subclass
deliberately never emits its own `eff-spellcasting`: its spells are the
class's, and a second source would split them out of the class's own
spell group and slot pool. (The spellcasting *header* would merge the
two rows --- same ability, DC and attack --- but only the header
merges.) `subclass.cleric.light` (value --- 2024 Light Domain, modelled at
L3: the always-prepared Light Domain Spells (a desc-less sub-feature
carrying Burning Hands / Faerie Fire / Scorching Ray / See Invisibility ---
the reason a Light cleric never authors those four), Radiance of the Dawn
(`activation: "Action"`, its Radiant dice reading the closure's own Cleric
level; it expends a Channel Divinity use, so like Wild Companion it emits no
pool of its own), and Warding Flare (`activation: "Reaction"`, a Wis-mod
`eff-limited-use` pool). Improved Warding Flare (L6) and Corona of Light
(L17) are not modelled yet.) `subclass.bard.lore(skill.…, …)` (function);
`subclass.rogue.assassin` (value --- L3 Assassinate (its extra damage
equals the Rogue level, so `desc`/`notes` read the closure's own level,
the Awakened Mind pattern; it carries **no `activation`**, riding an
attack rather than being one, so it routes to the card's OTHER table ---
same reasoning as Cunning Strike) + Assassin's Tools (the Disguise Kit
and Poisoner's Kit `eff-prof`s));
`subclass.rogue.phantom(gained: skill)` (function --- the chosen
Whispers of the Dead proficiency; Wails from the Grave is display-only
--- a Sneak Attack rider, not its own action, same reasoning as Cunning
Strike above); `subclass.warlock.great-old-one` (value --- L3 Awakened
Mind (`activation: "Bonus Action"`), the always-prepared Great Old One
Spells (a desc-less sub-feature carrying the 2024 table's level-gated
rows --- 4 spells at L3, growing at 5/7/9 --- folded into the Pact Magic
source per the rule above), and display-only Psychic Spells; L6
Clairvoyant Combatant (a short-or-long `eff-limited-use` rider on
Awakened Mind); L10 Eldritch Hex (carries its always-prepared Hex the
same way) + Thought Shield (emits `eff-resistance` Psychic));
`subclass.druid.circle-of-the-moon` (value --- L3 Circle Forms (its CR
cap, AC, and Temporary HP all scale, so `desc`/`notes` are `ctx`
functions reading the *closure's* Druid level for CR/THP and
`ctx.ability-mods.wis` for the AC --- the Awakened Mind pattern; it
carries **no `activation`**, being a rider on Wild Shape rather than its
own Bonus Action, so it routes to the card's OTHER table, same reasoning
as Cunning Strike) + the always-prepared Circle of the Moon Spells (a
desc-less sub-feature; Starry Wisp rides its `cantrips:` field and the
rest its `spells:`, growing at 5/7/9); L6 Improved Circle Forms; L10
Moonlight Step (a Wis-mod `eff-limited-use` Bonus-Action pool); L14 Lunar
Form). Subclass
objects carry `features: level => (…)`; a `subclass-feature` with a
`desc` shows under Class Features (both layouts). - `invocation.*` ---
Eldritch Invocations (2024 Warlock), passed to
`class.warlock(..., invocations: …)`. `_invocation` builds each with its
own `kind: "invocation"` --- a Warlock class feature mechanically (the
shared `is-trait-kind`/`is-class-feature-kind` predicates include the
kind, so it renders like any other --- Class Features box / card action
& trait tables, keyed off `desc` + `activation`), but the dedicated kind
is what the layouts key the **ELDRITCH INVOCATIONS** source group off
(grouping off the `source` display string would be brittle). Entries
with a choice are functions, those without are plain values (mirrors the
feat/subclass catalogs): `pact-of-the-blade` (**value** --- Bonus
Action; emits `eff-pact-blade(cha)`, names no weapon --- see that
effect), `agonizing-blast(cantrip)` (function ---
`eff-spell-damage-bonus(+Cha)` on the chosen cantrip), `fiendish-vigor`
(value --- Action, display-only prose: cast False Life at will, max
THP), `thirsting-blade` (value --- `eff-extra-attack(2)`),
`eldritch-mind` (value --- `eff-save-advantage` on Con concentration
saves), `pact-of-the-tome(cantrips, spells)` (function --- the book's
chosen cantrips + ritual spells), `repelling-blast(cantrip)` (function
--- display-only push prose), `one-with-shadows` /
`visions-of-distant-realms` (values --- each grants a free-cast spell,
Invisibility / Arcane Eye). **An invocation-granted spell is cast with
the Warlock's own spellcasting**, so these three carry their spells as
plain `cantrips`/`spells` fields that `warlock()` folds into its Pact
Magic source --- an `eff-spellcasting` per invocation would split them
out of Pact Magic's own spell group and slots (the Glamour rule). The
levelled spells fold in as per-spell
`(spell: s, slot: <own level>)` pins: a ritual or slotless free cast has
no slot to upcast with, so each groups at its own level (not the
pact-slot level) and, being fixed-slot, never shows the ▲/`scaling`
prose. `lessons-of-the-first-ones(origin-feat)` (function --- **nests
the chosen Origin feat**, e.g. `feat.tough`, so it flattens into the
trait list and contributes its effects). Prereqs are noted in comments;
only the per-level count is enforced (in `warlock()`). -
`background.*(..abilities, …)` (functions) --- `_background`; validates
the ability allocation (+2/+1 or +1/+1/+1, inferred from the count ---
two chosen = +2/+1 with the first getting the +2) against the
background's allowed trio, grants skills/tools, nests an origin feat.
acolyte (Int/Wis/Cha; Insight/Religion, Calligrapher's Supplies --- its
fixed Magic Initiate (Cleric) still needs the player's cantrip and spell
choices, so it takes `origin-feat:` like `sage`), entertainer,
marked-wanderer, sage, genie-touched (Deception/Perception,
Glassblower's Tools, Magic Initiate (Wizard)), criminal (Dex/Con/Int;
Sleight of Hand/Stealth, Thieves' Tools, Alert), farmer (Str/Con/Wis;
Animal Handling/Nature, Carpenter's Tools, Tough).
`background.custom(name, abilities:, skills:, tools:, origin-feat:)`
declares a **one-off background** (a homebrew/setting background used by
a single character --- elara's Guide, the template's Faction Agent) in one
call, with no fixed trio to validate against; a background used by more
than one character should graduate to a named catalog entry instead.
Never model a background as raw `eff-*` lines in the `effects:` escape
hatch. - `item.*` (mostly values) --- full armor table (`_armor`),
shields, AC items (incl. `cloak-of-protection` --- both halves compute:
`+1` AC (`eff-ac-bonus`) and `+1` to all saves (`eff-save-bonus`)),
`boots-of-elvenkind` (an `eff-check-advantage` on Stealth --- the
silent-movement half changes no value and stays prose),
`goggles-of-night` (an `eff-sense` Darkvision 60 ft --- the resolver's
dedupe already keeps the longest range, so the item's "+60 ft on existing
Darkvision" half stays prose),
`sentinel-shield` (a Shield *and* a magic item, so it carries both halves
that compute: `eff-ac-bonus(2)` and an `eff-check-advantage` on Perception,
which also raises the passive score by 5 --- the Advantage-on-Initiative half
is not modelled and stays prose, the `boots-of-elvenkind` treatment),
`magic-armor(base-id, bonus, name)` (a function --- a `+N` version of a
table armor: base AC raised by `bonus`, same Dex cap, optional flavored
`name` like "Do-Maru Half Plate +1"),
`rod-of-the-pact-keeper(bonus, source-name:)` (a function ---
`eff-spellcasting-bonus` on the `"Warlock"` source by default, plus a
nested Magic-action "Regain Pact Slot" child (the Telekinetic
parent/child split) tracked as a 1/Long-Rest pool), plus
`wand-of-magic-missiles(name)` (a function --- the `name` param
**reskins the display**, e.g.
`item.wand-of-magic-missiles(name: "Rod of Magic Missiles")` for elara's
flavored instance; the pool/effects follow the name). A **magic item
that grants an activated ability** (charges + a Magic-action power,
e.g. the Wand of Magic Missiles) is a
`feature(kind: "magic-item", activation: …, effects:   (eff-limited-use(name, max-charges),))`:
`card.typ`'s `is-trait-kind` recognizes `magic-item`, so an activated
one lands in the card's **Action/Bonus Action/Reaction** table (a
passive one in the Traits list) and its charges show at maximum in
**Resources**; the letter has no feature box for it (its three boxes are
class-feature/subclass-feature, trait, feat), so on the letter it
appears only in Resources. A magic item is **never a spellcasting
source** --- it has no spellcasting ability, DC, or attack, so it must
not emit `eff-spellcasting` (that would add a bogus row to the
spellcasting header). When the activated power *is* casting a spell, the
item names it with **`casts:`** (see the feature-field note above) and
`items.typ` imports `spells.typ` for it: `wand-of-magic-missiles` casts
`spell.magic-missile` pinned to slot 1, `wand-of-magic-detection` casts
`spell.detect-magic`, and `ring-of-comprehension` ---
**homebrew**, the Helm of Comprehending Languages reworked as a charged
ring --- casts `spell.comprehend-languages`. That is the whole of it --- **neither the `desc`
nor the `notes` of an item may restate a number that belongs to its
spell.** Both wands' prose is the published item text about charges;
every dart, die and range on the sheet is read from the spell catalog. - `weapon.*` (values) --- `_weapon`; each emits an
`eff-weapon`. Full 2024 PHB weapon catalog (38 weapons across simple/martial and melee/ranged):
simple melee (`club`, `dagger`, `greatclub`, `handaxe`, `javelin`, `light-hammer`, `mace`, `quarterstaff`, `sickle`, `spear`),
simple ranged (`dart`, `crossbow-light`/`light-crossbow`, `shortbow`, `sling`),
martial melee (`battleaxe`, `flail`, `glaive`, `greataxe`, `greatsword`, `halberd`, `lance`, `longsword`, `maul`, `morningstar`, `pike`, `rapier`, `scimitar`, `shortsword`, `trident`, `warhammer`, `war-pick`, `whip`),
martial ranged (`blowgun`, `hand-crossbow`, `crossbow-heavy`/`heavy-crossbow`, `longbow`, `musket`, `pistol`).
Finesse weapons (`dagger`, `dart`, `rapier`, `scimitar`, `shortsword`, `whip`) specify no explicit `ability:` so the resolver picks the better of Str/Dex.
Thrown weapons (`dagger`, `handaxe`, `javelin`, `light-hammer`, `spear`, `dart`, `trident`) carry `thrown-range:` (e.g. `"20/60 ft"`).
`club` and `quarterstaff` carry `shillelagh: true` (the cantrip names exactly those two weapons).
Every Versatile weapon (`quarterstaff`, `spear`, `battleaxe`, `longsword`, `trident`, `warhammer`, `war-pick`) declares its two-handed die as `versatile:`; `_weapon` asserts that die and the property are declared together.
`two-handed(base)` (exported top-level beside `magic-weapon`, and
composing with it in either order) rewrites the base feature's
`eff-weapon` with the grip: `two-handed(magic-weapon(weapon.longsword,   bonus: 1))` is Kragor's sword, rolling 1d10 instead of 1d8. It panics on
a weapon with no versatile die, since only a Versatile weapon has a
second one. A Shield leaves no hand free for the second grip, and the
resolver still gives that character the shield's AC, so declaring both
sheets two fighting styles for one character.
`magic-weapon(base, bonus:, name:)` (exported top-level, mirroring
`item.magic-armor`) builds a **`+N` version of a catalog weapon** by
rewriting the base *feature object's* `eff-weapon` --- flat `bonus` on
attack & damage (a nonzero bonus is also what marks it magic, for Pact
of the Blade and the inventory `*`), default name `"<Weapon> +N"`,
optional flavored `name`. It keeps `kind: "weapon"`; a pact weapon is
just `magic-weapon(weapon.longsword, bonus: 1)` next to
`invocation.pact-of-the-blade` --- never a hand-rolled
`feature(…, eff-weapon(…))` blob. - `spell.*` ---
`_spell(name, level, school, casting-time, range, area, components, duration,   concentration, ritual, save, attack, weapon-attack, check, trigger, material-cost, notes, scaling,   at-level, effects)`;
cantrips/levelled spells are data (the metadata fills the spell tables),
AC spells (`mage-armor`) also carry effects so they double as features.
`save` is the abbreviated ability that targets roll (all-caps, `"STR"`);
`attack: true` marks a spell that makes a spell attack;
`weapon-attack: true` (True Strike, Booming Blade, Shillelagh) marks one that makes
a *weapon* attack instead --- the resolver expands it into per-weapon
attack lines and its own SPELLS row shows no HIT/damage (see the
weapon-attack-cantrip note above). **`casting-time` is required** ---
`_spell()` asserts it is non-`none` (a missing one silently drops the
spell out of the card deck's action-economy routing below, so it's a
data bug, not a default); its value shares the exact
`"Action"`/`"Bonus Action"`/`"Reaction"` vocabulary as feature
`activation` (plus free-form non-action times like `"1 hr"`). `area` is
`(shape, size)` where `shape` is one of
square/cube/circle/sphere/cylinder/line/cone (drawn as a glyph in the
RANGE column); `trigger` is a reaction's trigger text (rendered
`Reaction: <trigger>`); `material-cost: true` shows the material
component as `M$` instead of `M`. `check` is authored prose naming an
ability/skill **check** the target makes against your spell save DC ---
a *check*, not a saving throw (Minor Illusion's "Study + Investigation
to discern") --- so it stays **out of the HIT/SAVE column**
(attacks/saves only) and renders in DAMAGE/EFFECT as the prose followed
by the resolved DC (`… (DC 14)`), the number pulled from the source's
`save-dc` at render time (not a literal, so it's correct for any
caster). Keep triggers/save wording out of `notes` --- the columns
render them. **A catalog spell's `notes` states that spell's own rules
text and nothing else --- never the vocabulary or the upgrades of a
feature that grants it.** A feature granting a customized variant
(`spell.mage-hand + (…)`, the Telekinetic feat) **appends to
`spell.<x>.notes`** rather than rewriting it, and states only the
upgrade that has no column of its own --- the range and component
changes are already in RANGE and COMP. This is the mirror of the rule
that an item's own prose must never restate a number belonging to its
spell: prose lives once, at the source that owns it. Mage Hand's note
opening "Telekinetically manipulate an object" is the bug this rule
exists to prevent --- Mage Hand is a spectral floating hand, telekinesis
belongs to `spell.telekinesis` and the Telekinetic feat, and every
ordinary caster's sheet inherited the feat's word.
`scaling` is authored prose for a spell's **per-slot upcast
scaling** (`[$+1d 6$/slot above 1st.]`, `[$+1$ target/slot above 1st.]`)
--- a **dedicated attribute, separate from `notes`**. Its **prose**
renders *only* in the SPELLS table (both layouts' spell boxes route
through `spell-table`): trailing the DAMAGE/EFFECT cell **after** the
duration, behind a small **filled up-triangle ▲ marker**
(`_scaling-mark`, `common.typ` --- its own separator, no bullet). The
card deck's terse ATTACK / Bonus Action / Reaction notes
(`spell-action-note`) never restate the prose, but **do show the ▲ mark
alone** --- trailing the whole note (at the end) --- to flag that the
spell is upcastable (`_upcastable`, `common.typ`: has `scaling`, isn't a
cantrip, isn't fixed-slot). For a **fixed-slot cast** (`fixed-slot`,
e.g. a warlock's pact slots) the **▲ mark is always suppressed** ---
it's an affordance ("you may spend a bigger slot"), and there is no
choice --- and the **per-slot delta prose is replaced by a computed
effect at the effective slot**, authored via `at-level` (below):
Banishment at a 5th-level pact slot reads "Targets up to 2 creatures"
instead of "+1 target/slot above 4th.", Dispel Magic reads "Auto-end a
spell of level 5 or lower", and Major Image drops its Concentration tag
and shows "until dispelled" as its duration. When `at-level` overrides
structured fields (`duration`/`concentration`/`area`), it returns
`scaling: none`, so the prose channel is silent and the structured cells
carry the result. A spell without `at-level` falls back to the per-slot
prose (bullet-joined, no ▲) so info isn't lost while the computed forms
roll out. A fixed-slot cast *at* the spell's own level (no headroom)
always drops the prose (this is why the free-cast invocations pin
`prepared-at` to the spell's own level), as does a spell whose
damage/healing came from slot tiers (the DAMAGE cell is already the
fixed-slot value --- Cloud of Daggers' 10d4 --- so restating "+2d4/slot
above 2nd" would misread as further growth). Keep upcast scaling in
`scaling`, not `notes`; a free-cast pool (Magic Initiate's / Fey
Touched's granted spell) is not scaling --- it's an `eff-limited-use` on
the *granting feature*, not the spell.
**`notes`/`scaling`/`trigger`/`check` are markup content** (`[…]`), not
strings --- see the descriptive-text convention below. - `feat.*` ---
`musician`, `lucky`, `alert` (+PB Initiative via an `eff-stat`
`proficiency` kind), `crossbow-expert` (+1 Dex), `tough`
(**mechanical**: `eff-stat("hp", ctx => 2 * ctx.level)` folded on top of
the computed --- or declared --- max HP) (values); `resilient(abil)`,
`dual-wielder(abil)` (a **General** feat --- the `+1` Str/Dex bump and
Quick Draw on the passive parent, an "Enhanced Dual Wielding" child at
`activation: "Bonus Action"`, the Telekinetic parent/child split),
`telekinetic(abil, casting-ability)` (the ability bump and Mage Hand
grant stay on the passive parent feature --- the granted Mage Hand is a
**customized variant** of `spell.mage-hand`, dict-merged with the feat's
upgrades (60 ft range, `components: none`, and a `notes` **composed
from** `spell.mage-hand.notes` plus the one upgrade with no column of
its own, the Invisible hand --- see the catalog-prose rule in the
`spell.*` note above), so the shared spell data stays feat-free and the
two notes cannot drift; a nested "Telekinetic Shove"
child carries `activation: "Bonus Action"`, same parent/child split as
Shell Defense above),
`magic-initiate(class, casting-ability, cantrips, spell)`, and
`fey-touched(abil, casting-ability, chosen-spell)` --- `+1` to `abil`
plus an `eff-spellcasting` source for Misty Step and the chosen
1st-level Divination/Enchantment spell, each with an `eff-limited-use`
1/Long-Rest free cast (param named `chosen-spell`, not `spell`, so it
doesn't shadow the imported `spell` module used for Misty Step) **and**
an `eff-spell-any-slot` (both feats' granted spell(s) also cast normally
with any spell slot the character has, per their own rule text --- see
the effect note above) (functions). `telekinetic`/`fey-touched`'s
`casting-ability` **defaults to the boosted ability** (the usual choice)
--- pass it only when the two differ. A feat's `source` string encodes
its **2024 category**: `"Origin Feat"`, `"Fighting Style Feat"` (the
styles nested by `_fighting-style`, classes.typ), or plain `"Feat"` for
a General feat --- `feature-tags` (common.typ) maps the first two to the
FEATS list's ORIGIN / FIGHTING STYLE tags (General stays untagged).

## Code comments

1. Style & Structure: Use short bullet points adhering to Simplified Technical English (STE) principles. Use simple verbs, active voice, and clear nouns.
2. Focus on Current State: Describe only the present code state. Do not include change history, commit notes, or "before vs. after" explanations.
3. Explain the Non-Obvious: Comment on complex logic, edge cases, invariants, and business rules.
4. Do not explain the obvious: Do not restate what the code clearly expresses (e.g., avoid writing # increments i by 1).
5. Forbidden Phrasing:
	- Avoid contrastive filler (e.g., "X, not Y", "Instead of doing X, this does Y").
	- Avoid conversational fluff or editorializing (e.g., "This clever trick...", "Make sure to...", "Crucially...").
6. Brevity Constraint: Keep inline comments to a maximum of 1–2 short lines/bullets per block.

## Conventions

- **Game concepts are objects** (`ability`/`skill`/`tool`/`spell`); pass
  the object or its string id --- `id-of` normalizes. Score input is
  id-keyed.
- **Character files declare, they don't compute --- and they don't
  narrate.** `abilities:` holds *base* scores; backgrounds/feats/ASIs
  apply their increases, and no comment restates the arithmetic ("giving
  final Dex 16") --- that's the resolver's output, not authoring input.
  `max-hp:` is omitted (computed; see the resolver note) unless HP was
  rolled. Every game concept gets its named form: extra languages and
  tool proficiencies are the `languages:`/`tools:` `character()` params,
  an Ability Score Improvement is `asi(ability.cha, 2)`, a one-off
  background is `background.custom(…)`, a magic weapon is
  `magic-weapon(…)` --- the raw `effects:` escape hatch is for genuine
  one-off effects only, not for concepts a builder already names.
  `equipment:` lists only unmodelled kit; a modelled item that's merely
  in the pack is `carried(item.…)` (inert --- INVENTORY), and a bare
  gear feature is equipped (live --- EQUIPPED; see the resolver's
  gear-pair note).
- **Languages are a character-creation choice, not a species/background
  grant.** 2024 PHB "Choose Languages": every character knows Common
  (granted automatically by `character()`, never authored) plus two
  chosen languages from the Standard Languages table --- species and
  background contribute *none* (neither catalog emits
  `eff-prof("language", …)`). Author the two chosen languages via
  `languages:`. Only a class/subclass/feat feature may grant an
  *additional* language as part of its own rule text (Druidic, Thieves'
  Cant + one language of choice, a Magic Initiate's granted spell) ---
  those stay wired on the granting feature, same as any other effect.
  `background.custom` is the one background builder taking a
  `languages:` param --- the escape hatch the catalog backgrounds
  deliberately lack (`backgrounds.typ`). A one-off setting background
  whose own rule text grants a language declares it there, so the grant
  stays on the feature that makes it rather than being folded into the
  character's two chosen languages: the template's Faction Agent grants
  Undercommon that way.
- **Descriptive/prose text is markup content (`[…]`); identifiers, keys,
  and computed values are strings.** Authored prose --- spell
  `notes`/`scaling`/`trigger`, trait/feat/subclass `desc` --- is
  `content`, so Typst's smart quotes curl apostrophes (`Doesn't` →
  `Doesn’t`) and dice/mods can be written as inline `$…$` math (see the
  math note). It flows through the same display sites as before
  (`[#s.notes]`, `[ — #f.desc]`), which `#`-interpolate and only
  null-check, so `content` and `str` both work --- but only `content`
  gets markup typography. Strings stay strings where identity matters:
  ids, names used for matching (weapon mastery, spell lookup), and
  resolver-computed values (the damage strings the tests assert). Those
  that are *displayed* verbatim yet must stay strings (equipment labels,
  the "Tasha's"/"Nature's Intuition" names, tool names in
  `constants.typ`) carry a **real `’` U+2019** in the source --- correct
  data, no render-time trick. A blunt reason not to over-reach: a lone
  `*` or `~` in a would-be markup string is a Typst control char (`~` =
  nbsp), which is why label lists with footnote `*`/`×N` stay strings.
- **Tool proficiencies are stored as apostrophe-free ids, displayed via
  the tool's canonical name.** `tools.typ` `_id(name)` derives a kebab
  id by dropping apostrophes then collapsing every non-alnum run to a
  hyphen (`Calligrapher’s Supplies` → `calligraphers-supplies`); the
  resolver stores that id. For display the layouts map ids through
  `tool-label` (`common.typ`), which looks the id back up in the `tool`
  catalog to recover the name **with** its apostrophe --- do *not*
  `titly(id)` a tool (that drops the apostrophe). Other prof categories
  (armor/weapon/language) still `titly` their raw keys.
- **A namespace that holds functions must be a module, not a dict.**
  `subclass.bard.lore(...)` works because `bard` is a module
  (`subclasses/bard.typ`); on a dict, `dict.lore(...)` parses as a
  *method* call and errors. This is also why `item`/`class`/`spell` are
  imported modules.
- **Fonts:** ETBembo (`body-font`) for body, Montserrat (`label-font`)
  for headings/labels. Layout metrics assume these; provided by the
  flake (`pkgs.et-book`, `pkgs.montserrat`).
- **Typst package deps:** `@preview/cuti:0.4.0` (fake bold + fake small
  caps --- see the bold-synthesis and small-caps notes) is the only
  external Typst package. It's declared as `typstDeps` on the
  `buildTypstPackage` in `flake.nix` (`pkgs.typstPackages.cuti`);
  `typst.wrapper` propagates it, so it resolves as `@preview/cuti` for
  compile/`nix flake check`/devShell with no extra `--package-path`
  wiring. Add future Typst-package deps the same way.
- **The design unit `u` (`common.typ`), and the layout registry
  `layouts.typ`.** Every absolute length in a layout file is a multiple
  of `u` (`1pt * scale`) --- type sizes, strokes, radii, insets, gaps
  --- and the registry entry for the active layout (named once in
  `src/layout/layouts.typ`, selected by `--input layout=…`) provides
  its `scale`, page geometry, and scale-1 margins. `em`-relative tokens
  (`dense-leading`/`row-inset`/`row-gap`/`group-gap`, the `0.055em`
  fake-bold strokes, `pad(left: 1em)`) and relative lengths (%), `fr`,
  `size * n`) are *not* multiplied: they follow the font size already.
  Inch/mm-authored lengths multiply by `scale` instead of `u`
  (`0.3in * scale`). There must be **no bare `pt` literal** in a layout
  file (module tokens included: `section-gap = 16 * u`,
  `card-stat-size = 13 * u`, `prof-mark-size = 6 * u`,
  `flag-size = 8 * u`). The deck's two fixed compositions (placard,
  core card) are authored at the registry's `fixed-scale` and rendered
  via `at-scale(factor, body)` (`common.typ`): laid out in a region
  `1/factor` the real size so wraps and `1fr` columns resolve at the
  fixed unit, then scaled back to fill the card. A new layout is one
  registry entry, nothing else.
- **Identifiers** use kebab-case (`studded-leather`, `card-sheet`).
- Renderers call `resolve()` themselves --- pass them a **declared**
  character, not a resolved one.
- **One character file, layout chosen at the command line.** A character
  is declared once, then the file ends with a single `#sheet(char)`.
  `sheet()` (`dndist.typ`) is the *one* place that dispatches to
  `card-sheet`/`letter-sheet`, reading `sys.inputs.layout`
  (`--input layout=card|card-lg|card-5x8|letter`, defaulting to card);
  never inline that if/else per file. The layout set and the design unit
  live in the registry (`src/layout/layouts.typ`), and `sheet()` reads
  it --- `assert`s that a per-call `layout:` override agrees with
  `--input layout=…`, because `u` is fixed for the compile by the input.
  A bare `typst compile <f> --input layout=…` works
  from the devShell, and the consumer repo's ninja rule passes the same
  flag per edge. This is why every character file --- a fixture here, a
  real character there --- must go through `sheet()` rather than calling
  a renderer directly: it is what lets a caller loop files × layouts
  with no per-file wiring.
- **Marker vocabulary (both layouts):** *circles mark
  training/proficiency; diamonds mark resource tracking; a hexagon marks
  a conditional save advantage; a filled up-triangle marks per-slot
  upcast scaling; a superscript symbol marks a footnote reference.*
  Never mix them. The triangle (`_scaling-mark`, `common.typ` --- a
  filled accent ▲) is a deliberate **fourth** shape, sanctioned for
  exactly one meaning --- *this spell upcasts*: prefixing a spell's
  `scaling` prose in the SPELLS-table DAMAGE/EFFECT cell, and standing
  alone (no prose) in the card deck's terse ATTACK / Bonus Action /
  Reaction notes to flag the same (see the informational-glyphs note).
  It reads as none of the other three (neither proficiency, nor
  tracking, nor save advantage), so it never collides with them. The
  footnote symbol (`_recharge-mark`, `common.typ`) is a **fifth**
  notation, sanctioned for exactly one meaning --- *this resource pool's
  recharge column does not state the whole rule*: a superscript symbol
  on the pool's row, the note rendered once at the page bottom by
  `recharge-footer` when any such marker landed on that page. The symbol
  is fixed **per recharge kind** in `_recharge-notes`, never sequential,
  so the same rule always reads with the same mark: `§` for
  `long-short-regain`, `*` for `dawn`. A
  superscript symbol reads as a footnote reference and none of the four
  shapes above, so it never collides with them. **Not a Typst native
  `#footnote`** --- see the resource-tables note above and the
  `school-notes-footer` note below for why (a real footnote realized
  inside `keep-together` can strand its note on an otherwise-blank
  continuation card, reproduced directly). **A spell-table row's
  school-synergy marker reuses this same superscript-symbol reading, via
  the identical query-based mechanism, but its own symbol sequence (`*`,
  `†`, `‡`, ...) is assigned independently of `_recharge-notes`' fixed
  symbols\*\* --- a Warlock with both a school-synergy note and a
  `long-short-regain` pool can land both notes on the same page, and two
  unrelated notes sharing a symbol would read as one run-on footnote,
  which is why `§` sits outside that sequence. **`dawn`'s `*` does
  overlap the sequence's first symbol**: only a character carrying both
  a dawn-recharge item and a school-synergy feature (Psychic Spells,
  Beguiling Magic) can land both notes on one page --- none does today.
  Move the school sequence to start at `†` if one ever does.
  See the `school-notes-footer` note below for why it isn't a Typst
  footnote either, and for how it stays a true page-bottom note despite
  that. Circles: skill/save/armor proficiency marks (`mark-*`,
  `armor-training`). Diamonds: the `checkbox` --- shield flag, death
  saves, heroic inspiration, magic-item attunement, expended spell
  slots, and the **limited-use resource tracker** (`_uses-cell`,
  `common.typ`: N diamonds per pool, with any derivation label inline
  just left of the diamonds --- the shared Uses cell behind both the
  card's `resource-tables` and the letter's `limited-use-lines` tracker,
  from `eff-limited-use`). Hexagon: `adv-badge` (a hexagon enclosing
  "A", `common.typ`) --- a deliberate *third* shape so it reads as
  neither proficiency nor tracking. It means **advantage**, and it has
  exactly two sites, which differ by how much of a thing the advantage
  covers. (1) A **save-advantage entry in the "Defenses & Senses"
  footnote** (badge + the `eff-save-advantage` prose), **never** on a
  save box: that advantage rarely covers all of an ability's saves
  (charmed is condition-scoped, War Caster is concentration-only), so a
  box would over-claim and the prose has to say when it applies. (2) A
  **`skill-row` whose skill carries `advantage`** (from
  `eff-check-advantage` --- Boots of Elvenkind's Dexterity (Stealth)),
  trailing the skill name. That advantage covers one whole skill
  unconditionally, and a skill *is* a row, so the row states it outright
  and carries **no prose** --- the granting item's own rule text already
  reads in Features & Traits (the label-by-name-only rule for summary
  surfaces), and the "Defenses & Senses" header would be wrong for a
  Stealth check. Reach for `eff-save-advantage` when the advantage needs
  a *when*; for `eff-check-advantage` when it does not.
  That footnote (`character-notes`, `common.typ`) holds three kinds of
  entry in one `stacked-lines` block --- the **badged save advantages**
  first (they sit closest to the saves they annotate), then the **damage
  responses** (one plain-text line per kind ---
  `Resistance: Fire, Cold`), then the **senses** (each = the sense
  name + its range in plain body text) --- the last two carry *no*
  marker glyph (neither proficiency nor tracking) --- rendered *beneath
  the saves* under a "Defenses & Senses" header shown **only when there
  are senses, resistances, or advantages**: the card's bottom footer is
  a two-column split --- the box on the left, proficiency training
  (Armor/Weapons/Tools/Languages) on the right. **Both columns are
  headed by a `_foot-head` eyebrow** (`card.typ`: DEFENSES & SENSES /
  TRAINING & PROFICIENCIES) --- bold + `tracking: 0.6pt` accent,
  mirroring the letter's `_framed-title`, so the header out-ranks the
  plainer item labels beneath it. The per-line `_prof-line` labels
  (ARMOR:/WEAPONS:/...) sit a step down --- **regular weight, a touch
  smaller (5pt), still accent** --- the tier-2/tier-1 distinction is
  weight+tracking+size, **never colour** (no greyed/muted labels;
  everything in this footer is accent or ink). Every such tiny accent
  Montserrat label (footer heads, proficiency-line labels, spellcasting
  source names, the resource tracker's headers/derivation labels, the
  feature lists' source-group headers and per-line tags, the letter's
  labelled blocks) routes through**
  `eyebrow(body, size:, weight:, tracking:)` **(`common.typ`) --- it
  names the shared font+accent+uppercase; each site keeps its own
  size/weight/tracking, preserving the tier distinctions. The letter
  puts the same data in a framed** Defenses & Senses\*\* box at the
  bottom of the left ability-rail column. Size the badge to roughly the
  surrounding capital height (≈`0.85·size`).
- **The passive feature lists group by source.** The card deck's one
  **Features & Traits** section (which opens the **Features & Traits**
  card, its own card set after Spells) and the letter's **Class
  Features** / **Species Traits** boxes partition their items with
  `trait-groups` (`common.typ`): species → each class in declaration
  order (a `subclass-feature` folds into its class's group via its
  stamped `class-source`, tagged with the subclass name) → **Eldritch
  Invocations** (keyed off `kind: "invocation"`) → **Feats** (card only
  --- the letter keeps its own Feats box) → **Magic Items**, ties broken
  by first occurrence, items in declaration order. Each group renders
  under a tiny eyebrow sub-header (the resource tables' SHORT REST /
  LONG REST vocabulary; `size * 0.72`, `tracking: 0.6pt`) --- a lone
  group **still shows its header** (it *is* the source info). Per-line
  tags come from `feature-tags`: the subclass name on a subclass
  feature; a feat's 2024 category (ORIGIN / FIGHTING STYLE --- General
  untagged) plus its granter's name when the granter is a chosen/notable
  feature (`via-kind` not background/class/class-feature --- so Tough
  reads "ORIGIN · LESSONS OF THE FIRST ONES" but a background-granted
  feat shows only ORIGIN). `feature-item` renders tags as an eyebrow
  sized well under the line (`size * 0.62`) with **no leading middot**
  (the size drop already sets the tag off from the name; a middot only
  *separates* multiple tags), so tagged and untagged rows keep identical
  height. Rendering goes through
  `grouped-feature-lines`/`grouped-feature-box` (`common.typ`): on the
  card (`keep-items`) each group header rides its first item's
  keep-together block --- the section head binds into the *first*
  group's header the same way --- so no header ever orphans at a card
  foot; on the letter each header is a sticky block (`sticky-head`).
  Groups are separated by the `group-gap` token (1.1em --- wider than
  `row-gap`, narrower than a between-section gap). On the card the feats
  are the **Feats subsection** (before Magic Items); on the letter the
  **Feats box** stays flat (tags only). The Action/Bonus
  Action/Reaction/Other tables and the resource tables deliberately
  carry **no** source info --- a row's group/source is looked up in
  Features & Traits. `trait-group-of`/`trait-groups`/ `feature-tags` are
  shared predicates; the partition into boxes stays per-layout (the
  resolver-note rule).
- **One entry per feature: a sub-ability renders inside its granter's
  entry, never beside it.** These lists enumerate *features* --- a magic
  item, a feat, a trait, a class feature earns exactly one line --- so
  the parent/child split that models a differently-activated sub-ability
  (Regain Pact Slot under the Rod of the Pact Keeper, Telekinetic Shove
  under Telekinetic, Enhanced Dual Wielding under Dual Wielder, Emerge
  under Shell Defense, Divine Spark / Turn Undead under Channel
  Divinity) must not read as two peer features: the Rod listing itself
  twice under MAGIC ITEMS is the bug this rule exists to prevent.
  `_fold-sub-features` (`common.typ`) folds each child into its granter's
  entry as `subs`, matching the resolver's `via-name` against the entries
  of that same list, and `feature-item` renders those on their own
  `pad(left: 1em)` lines beneath the parent at the wrapped-line rhythm
  (`dense-leading`, so the entry reads as one unit against the wider
  `row-gap` between entries) with the **granter tag dropped** --- the
  line it sits under *is* the granter. It lives in **`feature-lines`**,
  the one function every feature list (grouped or flat, both layouts)
  goes through, so the rule holds everywhere by construction. A child
  whose granter is *not* an entry of the same list stays top-level and
  keeps its tag --- a granter with no `desc` (a class container, the
  Spellcasting sub-feature, the Eldritch Invocations container), or one
  grouped elsewhere (Tough, granted by an invocation, sits in the Feats
  group while Lessons of the First Ones sits in Eldritch Invocations).
  The fold is one level deep: a grandchild of a folded child stays
  top-level, no catalog having one. Nothing is hidden --- the full `desc`
  of every sub-ability still shows here, per the
  Features-&-Traits-shows-everything rule --- and the action tables and
  resource tracker are unaffected, since they key off `activation` and
  `eff-limited-use`, not this list.
- **Dice and signed modifiers render in math mode --- LaTeX look. Each
  is written *explicitly*, never scanned out of prose.** Two
  sources: (a) authored prose --- spell `notes`/`scaling`/`trigger`,
  trait/feat/subclass `desc` --- is **markup content** (`[…]`, *not*
  strings; see the descriptive-fields note below) and writes dice/mods
  as inline math: `$+1d 6$`, `$+5$`, `$2d 4 + 4$`. **Space the die
  letter** (`1d 6`, not `1d6`) --- Typst reads a glued `d6` as one
  multi-letter identifier and *errors* (its own hint: `try d 6`). (b)
  **An expression sets tight** --- `1d6+4`, `1d6−1` --- so a die and its
  modifier read as one token (see `math-styled` below). **Every operator
  inside `$…$` therefore needs both of its operands**: an operator whose
  right-hand operand is a prose word belongs to the prose, outside the
  math (`$1d 6$ + your Strength modifier`, `AC $12$ + slot`), or it hugs
  the left term and floats before a word space.
  Structured/computed cells call
  `fmt-mod`/`fmt-dice`/`fmt-spell-damage`/`fmt-save` at the call site
  (mod circles, PB, proficient saves, attack bonus, the DAMAGE·EFFECT
  damage, a save-DC cell). `fmt-save(save, dc)` renders
  `[#upper(save) $#dc$]` --- the ability abbreviation followed by the
  mathified DC --- and is the *one* save-DC display site, shared by the
  spell table's HIT/SAVE column and the Cunning Strike table's SAVE
  column, so a save reads identically everywhere it appears; a new
  save-DC cell should call it rather than re-composing the
  abbreviation+DC pair inline. The **only** global rule is
  `show math.equation: math-styled` --- there is **no**
  prose-scanning show-rule; descriptions carry their own math. Math
  renders in the **Euler Math** OpenType font (`math-font`,
  `common.typ`; provided by the flake via
  `pkgs.texlivePackages.euler-math` --- a real math font, so *no* "font
  not designed for math" warning). Do **not** re-add
  `show math.equation: set text(font: body-font)` --- that override is a
  non-math font and triggers the warnings. `math-styled` carries the
  font **and the operator spacing**: nested `show "+"` /
  `show sym.minus` rules re-class both operators as `"normal"`, which
  drops math's binary spacing so every expression --- authored or
  computed --- sets tight. Typst normalises a source `-` to
  `sym.minus`, so the rule matches that codepoint, not the ASCII
  hyphen. Both channels go through the one rule, which is why a
  computed damage string and the dice in a spell's `notes` read alike.
  - **The bold-synthesis is the subtle part** (`_math-num`, called by
    `fmt-mod`/`fmt-dice`). Euler ships a single weight --- its glyphs
    ignore `text(weight:)` and `math.bold` --- so bold stat values (mod
    circles, PB, proficient saves) would drop to regular next to the
    bold ETBembo scores/HP/speed. We synthesise weight with **cuti's
    stroke-based fake bold** (`@preview/cuti:0.4.0`, provided by the
    flake --- see the fonts/deps note above). Three traps: (1) a
    `math.equation` does **not** inherit the surrounding `text(weight:)`
    into its own context, so detecting bold inside a
    `show math.equation` handler **always reads regular** --- the
    `context` that reads `text.weight` must live at *construction*
    (`_math-num`), where the value sits in the cell inside
    `text(weight: "bold")`; `_math-num` reads that weight and only then
    applies fake bold. (2) A `set text(stroke:)` inside a show handler
    does **not** restyle the already-realised equation; cuti *wraps*
    it. (3) Stroking the **whole** equation makes the `+`/`−` sign
    blobby --- a thin uniform glyph takes an outline badly --- so
    `_math-num` uses cuti's
    **`regex-fakebold(reg-exp: "[0-9A-Za-z]+", …)`** to stroke **only
    the alnum runs** (digits and the die `d`), leaving the operators'
    glyphs and math spacing (the binary `+` in `1d6 + 2d6`) untouched.
  - The structured cells feed `_math-num` directly (`fmt-mod` builds
    `"+3"`/`"-1"`; `fmt-dice` normalises the unicode minus to ASCII and
    spaces out the die `d` so a glued `d8` isn't one unknown identifier;
    `fmt-spell-damage(dice, type:, label:)` mathifies the dice and
    appends the type/label upright). The save-DC number stays raw math
    (`[#upper(s.save) $#s.save-dc$]`, the placard's `$#s.save-dc$`) ---
    it only needs the font from `math-styled`, no bold. The **resolver
    emits only plain strings** (dice like `"3d10"`, mods like `"+5"`)
    --- this is the invariant that keeps the engine testable
    (`tests/resolve-test.typ` asserts them) and presentation-free;
    **only display wraps them** in math. That's why prose descriptions
    carry their *own* `$…$` (they're authored content, not resolver
    output) while computed dice go through `fmt-*` --- same LaTeX look,
    opposite sides of the data/render boundary. Authored prose in `$…$`
    is regular weight, so it only needs `math-styled`'s font; the bold
    synthesis is for the structured `fmt-*` sites.
  - **Unsigned bare numbers render in Euler too --- but via font
    `covers`, not the show-rule.** `body-font` is a font *list*:
    `((name: math-font, covers: regex("[0-9]")), text-font)`, so digits
    are drawn from Euler and everything else from ETBembo
    (`text-font` --- the plain family, named beside `math-font`/`label-font`
    so a site that must opt back out of the covers can say so). Because
    `body-font` is used only as a `font:` argument, this one definition
    (`common.typ`) reaches the base `set text` **and** every per-cell
    `text(font: body-font)`, so bare numbers everywhere --- scores, AC,
    HP, speed, passives, ranges like `80/320 ft`, digits in prose ---
    match the math figures with **no** regex, `eval`, or per-site call.
    (*Signed*/dice tokens instead go through explicit `$…$` markup or
    `fmt-*`, for the sign glyph and math spacing.) Euler is
    single-weight, so bold bare numbers need faked weight: `bold-num(n)`
    (`common.typ`, next to `fmt-mod`) applies cuti's `fakebold` with the
    same em-relative stroke --- no alnum split, since a bare number has
    no sign to go blobby. Euler is also **single-style**, so a digit
    inside `emph` stays upright — a covered digit cannot be italicized at
    all. Where the italic is the point (`spell-action-note`'s level
    marker), wrap the digit in `text(font: text-font)` to opt out of the
    covers and take ETBembo's real italic face, which sets it as an
    old-style figure. Apply `bold-num` at the prominent bold-number sites:
    the number-box primitives (`ability-cell`, `_score-box`,
    `_header-number-box`, `hp-box`, `hit-dice-box`, `coins-box`) render
    `bold-num(value)` directly; `stat-cell`/`stat-box` branch on
    `type(value) == int` so pure integers get `bold-num` and
    already-styled content (a `fmt-mod`, a size string, a `checkbox`)
    passes through the real-`weight` wrapper; mixed cells (the speed
    `NN ft`, card `hp-cell`) call `bold-num` on just the digit. The
    placard's `_pl-group` stats stay regular-weight (Euler regular);
    label-font (Montserrat) digits are left as-is.
- **Informational glyphs are drawn, not unicode.** The spell table's
  area-of-effect shapes (`_aoe-icon(shape, s)` ---
  square/cube/circle/sphere/cylinder/line/cone) and the duration
  `_clock-icon` are small line-art icons drawn with Typst primitives
  (`common.typ`), because the sheet fonts (ETBembo/ Montserrat) don't
  carry the geometric/emoji glyphs and they must scale with the text.
  Add new glyphs the same way; don't paste a codepoint. (`_scaling-mark`
  --- the filled ▲ before a spell's `scaling` prose --- is drawn the
  same way; it *is* a notation marker, a deliberate fourth shape outside
  the circle/diamond/hexagon vocabulary, see that note.) The spell table
  columns are SPELL (an `auto` column, so it grows to the widest name
  --- but the name cell **caps its width at `size * 9.2` (≈9.2em)**:
  past that a long name wraps rather than widening the column and
  squeezing the rest. `context measure` inherits the cell size, so the
  test is width-in-em --- `Dissonant Whispers` (\~8em) stays one line,
  `Tasha’s Hideous Laughter` (\~10.4em) breaks) / RANGE (range +
  `«glyph» size` AoE) / HIT·SAVE (`+5` attack or `WIS 14` save;
  **centered**) / COMP (V·S·M, but a costly material shows as `M$` when
  `material-cost: true`) / DAMAGE·EFFECT (casting time if not an Action
  --- a Reaction folds its trigger in as `Reaction: <trigger>` •
  Concentration/Ritual tags • notes, then `«clock» duration` (unless
  Instantaneous/1 round) hanging off the end with **no** bullet --- the
  clock icon is separator enough --- then, last of all, the per-slot
  upcast `scaling` prose behind a filled `«▲»` marker (`_scaling-mark`,
  also no bullet --- the triangle is separator enough). For a fixed-slot
  cast the ▲ is dropped and the per-slot prose is replaced by a computed
  effect (the spell's `at-level` function) --- bullet-joined, shown only
  when the fixed slot exceeds the spell's base level, omitted entirely
  otherwise (see the `spell.*` scaling note). The casting time and the
  Concentration/Ritual tags are *italicized* (for a Reaction only the
  `Reaction:` label, not the trigger); the earlier parts join on a plain
  **black** bullet `•` (not a muted/grey one). A cell that would
  otherwise be empty (no HIT/SAVE, no components, no damage/effect;
  likewise an attack's empty Notes / a spell's rangeless RANGE) renders
  an em-dash `—` rather than blank.
- **Tabular rhythm --- never hand-roll a `table()` or a `stack()` of
  wrapping items.** Every sheet table goes through
  `sheet-table(columns, headers, rows, align:, size:)` and every stacked
  wrapping list (feature "name --- desc" lists, bullet inventories,
  proficiency lines) through `stacked-lines(items)`, both in
  `common.typ`. They exist to enforce one invariant in one place: the
  gap *between* rows/items must exceed the leading *between wrapped
  lines within* a row/item, or a wrapping cell reads with looser spacing
  than the rows (structure inverted). `sheet-table` also owns the **cell
  text style**: it `set text(font: body-font, size:)` so every body cell
  reads in the body font at the shared `size` --- pass plain content per
  cell (not `text(font: body-font, size: …)[…]`) and reach for
  `text(weight:)`/ `emph` only for genuine emphasis, so per-cell styling
  can't silently diverge (e.g. into a bold HIT or a grey NOTES column).
  The rhythm is three `em`-relative tokens next to `section-gap` ---
  `dense-leading` / `row-inset` / `row-gap` --- so gaps scale with font
  size (tight on the 8pt cards, roomier on the 9.5pt letter) and the
  invariant holds by construction. `em` handles the *font-relative*
  gaps; every other absolute length goes through the design unit `u`
  (see the design-unit convention). Adding a new table or list means
  calling these, not passing your own
  `inset`/`stroke`/`spacing`/`leading`. `sheet-table` wraps its
  `table()` in `block(width: 100%, spacing: 0pt, …)` --- a bare
  `table()` placed in flow otherwise carries Typst's own default block
  spacing on top of whatever explicit gap a caller places around it,
  which silently *doubles* `v(section-gap)` wherever two sheet-tables
  sit back to back (attack-table -\> Cunning Strike table) while a spot
  already inside a zero-spacing block (a `feature-box` heading) reads
  correctly --- a real, visibly cramped-vs-loose mismatch on the card
  deck, not merely a difference in which token a call site happens to
  use. `feature-box`/`keep-together` zero their own block spacing for
  the same reason; `sheet-table` does too, so every explicit gap around
  any sheet table is exact by construction rather than needing a
  per-call-site wrapper. `sheet-table(..., atomic-rows: true)` (threaded
  through `spell-table(..., atomic-rows: true)`) marks every body cell
  `breakable: false` so a page/card-spanning table breaks *between*
  rows, never mid-row --- used by **both** the letter's spell box
  **and** the card deck's spell table, so a spell that overflows a card
  bumps whole to the next card instead of splitting its DAMAGE/EFFECT
  mid-cell. On the cards it pairs with the whole-group `keep-groups`
  policy below (an intact group when it fits, an inter-row split when a
  group is taller than a card). A non-breakable row on a small region
  does not trigger Typst's one-row-per-page repeating-header quirk under
  `keep-groups` (verified on the dense casters). A flat list can also be
  partitioned into an **N-up grid** ---
  `stacked-lines-columns(items, columns:, column-gutter:)` --- for a
  long roster that reads better as a grid than a single tall column (the
  Gear card's Inventory). Unlike `columns()`-style snaking, it slices
  `items` into `columns` roughly-equal chunks up front (mirroring
  `_core-card`'s skills-grid slice pattern) and lays each chunk out as
  its own `stacked-lines` in a `grid` cell --- a real N-up grid even for
  a short list (no lopsided single populated column), and a
  card-overflow split lands at the same row in every column since the
  grid's one row breaks as a unit, rather than dumping a ragged tail
  into a single column on the continuation card.
- **Card overflow = whole-group bump, then split as a fallback.** When a
  fixed-size card's content overflows, each *unit* --- a spell
  level-group (`spell-table(..., keep-groups: true)`) or a feature item
  (`feature-box(..., keep-items: true)`) --- is wrapped in
  `keep-together` (`common.typ`): it bumps **intact** to the next card
  if it fits a card alone, and only **splits** when a single unit is
  taller than a whole card (else `breakable: false` would silently clip
  and lose rows --- Typst does not force-break it). Three traps
  `keep-together` handles: (1) it must
  `measure(box(width: region.width, body))` --- a bare `measure` lays a
  `1fr` column out at \~zero width and reports a wildly inflated height;
  (2) the unit must be a **direct flow child**
      (`spell-table`/`feature-lines` emit units with an explicit `v(…)`,
      never inside a `stack`) or `layout` reports a shrunken region and
      always splits; (3) it wraps the whole thing in an **outer
      `block(spacing: 0pt)`** --- the `context`/`layout` wrapper is
      itself a block whose default spacing otherwise stacks on the
      caller's `v(…)` and inflates lists. **A section heading must NEVER
      sit alone at a card/page foot.** There are two binding patterns,
      and the distinction is which one a site needs:

  - **`sticky-head(heading, body, gap: head-gap)`** (`common.typ`) ---
    the heading is a `block(sticky: true, above: 0pt, below: gap)`
    immediately followed by `body`. When `body` is one unit that can be
    *taller than a card* and must therefore split internally (a spell
    level-group's table, the Resources tracker, a `feature-box` list,
    the Gear Inventory grid), the heading is sticky, so Typst carries it
    to the next region *with the top of the body* instead of orphaning
    it. **A `stack` is not flow layout, so it ignores stickiness** --- a
    break can land right between the heading and the body, orphaning a
    lone `1ST LEVEL` at a card foot with its table on the next card; use
    `sticky-head`, not `stack`, here. `below: gap` reproduces the exact
    heading→body gap (the bodies carry zero surrounding spacing) and
    `above: 0pt` leaves the caller's `v(section-gap)` as the only space
    above. Used by `spell-table`'s level groups, the card resource
    tables, `feature-box` (non-`keep-items`), and the Gear Inventory.
  - **`keep-together(stack(spacing: head-gap, head, first-item))`** ---
    `feature-box(..., keep-items: true)` via
    `feature-lines(..., head: …)` binds the heading to *only its first
    item* in one `keep-together` unit (later items stay their own
    blocks). The heading bumps to the next card with at least its first
    line; a long list still splits between later items. This is safe
    because a heading + one feature line is never taller than a card (so
    the `keep-together` never has to split *that* unit and orphan the
    heading inside it) --- the pattern `sticky-head` supersedes only
    where the bound body can itself exceed a card. Either way, **never**
    use free-flow `head; v(head-gap); item`: the heading paragraph's own
    block spacing sneaks in on top of the `v()` and loosens the
    after-header gap.
- **Letter overflow = row-level break with a repeating,
  `(continued)`-tagged header.** The letter is a page-flow layout, so
  its long spell box just fills the page and continues onto the next ---
  but two things must survive the break, and both are opt-in flags on
  the shared components (`common.typ`). (1) The framed-box **title bar
  repeats**: `framed-box(..., repeat-header: true)` wraps the body in a
  single-column `table` whose `table.header` is the title bar (Typst
  repeats *only* a `table.header`, and **re-realises it per page** ---
  so a `context` inside it can read `here().page()`); it compares that
  against the box's start page (recovered by querying a marker dropped
  at the top of the body, under a label derived from the title via
  **`std.label`**, since this module's own `label` text helper shadows
  the built-in) to append an italic "(continued)" past the first page.
  The title styling lives in `_framed-title(title, continued:)`, shared
  with the non-repeat path. (2) Rows stay atomic via `atomic-rows` (see
  the tabular-rhythm note) so a spell never splits mid-row --- it bumps
  whole to the next page. The spell table's own **column header**
  already repeats (Typst default) and is left on. The page-1 **Class
  Features / Species Traits / Feats** boxes carry `repeat-header: true`
  too, so a trait- or feat-heavy build reads its overflow under a
  "(continued)" bar --- but they are **not** atomic: a feature list has
  no orphaned-cell hazard (unlike the spell table), so letting an entry
  split *fills* the column tail instead of bumping it whole, which is
  what keeps a dense build's core on the single page it gets. Only the
  letter's overflow-prone boxes need these flags; the cards use the
  whole-group `keep-together` policy above instead.
- **Letter page 1 packs into two macro-columns that must stay balanced
  --- the ability rail anchors the left.** The full-height ability rail
  (every skill listed) fixes the left column's height, so the right
  column carries the most stackable content: stat row, weapons, **Class
  Features, Species Traits, Feats**, each at the *full* right-column
  width (a half-width Species\|Feats sub-grid would wrap them twice as
  tall). Feats lands in the right column *below* species (not the left)
  because that's where the slack is; the feature boxes render at
  **8pt**. The inter-box gap (both this right column and the left
  column, the header row, page 2's boxes, and a table-to-table gap like
  attack-table -\> Cunning Strike table) is `letter-section-gap`
  (`common.typ`, currently 8pt) --- the one token every letter
  block-to-block transition routes through, so it holds by construction
  rather than by matching literals across pages. These metrics are why a
  Bugbear rogue (6 Phantom features + 7 Bugbear traits + 2 feats) still
  fits page 1. **The letter sheet is *not* a two-page document** ---
  only its core is fixed at one page. The hard `pagebreak()` after it
  starts the roleplay section, which then flows over as many pages as
  the spell tables and equipment need: 3 pages total for a level-2 druid
  (goro), 4 for a level-4 bard (elara), 7 for the level-10
  Fighter/Warlock (`template/main.typ`). That is by design and not a bug to chase
  --- the roleplay section is page-flow layout with `(continued)`-tagged
  repeating headers precisely so it can grow. What page-1 balance
  protects is narrower and still worth guarding: the core must fit its
  **one** page, because the `pagebreak()` means any spill lands alone on
  a near-empty page with the whole roleplay section pushed behind it.
  Adding tall page-1 content means re-checking that balance (render the
  densest character --- `template/main.typ`, the level-10
  Fighter/Warlock), not just trusting it to reflow.
  **The Weapons box renders at 8pt**, joining the feature boxes rather
  than the 8.5pt the roleplay pages use: the attack table's five columns
  leave its Notes column roughly 13 characters at this width, and at
  8.5pt nearly every weapon's properties wrap to a second line ---
  enough extra height, on a level-4 bard (elara), to push the Feats box
  off the page. Keep that in mind before widening any attack-table
  column: it is the *widest* attack table, not the longest sheet, that
  page 1 is short of.
- **The core card's top two rows are one tier of numbers ---
  `card-stat-size` (`common.typ`).** Each ability cell leads with its
  **score** at that size, the modifier set smaller beneath it;
  `stat-cell(..., big: true)` (AC, HP) and the card's own `hp-cell` read
  at the same size. The pair needs no SCORE/MOD labels (the letter's rail
  carries them): a modifier always shows its sign, a score never does.
  Size a new headline stat off the token (a `* u` multiple of the design
  unit), not a literal `pt`, or the rows drift out of tier and out of
  scale on the enlarged layouts.
- **One masthead for every card ---
  `_card-header(title, subtitle, note1, note2)`.** All cards (core and
  the spells/actions/gear section cards) render the *same* four-area
  header --- TITLE (character name, big, left) / SUBTITLE (small italic,
  left) / NOTE1 (small, top-right) / NOTE2 (small, right) --- so the
  masthead is **positionally identical across the deck** (do not give
  one card its own header --- an in-body title would sit at a different
  height than the section cards'). Core fills all four; the section
  cards fill TITLE + NOTE1 (the section name), the rest blank. **The
  core card splits identity between the two left/right stacks by what
  the fact is:** SUBTITLE carries what the character *plays as*
  (species · class) --- **`identity-line(c)`, the same line the placard
  packs** (`common.typ`), so the deck states a character's identity in
  one form: species, then one part per class, **subclass first and no
  parens** ("Orc · Fighter 1 · Great Old One Warlock 9"). The right
  stack holds the descriptive facts --- NOTE1 is `meta-line`
  (`common.typ`): size and creature type, then the background ("Small
  Humanoid · Sage"); NOTE2 pairs the alignment with the proficiency
  bonus ("True Neutral · PB +2"). Every one of those joins is the
  shared **`meta-sep`** token (`common.typ`), the one divider between
  peer identity facts. It is a **string**, so the placard can measure a
  joined line before it wraps (see the placard note). The two NOTE
  rows share one base text style, `set` in `_card-header` so each
  note styles only its own spans (the PB value, "(continued)"). It is
  drawn by the running page header (`_running-head`), reading a per-card
  metadata marker (`<card-marker>` carrying the four areas) queried by
  page counter (not `state`, so no first-page off-by-one); on a page
  past the card's start page it is a continuation, so **NOTE2 becomes
  "(continued)"** (NOTE1 keeps the section name). Because the header
  lives in the margin for *all* cards, the top margin is enlarged
  uniformly (one value) and moving the header out of every body ---
  including core's --- keeps it space-neutral; that top margin also sets
  how far the title sits from the page's top edge (header fills the
  region and `v(1fr)` bottom-aligns it, so shrinking the margin raises
  the title). Two spacing traps: (1) a content-sized header **top-aligns
  at the page edge and clips the caps** --- fill the region and push it
  down with `block(height: 100%)` + `v(1fr)` (a leading `v()` collapses;
  block inset / `top-edge` clamp don't help); (2) the gap *below* the
  header to the body is **`header-ascent`** (`_header-gap`), not
  anything in the body, or the body smushes up. SUBTITLE reserves its
  line even when blank (`hide`) so the TITLE height is constant. The
  column header repeats via `table.header`.
- **Page numbers ("n/m") count only the "real" pages of each layout, via
  a shared `page-number-footer(n, m)` (`common.typ`) right-aligned in
  the page's footer.** The letter sheet numbers straightforwardly ---
  every page counts (`counter(page).get()`/`.final()`). The card deck is
  choosier: the **placard, Gear, and Backstory cards are
  front-matter/flavor and stay un-numbered**; only Core, Actions,
  Spells, and Features & Traits (plus any continuation pages they spill
  onto) count. This means `n`/`m` can't come from the raw page counter
  --- `_card-marker` (`card.typ`) carries a `numbered: bool` (default
  `true`; `false` on the Gear/Backstory markers), and `_page-footer`
  derives each marker's **page range** (its own start page through the
  page before the *next* marker's start, or the document's last page for
  the final marker --- the same span the running masthead treats as
  "this card, including overflow") to sum numbered pages before/through
  the current one.
  - **`footer-descent` is a gap from the body, not from the physical
    page edge --- and it's easy to get the direction backwards.** The
    footer's layout region always extends down to the page's physical
    bottom edge regardless of `footer-descent`; the property only trims
    the region's *near* (body-side) edge. So a *larger* descent pushes
    content *closer* to the physical edge (this is what "lowered into
    the margin" means), the mirror image of `header-ascent` trimming the
    header region's *far* side. **Never `align(bottom, …)` inside a
    `block(height: 100%)` footer** --- that box's height is
    `margin.bottom - footer-descent` but its *bottom* is always the
    physical page edge, so bottom-aligning inside it pins the content to
    that edge no matter what `footer-descent` is, silently defeating the
    property. Bottom-aligning would clip the page number on a borderless
    card print (the printer's measured clip band --- right \~5.15mm,
    bottom \~2.25mm --- is recorded in the `card-sheet` margin comment).
    Instead, `page-number-footer` just `align(right, …)`s with no
    vertical alignment, so it naturally sits `footer-descent` below the
    body --- snug against the margin, comfortably inboard of the clip
    band. The card's bottom margin is tiny (0.21in total, only \~0.12in
    of it actually visible after the clip), so its `_footer-gap` is a
    near-zero `0.5pt`; the letter's generous 0.5in margin has no such
    constraint and just uses `6pt`.
  - **Watch the Typst line-continuation trap** hit while computing `n`:
    an expression split across lines
    (`let n = foo().sum(default: 0)\n  + bar`) does **not**
    auto-continue --- the `+ bar` on its own line parses as a *separate*
    bare statement, which silently becomes int output that then fails to
    join with later content (a `context` block's non-`let` lines all
    join, `none`-safe but not int-safe). Keep such expressions on one
    line. `.sum()` also needs `default: 0` --- an empty array has no
    default sum and errors. The trap has a **markup-level variant**: a
    top-level `#let f(x) = expr` ends its expression at the line break,
    so a method chain continued on the next line
    (`#let f(e) = e\n .filter(…)`) silently becomes `f = identity` +
    stray markup text --- *no error*, wrong value (leading-dot
    continuation only works inside code-mode parens/braces). Give a
    multi-line body a `{ … }` block.
- **A spell's school-synergy note (`spell-schools`, above) is a true
  page-bottom footer, but deliberately not a Typst `#footnote`.**
  `_spell-name-cell` (`common.typ`) marks a matching spell with a plain
  superscript symbol (from the same *, †, ‡, ... sequence Typst's own
  footnotes use, assigned once per table via `numbering("*", n)` --- no
  footnote counter involved) plus an invisible `<school-note-marker>`
  metadata anchor carrying the note's name and symbol.
  `school-notes-footer(size)` (`common.typ`) --- called from both
  `card.typ`'s `_page-footer` and the letter's `set page(footer: …)`,
  sharing the footer line with `page-number-footer` via a two-column
  grid (note left-aligned, page number right-aligned, exactly as before
  when there's no note) --- `query()`s every such anchor whose
  `location().page()` is the* current\* page, dedupes by name (several
  spells on one page can share a note), and renders it: the same "ask
  what's on this page once layout has settled" idiom `_running-head`/
  `_page-footer` already use for the card masthead, so it's answered
  only after layout is final rather than during any in-progress
  measurement. **This query-based indirection exists because a real
  `#footnote(...)` here is provably unsafe**: nested inside
  `spell-table`'s `keep-groups` per-level `keep-together` (the
  whole-group-bump mechanism --- see the card-overflow note), Typst's
  `measure()`/region-retry pass for a group that doesn't fit the current
  card at all and gets deferred whole to the next one can *realize* a
  footnote it lays out --- pinning the note to the page the retry ran on
  --- while the group's actual content (and the footnote's own marker)
  lands on the deferred page, splitting note from reference; on a
  still-tighter region it can drop the footnote's note entirely rather
  than overflow it. Both were reproduced directly (a level group forced
  to bump on a small-margin card) before landing on the query-based fix
  --- a bare `#footnote(...)` with **no** `counter(footnote).at(label)`
  dedup read turned out to place correctly even inside `keep-together`,
  but Typst can still starve it of footer space on a dense card, so it
  was dropped in favor of this mechanism, which owns its own footer
  placement outright rather than asking Typst's footnote engine to find
  room.
- **The placard (card #1) is the one card that does NOT use the running
  masthead** (`_placard-card`, `card.typ`). It's a foldable table-tent:
  the character `name` (accent faux-small-caps), `player` (ink italic),
  a rule, the identity line (`identity-parts`/`identity-line`,
  `common.typ` --- species, then one part per class, subclass first and
  no parens, on the shared `meta-sep` divider: "Orc · Fighter 1 · Great
  Old One Warlock 9"; the card masthead's SUBTITLE is the same line),
  and two stat groups
  (left AC/HP/PPer, right Initiative/Spell Attack/Spell DC --- the spell
  rows only when `c.spellcasting` is non-empty). It's emitted on its
  **own portrait 4×6 page** whose **top margin is set to the fold line
  (3in = half the 6in card)** so the body region *is* the card's lower
  half --- the content is guaranteed to sit below the fold and the blank
  upper half folds back to stand it up. It drops **no `<card-marker>`**
  and sets **`header: none`**, so `_running-head` renders nothing on it
  (and the core card's marker lands on page 2, unaffected). Inside it
  `set block(spacing: 0pt)`/`set par(spacing: 0pt)` so the only gaps are
  the explicit `v(…)`s (else Typst's block spacing stacks on them and
  balloons the space around the class line --- the same trap as
  `keep-together`). **The identity line packs its own lines** rather
  than wrapping: a `layout` measures each part against the region width
  and breaks at a divider when the next part would not fit, leaving the
  divider at the end of the broken line to mark it continued ("Orc ·
  Fighter 1 ·" / "Great Old One Warlock 9"). A break mid-part reads as
  two half-facts on a card whose whole job is a glance, and the line is
  the widest thing on the placard, so it is the one place worth
  measuring. Because ETBembo ships its small-caps face under the
  *same* family+style as the roman, `smallcaps()`/`smcp` is a **no-op**;
  use the `small-caps` helper (`common.typ`), a thin wrapper over
  **cuti's `fakesc`** that **synthesizes** the look ---
  originally-lowercase letters uppercased and rendered at 0.76em,
  capitals left tall.
- The card's proficiency icons (`common.typ`): empty ○ / half-filled 45°
  split (Jack of All Trades) / filled ● (proficient) / filled ring
  (expertise), all drawn at one size.
- When you change the engine, **add/extend assertions in
  `tests/resolve-test.typ`** and run them.
- After visual changes, render to PNG (poppler via nix) and look at it
  before claiming it works.

## Rules data source

**Never invent a rules number or a line of rules text.** Every value in
the catalogs traces to a published source, and a plausible-sounding
invention is the one class of bug the tests cannot catch.

The canonical reference is the **System Reference Document 5.2.1**,
available free under CC-BY-4.0 at https://www.dndbeyond.com/srd ---
armor AC, weapon and mastery properties, spells, feats, the four SRD
backgrounds (Acolyte, Criminal, Sage, Soldier), the nine SRD species,
and the six SRD subclasses all come from there. `NOTICE` records exactly
which of this repo's catalog entries are SRD and which are not.

Content **outside** the SRD (Tortle, Fairy, Bugbear, Aasimar; College of
Glamour, Phantom, Great Old One, Light Domain; Cunning Strike; the
Entertainer and Genie Touched backgrounds) is a fan restatement of the
2024 rulebooks
--- cite the rulebook and page when adding to it, and keep the wording
paraphrased rather than copied wholesale.

## Status / scope

Done: the effect/feature model with nested sub-features; full AC/ability
engine; derived stats (skills incl. expertise/JoAT/Reliable Talent +
ability-derived skill bonuses, saves, passives --- each passive raised by
`5` when the skill carries Advantage);
abilities/skills/tools/spells/weapons as objects; seed catalogs for
species (**every entry a function** --- incl. Tortle natural armor,
Fairy w/ species spellcasting, Bugbear, Aasimar w/ Celestial
Resistance/Light Bearer/Healing Hands/Celestial Revelation, Human w/
Skillful + Versatile, Elf w/ Elven Lineage, Dragonborn w/ Draconic
Ancestry + Breath Weapon), classes (incl. Bard, Cleric, Druid & Sorcerer
full casters --- the Cleric w/ Divine Order and a Channel Divinity pool
that its Divine Spark / Turn Undead children spend, thru L4 --- an
enriched Rogue with 2024 Cunning Strike, a Fighter with
Second Wind + Fighting Styles, a Warlock with Pact Magic + Contact
Patron + Eldritch Invocations, and multiclass support
incl. starting-class-only saves), subclasses (bard incl. 2024 College of
Glamour, rogue/Phantom, rogue/Assassin, warlock/Great Old One thru
L10, cleric/Light Domain thru L3), Eldritch
Invocations (`invocation.*`, count-validated against the level
progression, incl. Pact of the Tome / free-cast / feat-granting
invocations), backgrounds (Acolyte, Entertainer, Sage, Genie Touched, Criminal, +
`background.custom` for one-offs), items (incl. `magic-armor` +N, Cloak
of Protection w/ computed save bonus, Rod of the Pact Keeper w/ scoped
spellcasting bonus), weapons (incl. Finesse best-of-Str/Dex, by-name
martial proficiency, Pact of the Blade, `magic-weapon` +N), spells (with
rich metadata), feats (incl. a mechanical Tough); **computed max HP**
(the 5.5e fixed rule, `max-hp:` as the rolled-HP override); the
**authoring idioms** (`languages:`/`tools:` params, `asi()`, the
EQUIPPED/INVENTORY gear split with `carried()` for inert pack items ---
see the conventions note); **spellcasting v2** (class sources with
slots + per-spell detail); **attacks** (weapon attack bonus + damage);
the **themed index-card deck** (a foldable placard/table-tent + core /
actions / spells / features-&-traits / gear + an optional Backstory
card) and the **full letter sheet** (a one-page core plus a roleplay
section that flows over as many pages as it needs); display-only
`equipment`/`currency`/`backstory`; flake + tests; the card deck's
**Action/Bonus Action/Reaction/Other tables** surfacing activated
abilities alongside Features & Traits, not instead of it (card-deck only
--- both the letter sheet's Class Features/Species Traits/Feats boxes
and the card deck's Features & Traits list show every feature via `desc`
regardless of activation, per the card-partition note); the
**limited-use resource tables as the Actions card's tail** (two
side-by-side Short Rest / Long Rest `sheet-table`s of diamonds,
travelling together --- see `resource-tables`); **actionable spells
folded into those same card tables** (ATTACK / Bonus Action / Reaction),
routed by `casting-time` (see the resolver note above); **source-grouped
feature lists** (the card's Features & Traits section and the letter's
Class Features/Species Traits boxes partition by
species/class/invocations/magic-items under eyebrow sub-headers, with
subclass / feat-category / granter per-line tags --- see the
source-grouping note), with **Fighting Styles modeled as the feats they
are** (2024) and **Weapon Mastery surfaced** as a named class feature +
the italicized mastery property on attack lines; **advantage on a skill check**
(`eff-check-advantage`, stamped on the skill and badged on its own row
in both layouts --- the unconditional counterpart to the footnoted,
condition-scoped `eff-save-advantage`); **spell-school synergy
marking** (a feature's `spell-schools:` field --- Great Old One's
Psychic Spells, College of Glamour's Beguiling Magic ---
cross-referenced against every spell's `school` at layout time and
footnoted with a true page-bottom, query-based footer, not a
Typst-native footnote --- see the school-notes-footer note); **a
feat-granted spell that also casts with any spell slot the character
has** (Magic Initiate, Fey Touched --- `eff-spell-any-slot`, projected
into every other spellcasting source with slots regardless of how the
feat is attached to the character).

Not yet: broader catalogs, multiclass spell-slot tables, spell
preparation limits, conditional effects (e.g. Bracers of Defense
gating), input validation; letter-sheet Action/Bonus Action/Reaction
tables (the card deck has them, the letter doesn't yet). All extend via
new features without engine changes.

> Unofficial; not affiliated with Wizards of the Coast.
