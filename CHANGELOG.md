# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Because `@preview/dndist:<version>` is a hard contract for every consumer file, a breaking change to
the public API means a major version bump.

## [Unreleased]

### Added

- Two new card layouts, selected like the others with `--input layout=…`:
  - `card-lg` — the same 4x6 stock as `card`, with the design scaled to 115%
    so the deck reads larger and runs longer.
  - `card-5x8` — 8in × 5in landscape stock at 125%, the same deck at a larger
    size (the printer clip for this stock still needs a test print; the
    registry entry lands with the design border alone, marked `TODO`).
- A layout registry (`src/layout/layouts.typ`) and the design unit `u`: every
  layout is one entry (page geometry, scale, margin decomposition), and every
  absolute length in a layout is authored as a multiple of `u`, so one scalar
  rescales a whole sheet. At scale 1 the rendering is bit-identical to before.

## [1.0.0] — 2026-08-04

First public release.
