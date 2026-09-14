# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Because `@preview/dndist:<version>` is a hard contract for every consumer file, a breaking change to
the public API means a major version bump.

## [Unreleased]

### Added

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

## [1.0.0] — 2026-08-04

First public release.
