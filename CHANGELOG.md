# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Because `@preview/dndist:<version>` is a hard contract for every consumer file, a breaking change to
the public API means a major version bump.

## [Unreleased]

### Added

- `feat.conjuration-adept(abil, casting-ability: auto)`: the table spells
  (Entangle → Conjure Elemental) join the slotted spellcasting sources once a
  slot of their level exists.
- `feat.war-caster(abil)`: `+1` to Int/Wis/Cha, Advantage on Constitution
  saves to maintain Concentration (Saving Throws footnote), and a nested
  Reactive Spell reaction.
- `eff-spell-any-slot(..., at-slot: n)`: gate a projected spell on the
  character having a slot of level `n`.
- `item.headband-of-intellect`, via the new `eff-ability` kind `min` (raise to
  at least a value, never lower).
- `spell.conjure-elemental`, `spell.beast-sense`.
- Dimension-based layout names: `6x4` (default card), `6x4L` (large card at 115%), `5x8` (portrait card), `5x8L` (portrait card at 115%), `8x5` (8in × 5in landscape at 125%), and `8.5x11` (letter sheet).
- A layout registry (`src/layout/layouts.typ`) and the design unit `u`: every
  layout is one entry (page geometry, scale, margin decomposition), and every
  absolute length in a layout is authored as a multiple of `u`, so one scalar
  rescales a whole sheet. At scale 1 the rendering is bit-identical to before.
- A `stowed(f)` gear marker: the feature stays live (effects, spell tables,
  attack lines) but lists under INVENTORY instead of EQUIPPED. Complements
  `carried(f)`, whose gear is fully inert.
- `item.spell-scrolls` is stowed, not equipped, and carries no `desc`: the
  scroll table on the Spells card is the reference, so the aggregate joins
  neither the Features & Traits Magic Items list nor EQUIPPED.
- `item.ring-of-spell-storing(..spells)`: each stored spell is a bare spell or
  `(spell: s, slot: N)` for an upcast one; the wearer is taken to be the
  original caster, so the wearer's casting numbers apply. Construction asserts levels 1–5 and the
  5-level capacity. Its spell table swaps the Charges column for Slot: the
  stored slot level plus a diamond to check off the single cast.
- Magic-item spell tables add the caster's spellcasting ability modifier where
  a spell does (Cure Wounds heals 2d8 + modifier), as class spell tables do.
- The Spell Scrolls table's Charges column is now Uses: one diamond per scroll
  held, to check off as each is cast.
- Archery Fighting Style (`class.fighter(fighting-style: "Archery")`): +2 to
  attack rolls with Ranged weapons, via the new `eff-ranged-attack-bonus`
  effect. A Thrown melee weapon gains nothing, and damage is unchanged.
- `monster(stat-notes: (ac: …, hp: …, init: …, speed: …))`: footnotes on a
  creature card's AC/HP/Init/Speed numbers. The Battle Familiar uses them for
  the Brute's AC and Hit Points and the Flyer's fly speed.

### Changed

- Monster cards hold one creature each, in two columns: a tinted stat panel
  (AC/HP/Init/Speed strip, ability table with saves, senses and other lines)
  beside Traits/Actions/Bonus Actions/Reactions under tapered rules. Each
  card scales its block (85%–140%) to fill the card. Two creatures no longer
  share a card.

## [1.0.0] — 2026-08-04

First public release.
