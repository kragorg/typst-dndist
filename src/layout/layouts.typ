// The layout registry: every layout named once, with its page geometry, its
// scale, and its margin decomposition. `dndist.typ` and `common.typ` both read
// it, so there is one list to extend.
//
// - `margin` is the **scale-1** margin for that paper: the printer clip plus
//   `card-border` below.
// - The 4x6 clips are the ones measured on the index-card stock: this printer
//   clips borderless 4x6 prints by ~1mm (left), ~5.15mm (right), ~1.05mm (top),
//   ~2.25mm (bottom). Each file margin = the desired printed margin + that
//   edge's clip. Re-measure with calibration.typ for a different printer.
// - A card layout's edge margin at scale `s` is
//   `margin.at(e) + card-border.at(e) * (s - 1)`: the printer clip stays fixed
//   (it is a physical property of the printer), and the design border grows
//   with the type it frames.
// - `fixed-scale` is the unit for the two fixed-composition cards (placard,
//   core card): they are tuned to fill a card exactly and only grow when the
//   card itself does.

// The white border the design wants around a card body, separate from the
// printer clip below. It is the part of a margin that belongs to the design,
// so it is the part that grows with `scale`.
#let card-border = (left: 0.12063in, right: 0.11724in, top: 0.53866in, bottom: 0.12142in)

#let layouts = (
  "card":     (kind: "card", scale: 1.00, fixed-scale: 1.00, width: 6in, height: 4in,
               margin: (left: 0.16in, right: 0.32in, top: 0.58in, bottom: 0.21in)),
  "card-lg":  (kind: "card", scale: 1.15, fixed-scale: 1.00, width: 6in, height: 4in,
               margin: (left: 0.16in, right: 0.32in, top: 0.58in, bottom: 0.21in)),
  // TODO (clip-5x8, open item): the 5x8 printer clip is a physical property of
  // the printer that only a test print reveals, so this margin cannot be
  // finished from the code — it is `clip + card-border`, and it lands with
  // `card-border` alone for now. Until the clip is measured, expect the first
  // 5x8 prints to truncate an edge. Ask the user to run:
  //   nix develop -c typst compile --input card=5x8 calibration.typ /tmp/cal-5x8.pdf
  // print it borderless at 100% on 5x8 stock, read the four clips off the
  // rulers as calibration.typ's header describes, and add them to this entry.
  "card-5x8": (kind: "card", scale: 1.25, fixed-scale: 1.25, width: 8in, height: 5in,
               margin: card-border),
  "letter":   (kind: "letter", scale: 1.00),
)

#let active-layout = sys.inputs.at("layout", default: "card")