# dndist

Define and render printable **D&D 5.5e** character sheets in [Typst](https://typst.app).

A character is declared as data plus a list of composable *features* (species, classes, items,
spells, feats). A resolver folds those features' effects into computed values — ability modifiers,
proficiency bonus, **Armor Class**, **maximum HP**, skills, saves, passives, attacks, spell slots —
and four layouts render the result: the themed **index-card deck** on three stocks — `card`
(4x6, dense 8pt type), `card-lg` (same 4x6 stock at 115% type, so the deck runs longer), and
`card-5x8` (8x5 stock at 125%, the same deck, bigger) — and a **full letter sheet**.

You never write a number the rules can derive.

<!-- Absolute URLs on purpose: docs/ is excluded from the published package (see
     packageFileset in flake.nix), so a relative src would 404 on Typst Universe,
     which renders this README from the package archive rather than from the repo. -->
<p align="center">
  <img src="https://raw.githubusercontent.com/kragorg/typst-dndist/main/docs/card-deck.png" alt="The core card from the index-card deck: ability scores with proficiency-marked saves, AC/HP/initiative/speed/passive perception, the full skill list, and defenses and proficiencies" width="720">
</p>
<p align="center">
  <img src="https://raw.githubusercontent.com/kragorg/typst-dndist/main/docs/letter-sheet.png" alt="The core page of the letter sheet: the ability rail, weapons and damage cantrips, and class features grouped by source" width="620">
</p>

## Quick start

**dndist is not on Typst Universe yet**, so you install it by cloning it. Setup is two things Typst
has to be pointed at: the clone's own `packages/` directory, which names the repo as
`@preview/dndist:1.0.0`, and the three fonts the sheet is calibrated to, which `fonts.pl` downloads
for you. Both are one-liners, and there is nothing after them.

```sh
git clone https://github.com/kragorg/typst-dndist
cd typst-dndist
perl fonts.pl                                 # downloads the three fonts into ./fonts
export TYPST_PACKAGE_PATH="$PWD/packages"     # put both in your shell rc to make them stick
export TYPST_FONT_PATHS="$PWD/fonts"
```

Now scaffold a character. The template is a fully-built level-10 multiclass character to edit down
from — it is easier to delete than to discover.

```sh
typst init @preview/dndist:1.0.0 ~/mychar
cd ~/mychar
typst compile --root . main.typ sheet.pdf --input layout=card
typst compile --root . main.typ sheet-5x8.pdf --input layout=card-5x8
typst compile --root . main.typ letter.pdf --input layout=letter
typst watch --root . main.typ
```

The layout is one of `card` (default), `card-lg`, `card-5x8`, or `letter` — one
character file renders every layout, with no per-file wiring.

That is the whole setup: [Typst](https://typst.app/docs/tutorial/installation/), a clone, one script,
two variables. The fonts are **not** vendored into this repository — `fonts.pl` downloads them into
`./fonts` (1.6 MB, ignored by git), each file pinned by sha256 to the exact build the Nix flake
renders with, so a clone cannot end up with a *different* cut of a family. It needs the network once,
as does the first compile, which fetches dndist's one dependency,
[cuti](https://typst.app/universe/package/cuti). After that everything is offline.

```sh
perl fonts.pl --check     # verify ./fonts against the pinned hashes
```

Skipping the fonts is the one failure worth knowing about: a missing family is only a *warning* to
Typst, which substitutes a face and hands you a plausible-looking, subtly wrong sheet — see
[Fonts](#fonts).

With [Nix](https://nixos.org) even that is unnecessary: `nix develop` gives you a `typst` that
already carries the package, its dependency, and all three fonts.

<details>
<summary><b>How that works, and how to install it permanently instead</b></summary>

Typst resolves `@<namespace>/<name>:<version>` from `<root>/<namespace>/<name>/<version>` on disk
before it reaches for the network, where `<root>` is `TYPST_PACKAGE_PATH` (or `--package-path`, or a
per-platform data directory). This repo commits exactly that shape, as one symlink:

```
packages/preview/dndist/1.0.0 -> ../../..
```

The `preview` namespace is deliberate — it is the name the package will have once published, so
`@preview/dndist:1.0.0`, the import in every file here and in everything `typst init` writes, resolves
unchanged both now and after publication. Nothing is copied and no import ever needs editing. It also
means the repo's own fixtures run against the clone: `typst compile --root . tests/example.typ /tmp/e.pdf`.

To avoid the environment variable, link the clone into Typst's own package directory once — then
`@preview/dndist:1.0.0` resolves from any project, in any shell:

```sh
# macOS
DEST="$HOME/Library/Application Support/typst/packages/preview/dndist"
# Linux
DEST="${XDG_DATA_HOME:-$HOME/.local/share}/typst/packages/preview/dndist"

mkdir -p "$DEST" && ln -s "$PWD" "$DEST/1.0.0"        # undo: rm "$DEST/1.0.0"
```

On Windows that directory is `%APPDATA%\typst\packages\preview\dndist\1.0.0`; copy the clone there, and
note that Git only checks out `packages/preview/dndist/1.0.0` as a real symlink when symlinks are
enabled (`git clone -c core.symlinks=true`), so the `TYPST_PACKAGE_PATH` route needs that first.

Either route registers the whole repo, tooling (`tests/`, `flake.nix`, the Perl scripts) included.
That is harmless — `dndist.typ` is the entrypoint and nothing else is reachable by import — but if you
want the exact published tree, `nix build` writes one to `result/lib/typst-packages/dndist/1.0.0`.

</details>

## Developing this package

With [Nix](https://nixos.org) (brings its own Typst, fonts, and dependencies):

```sh
nix flake check               # engine assertions + render fixtures + template + package contents
nix build                     # build the package itself
nix develop                   # dev shell: bare `typst` finds fonts + the package
```

Inside the dev shell:

```sh
typst compile --root . tests/resolve-test.typ /tmp/t.pdf    # the engine assertions
typst-strict --root . tests/example.typ /tmp/e.pdf --input layout=card
```

`--root .` is required for `tests/resolve-test.typ`: it reaches relatively into `../src/` for
unexported internals, which escapes its own directory. The dev shell exports `TYPST_ROOT` for the
same reason.

## Defining a character

```typ
#import "@preview/dndist:1.0.0": *

#let glory = character(
  name: "Glory",
  alignment: "CG",                 // LG NG CG LN NN CN LE NE CE
  abilities: (str: 9, dex: 16, con: 12, int: 10, wis: 10, cha: 18),
  features: (
    species.aasimar,
    background.entertainer(ability.cha, ability.dex),
    class.bard(
      level: 4,
      subclass: subclass.bard.glamour,
      skills: (skill.deception, skill.performance, skill.persuasion, skill.perception),
      expertise: (skill.persuasion, skill.perception),
      cantrips: (spell.vicious-mockery, spell.minor-illusion),
      spells: (spell.dissonant-whispers, spell.healing-word),
    ),
    item.studded-leather,
    item.shield,
  ),
  languages: ("Elvish", "Celestial"),   // Common is automatic; choose two more
)

#sheet(glory)                      // layout comes from --input layout=card|card-lg|card-5x8|letter
```

Every character file ends with a single `#sheet(char)`; the layout is chosen at the command line, so
one file renders both ways. `typst init @preview/dndist:1.0.0` (see [Quick start](#quick-start))
gives you a fully-built level-10 multiclass character to edit down from — it's easier to delete than
to discover.

A few authoring rules worth knowing up front:

- **`abilities:` holds base scores.** Backgrounds, feats, and `asi()` apply their own increases.
- **Max HP is computed** from hit dice + Con by the 5.5e fixed rule. Pass `max-hp:` only to override
  it with a rolled total.
- **Declaration order of classes matters** — the first is the starting class, which grants the
  saving-throw proficiencies and the maximum-roll first hit die.
- **Gear declared as a feature is equipped** and its effects are live (it lists under EQUIPPED).
  `carried(item.…)` puts a modelled item in the pack instead: inert, listed under INVENTORY.
  `equipment:` is for unmodelled kit only.
- **A Versatile weapon is wielded in one hand** unless you say otherwise.
  `two-handed(weapon.longsword)` rolls its bigger die instead; either way the attack line
  states what the other grip would deal.
- **Languages are a character-creation choice** in 2024 — Common plus two chosen. Species and
  standard backgrounds grant none.

## How it works

Declare → resolve → render:

- **`character(...)`** captures declared data (`name`, `abilities`, `features`, `languages`, …).
- **Features** (`species.*`, `class.*(...)`, `item.*`, `feat.*`, `invocation.*`) each contribute a
  list of tagged *effects* — ability changes, AC bases/formulas/bonuses, proficiencies, limited-use
  pools, weapons, spellcasting sources. Features nest, so a class carries its own sub-features and a
  subclass folds into its class.
- **`resolve(char)`** folds every effect into final values. The AC engine collects candidate bases
  (armor + capped Dex, or an alternate formula like Mage Armor or Unarmored Defense), takes the best,
  then adds flat bonuses.
- **`card-sheet` / `letter-sheet`** render with native Typst layout.

Adding a new rule — a species, subclass, item, feat, spell — means adding a feature that emits
effects. It never means special-casing the resolver or a renderer. That invariant is the whole
reason the architecture holds; see [CONTRIBUTING.md](CONTRIBUTING.md).

## Fonts

Three fonts are required, and the sheet is *calibrated* to them — this is not a cosmetic preference:

| font | role | license |
|---|---|---|
| **ETBembo** (ET Book) | body text | MIT |
| **Montserrat** | headings, labels, eyebrows | OFL 1.1 |
| **Euler Math** | all digits and math | OFL 1.1 |

Three mechanisms depend on their specific properties: bold numbers are *synthesized* because Euler
ships a single weight; small caps are *synthesized* because ETBembo hides its small-caps face under
the roman style; and column widths and card-overflow decisions are tuned to ETBembo's metrics.
Substituted fonts therefore produce a plausible-looking but subtly wrong sheet rather than an
obviously broken one — the worst failure mode, because nothing looks broken.

Typst by itself will not stop you: a missing family is a *warning*, after which it substitutes an
embedded font and exits 0. `--ignore-system-fonts` (which every render passes) prevents a stray
system font from quietly satisfying a family, but it does not make the fallback fail, and no CLI flag
does. So renders go through **`./typst-strict.pl`**, which fails the build if any family went
unresolved. The `render` and `template` checks use it, so `nix flake check` and CI inherit the
guarantee; call it directly (it's `typst-strict` on the dev shell's PATH) if you're driving Typst
yourself.

The Nix flake takes all three fonts from nixpkgs and wires them into a wrapped `typst` that also
hard-sets `TYPST_IGNORE_SYSTEM_FONTS`, so a host-installed face of a different version cannot quietly
satisfy a family. Outside Nix, `perl fonts.pl` downloads them into `./fonts` and you point
`TYPST_FONT_PATHS` there. **Neither path vendors fonts into the repository** — the downloads are
third-party binaries with their own upstreams, and `fonts.pl` keeps them honest by pinning every file
to a sha256, taken from the same revisions nixpkgs pins:

| family | source | files |
|---|---|---|
| ETBembo | `edwardtufte/et-book` @ `7e8f02d` | 5 faces (all that exist) |
| Montserrat | `JulietaUla/montserrat` @ `v9.000` | Regular, Medium, Bold — the weights the layout asks for |
| Euler Math | CTAN `fonts/euler-math` | `Euler-Math.otf` |

Those pins are what makes the two paths one path: the `font-pins` check hashes the flake's own font
files and fails the build if any pinned hash is not among them, so a nixpkgs bump surfaces as a red
build rather than as a newcomer silently rendering with a different cut of Montserrat. `perl fonts.pl
--check` verifies an existing `./fonts` the same way, and `fonts.pl` refuses a download whose hash
does not match rather than writing it.

## Layout

```
dndist.typ            public API (re-exports + feature namespaces)
src/model.typ         character(), feature(), the eff-* effect constructors
src/resolve.typ       the resolution / computation engine
src/data/             abilities, skills, tools, constants (armor table, …)
src/features/         species, classes, subclasses, invocations, backgrounds,
                      items, weapons, spells, feats
src/layout/           layouts.typ (the layout registry + design unit), shared
                      components, card deck, letter sheet
template/main.typ     what `typst init` gives you
tests/                resolve-test.typ (engine assertions) + render fixtures
packages/             one symlink naming this repo @preview/dndist:<version>
fonts.pl              downloads the three fonts into ./fonts, pinned by sha256
typst-strict.pl       `typst compile` that fails on a substituted font
flake.nix             the Nix build; packageFileset scopes what actually ships
```

The repo root *is* the package root, so the repo's own tooling sits beside what ships. What gets
published is scoped by the `packageFileset` allow-list in `flake.nix` — `buildTypstPackage` is a
plain `cp -r` and ignores `typst.toml`'s `exclude` — and the `package-contents` check fails the build
if anything leaks in or goes missing.

## Scope

Implemented: the effect/feature model with nested sub-features; the AC and ability engines; derived
stats (skills with expertise / Jack of All Trades / Reliable Talent, saves, passives); spellcasting
with slots, upcasting, and per-spell detail; weapon attacks with finesse, mastery, and Pact of the
Blade; limited-use resource tracking; multiclassing; computed max HP; all four layouts.

Not yet: multiclass spell-slot tables, spell preparation limits, conditional effects (e.g. Bracers
of Defense gating), input validation, and Action/Bonus Action/Reaction tables on the letter sheet
(the card deck has them). All of these extend through new features rather than engine changes.

The catalogs are seeds, not a complete rules implementation — they cover what the example characters
needed. Adding entries is the most useful contribution.

## Contributing

The most useful contribution is a **catalog entry** — a species, subclass, feat, spell, item, or
invocation that isn't modelled yet. The one rule that matters is that rules arrive as features
emitting effects, never as a special case in the resolver or a renderer. See
[CONTRIBUTING.md](CONTRIBUTING.md) for setup, conventions, and how to test a layout change.

Release history is in [CHANGELOG.md](CHANGELOG.md).

## License

Code is [MIT](LICENSE). Game content is a separate matter: some derives from the System Reference
Document 5.2.1 under CC-BY-4.0, and some is outside the SRD entirely. See [NOTICE](NOTICE), which
records exactly which is which.

> This work includes material from the System Reference Document 5.2.1 (“SRD 5.2.1”) by Wizards of
> the Coast LLC, available at https://www.dndbeyond.com/srd. The SRD 5.2.1 is licensed under the
> Creative Commons Attribution 4.0 International License, available at
> https://creativecommons.org/licenses/by/4.0/legalcode.

### If you share a rendered sheet

CC-BY attribution attaches to the material when it is *shared*, and **the renderers do not print an
attribution line** — a generated PDF carries SRD-derived text with nothing on it saying so. Keeping
the sheet to yourself and your table needs nothing. But if you publish, distribute, or otherwise
share a sheet dndist produced, include the attribution notice above alongside it. Reproducing the
blockquote verbatim is sufficient.

dndist is compatible with fifth edition. It is an unofficial, fan-made project, and is not approved,
endorsed, sponsored by, or affiliated with Wizards of the Coast LLC.
