# Contributing to dndist

The most useful contribution is **catalog entries** — a species, subclass, feat, spell, item, or
invocation that isn't modelled yet. The catalogs are seeds; they cover what the example characters
needed and no more.

## Getting set up

This repo is developed under Nix:

```sh
nix develop                       # bare `typst` finds the fonts and the package
nix flake check                   # engine assertions + render fixtures + template + contents
nix build                         # build the package itself
```

Inside the dev shell:

```sh
typst compile --root . tests/resolve-test.typ /tmp/t.pdf    # the engine assertions
typst-strict --root . tests/example.typ /tmp/e.pdf --input layout=card
```

`--root .` is required for `resolve-test.typ`, which reaches relatively into `../src/` for
unexported internals — that escapes its own directory. The dev shell exports `TYPST_ROOT` for the
same reason.

Without Nix, the fixtures in `tests/` import `@preview/dndist:1.0.0` like any consumer, so point
Typst at the committed `packages/` symlink and fetch the fonts:

```sh
perl fonts.pl
export TYPST_PACKAGE_PATH="$PWD/packages" TYPST_FONT_PATHS="$PWD/fonts"
typst compile --root . tests/resolve-test.typ /tmp/t.pdf
```

That symlink and `fonts.pl` are the whole non-Nix setup (see
[Quick start](README.md#quick-start)); the `bare-typst` and `font-pins` checks guard them. Re-pinning
a font means editing the hashes in `fonts.pl` **and** re-checking the layout, since column widths and
overflow decisions are calibrated to these exact faces. `nix flake check` remains the only thing that
proves a change green, so a non-Nix contribution is best confirmed in CI.

## The two rules that matter most

**1. Add rules as features that emit effects. Never special-case the resolver or a renderer.**

This is the project's central invariant and the entire reason the architecture holds. A species, a
magic item, and a feat all reach the sheet the same way: they build a `feature(...)` carrying a list
of tagged `eff-*` effects, and `resolve()` folds those effects into computed values without knowing
what produced them.

If you find yourself adding `if feature.name == "..."` to `resolve.typ` or a layout, stop — the
right fix is almost always a new effect kind, or an existing one you haven't found yet. A new effect
kind is a legitimate change; a special case is not.

**2. `git add` new files before running any `nix` command.**

A Nix flake only ever sees git-tracked files. An untracked new file fails evaluation with a
confusing "not tracked by Git" (or a file-not-found from inside the sandbox), and nothing about the
message points at the real cause. This bites everyone exactly once.

## Where things live

```
src/model.typ       character(), feature(), the eff-* constructors
src/resolve.typ     the engine: folds effects into computed values
src/features/       the catalogs — most contributions land here
src/layout/         common.typ (shared components), card.typ, letter.typ
tests/resolve-test.typ  engine assertions
```

`src/layout/common.typ` is by far the largest file (~1,400 lines) and is where most layout work
happens — the shared components, tables, icons, and rhythm tokens all live there.

## Conventions worth knowing before you write code

- **Game concepts are objects, reached through namespaces** — `ability.cha`, `skill.stealth`,
  `spell.fire-bolt`. Every effect that names one accepts the object *or* its string id; `id-of`
  normalizes. The exception is the ability-score dict, which is id-keyed because dict keys can't be
  objects.
- **Descriptive prose is markup content (`[…]`), not a string.** Trait/feat `desc`, spell `notes` and
  `scaling` — writing them as content gets you curled apostrophes and inline math. Identifiers, keys,
  and resolver-computed values stay strings.
- **Dice and signed modifiers render in math mode**, written explicitly — `$+1d 6$`, `$+5$`. Space
  the die letter (`1d 6`, not `1d6`): Typst reads a glued `d6` as one identifier and errors.
- **A namespace holding functions must be a module, not a dict** — `dict.fn(...)` parses as a method
  call and errors. This is why `item`, `class`, and `spell` are imported modules.
- **Never invent a rules number or a line of rules text.** Cite SRD 5.2.1 where it covers the entry;
  see `NOTICE` for what is and isn't SRD. A plausible-sounding invention is the one class of bug the
  tests cannot catch.
- **Marker vocabulary is fixed**: circles mark proficiency, diamonds mark resource tracking, a
  hexagon marks a conditional save advantage, a filled triangle marks upcast scaling, a superscript
  symbol is a footnote reference. Never mix them, and never use grey to establish hierarchy —
  the palette is accent and ink only, with weight, tracking, size, and case doing the work.

`CLAUDE.md` is the long-form architecture document. It is dense but it is where the hard-won layout
rationale is recorded — the `keep-together` measurement traps, why the footnotes are query-based
rather than native, why bold numbers are synthesized. Read the relevant section before fighting the
layout; the answer is usually already there.

## Testing and review

- **Engine changes need assertions.** Add them to `tests/resolve-test.typ` and run `nix flake check`.
  A failed `assert` fails the build — that is the whole mechanism.
- **Adding a file the package must ship?** Add it to `packageFileset` in `flake.nix`. The repo root
  is the package root, so that allow-list is the only thing scoping what gets published —
  `buildTypstPackage` ignores `typst.toml`'s `exclude`. The `package-contents` check will fail if
  something leaks in or goes missing, but it only knows the paths it was told about.
- **Layout changes need eyes.** Render the affected fixtures to PNG and actually look at them:

  ```sh
  nix build .#checks.$(nix eval --raw --impure --expr builtins.currentSystem).render
  nix shell nixpkgs#poppler-utils --command pdftoppm -png -r 150 result/example-card.pdf /tmp/example
  ```

  Check *every* affected page, not the first one. Look for clipping, smushed spacing, orphaned
  headings at a card foot, and rows split mid-cell.
- **For changes that shouldn't alter output** (a refactor, a file move), prove it: render every
  fixture × layout to PNG before and after, and compare checksums. They should be byte-identical.
- **A visible layout change dates the README screenshots.** Regenerate them from the repo root:

  ```sh
  nix run .#docs-images
  ```

  Both images come from `template/main.typ` — `docs/card-deck.png` is the core card (page 2; the
  placard is page 1) at 150 dpi, `docs/letter-sheet.png` is page 1 of the letter at 100 dpi. Those
  pages and resolutions live in `docs-images.pl` and nowhere else, so a regenerated image differs
  only where the layout did. Commit the result with the change that caused it.

## Releasing

The version appears in more places than you'd expect. When cutting a release, update all of them:

| where | what |
|---|---|
| `typst.toml` | `version = "…"` |
| `flake.nix` | `version = "…"` |
| `dndist.typ` | the doc comment's import line |
| `template/main.typ` | its `@preview/dndist:…` import |
| `tests/*.typ` | every `@preview/dndist:…` import |
| `README.md`, `CLAUDE.md` | documented import lines |
| `CHANGELOG.md` | a new entry |

`git grep '<old-version>'` should come back empty when you're done. Then tag `v<version>`.
