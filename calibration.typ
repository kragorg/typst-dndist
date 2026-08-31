// calibration.typ — Printer margin & edge-clip calibration sheet.
//
// HOW TO USE THIS SHEET:
// 1. Compile the calibration PDF for 5"x8" (or other card sizes):
//      typst compile calibration.typ /tmp/cal-5x8.pdf
//    or specify the layout explicitly:
//      typst compile --input card=5x8 calibration.typ /tmp/cal-5x8.pdf
//      typst compile --input card=8x5 calibration.typ /tmp/cal-8x5.pdf
//      typst compile --input card=6x4 calibration.typ /tmp/cal-6x4.pdf
// 2. Print at 100% scale (Actual Size / Do NOT scale / Do NOT fit to printable area).
// 3. Print borderless if your printer supports it, or standard bordered.
// 4. Verify scale: measure the center calibration box with a physical ruler (50mm / 2.00 in).
// 5. Read the four edge clips off the rulers (the first visible tick mark at the paper edge).
// 6. Calculate the final margin for `src/layout/layouts.typ`:
//      margin = clip + card-border
//    where card-border = (left: 0.12063in, right: 0.11724in, top: 0.53866in, bottom: 0.12142in).

#let label-font = "Montserrat"
#let text-font = "ETBembo"
#let math-font = "Euler Math"

#let ink = rgb("#2b2b2b")
#let accent = rgb("#7a1f2b")
#let rule-color = rgb("#b8b0a8")
#let light-rule = rgb("#ded8d0")
#let faint-rule = rgb("#f2eee9")
#let highlight = rgb("#c84b31")
#let guide-blue = rgb("#2b5b84")
#let guide-green = rgb("#2d7d46")

#let card-border = (left: 0.12063in, right: 0.11724in, top: 0.53866in, bottom: 0.12142in)

// Known card sizes
#let card-sizes = (
  "5x8":  (width: 5in, height: 8in, name: "5\" x 8\" (Portrait)"),
  "5x8L": (width: 5in, height: 8in, name: "5\" x 8\" Large (Portrait)"),
  "8x5":  (width: 8in, height: 5in, name: "8\" x 5\" (Landscape)"),
  "6x4":  (width: 6in, height: 4in, name: "6\" x 4\" (Landscape)"),
  "6x4L": (width: 6in, height: 4in, name: "6\" x 4\" Large (Landscape)"),
  "4x6":  (width: 4in, height: 6in, name: "4\" x 6\" (Portrait)"),
)

#let input-card = sys.inputs.at("card", default: sys.inputs.at("layout", default: "auto"))

#let blank(w) = box(stroke: (bottom: 0.6pt + ink), width: w, [])

// Draw calibration page for a specific width and height
#let calibration-page(w, h, title, subtitle) = {
  set page(
    width: w,
    height: h,
    margin: 0pt,
    fill: white,
  )
  set text(font: label-font, fill: ink)

  // Full-bleed outer bounding border (x=0, y=0 to x=w, y=h)
  place(top + left, rect(width: w, height: h, stroke: 0.75pt + ink, fill: none))

  // Corner diagonal ticks (45 degrees) for corner clip / skew checking
  for d in (1mm, 2mm, 3mm, 4mm, 5mm, 10mm, 15mm, 20mm) {
    let strk = if d == 5mm or d == 10mm { 0.5pt + highlight } else { 0.25pt + light-rule }
    place(top + left, line(start: (d, 0pt), end: (0pt, d), stroke: strk))
    place(top + left, line(start: (w - d, 0pt), end: (w, d), stroke: strk))
    place(top + left, line(start: (0pt, h - d), end: (d, h), stroke: strk))
    place(top + left, line(start: (w - d, h), end: (w, h - d), stroke: strk))
  }

  // Reference full-span grid lines near edges (1mm to 25mm)
  for d in (1mm, 2mm, 3mm, 4mm, 5mm, 10mm, 15mm, 20mm, 25mm) {
    let strk = if d == 5mm or d == 10mm or d == 20mm { 0.35pt + rule-color } else { 0.15pt + faint-rule }
    place(top + left, line(start: (0pt, d), end: (w, d), stroke: strk))
    place(top + left, line(start: (0pt, h - d), end: (w, h - d), stroke: strk))
    place(top + left, line(start: (d, 0pt), end: (d, h), stroke: strk))
    place(top + left, line(start: (w - d, 0pt), end: (w - d, h), stroke: strk))
  }

  // Inch reference lines (0.125", 0.25", 0.5", 0.75", 1.0")
  for in-val in (0.125in, 0.25in, 0.5in, 0.75in, 1.0in) {
    let strk = 0.25pt + rgb("#d8e0e8")
    place(top + left, line(start: (0pt, in-val), end: (w, in-val), stroke: strk))
    place(top + left, line(start: (0pt, h - in-val), end: (w, h - in-val), stroke: strk))
    place(top + left, line(start: (in-val, 0pt), end: (in-val, h), stroke: strk))
    place(top + left, line(start: (w - in-val, 0pt), end: (w - in-val, h), stroke: strk))
  }

  // CONTINUOUS EDGE TICKS around the entire perimeter (every 1mm, 5mm, 10mm)
  let total-mm-x = int(w / 1mm)
  for mm-x in range(0, total-mm-x + 1) {
    let x = mm-x * 1mm
    if x <= w {
      let t-len = if calc.rem(mm-x, 10) == 0 { 6pt } else if calc.rem(mm-x, 5) == 0 { 4pt } else { 2pt }
      let strk = if calc.rem(mm-x, 10) == 0 { 0.5pt + ink } else if calc.rem(mm-x, 5) == 0 { 0.35pt + accent } else { 0.2pt + light-rule }
      place(top + left, dx: x, dy: 0pt, line(angle: 90deg, length: t-len, stroke: strk))
      place(top + left, dx: x, dy: h - t-len, line(angle: 90deg, length: t-len, stroke: strk))
    }
  }
  let total-mm-y = int(h / 1mm)
  for mm-y in range(0, total-mm-y + 1) {
    let y = mm-y * 1mm
    if y <= h {
      let t-len = if calc.rem(mm-y, 10) == 0 { 6pt } else if calc.rem(mm-y, 5) == 0 { 4pt } else { 2pt }
      let strk = if calc.rem(mm-y, 10) == 0 { 0.5pt + ink } else if calc.rem(mm-y, 5) == 0 { 0.35pt + accent } else { 0.2pt + light-rule }
      place(top + left, dx: 0pt, dy: y, line(length: t-len, stroke: strk))
      place(top + left, dx: w - t-len, dy: y, line(length: t-len, stroke: strk))
    }
  }

  // Theoretical design area (card-border)
  let cb-x = card-border.left
  let cb-y = card-border.top
  let cb-w = w - card-border.left - card-border.right
  let cb-h = h - card-border.top - card-border.bottom
  place(top + left, dx: cb-x, dy: cb-y,
    rect(
      width: cb-w,
      height: cb-h,
      stroke: (dash: "densely-dashed", thickness: 0.75pt, paint: guide-blue),
      fill: none,
    )
  )
  place(top + center, dy: cb-y + 2pt,
    box(
      fill: white,
      stroke: 0.4pt + guide-blue,
      radius: 1.5pt,
      inset: (x: 4pt, y: 1.5pt),
      text(size: 4.2pt, fill: guide-blue, weight: "bold")[
        DESIGN BORDER (card-border: L=0.121 in, R=0.117 in, T=0.539 in, B=0.121 in)
      ]
    )
  )

  let is-portrait = h > w
  let h-stations = (w * 0.22, w * 0.78)
  let v-stations = if is-portrait { (h * 0.22, h * 0.5, h * 0.78) } else { (h * 0.35, h * 0.65) }
  
  // TOP RULER (y = 0 to 25mm)
  for sx in h-stations {
    for mm-val in range(0, 26) {
      let y = mm-val * 1mm
      let tick-len = if calc.rem(mm-val, 10) == 0 { 16pt } else if calc.rem(mm-val, 5) == 0 { 11pt } else { 6pt }
      let strk = if calc.rem(mm-val, 10) == 0 { 0.6pt + ink } else if calc.rem(mm-val, 5) == 0 { 0.45pt + accent } else { 0.25pt + ink }
      place(top + left, dx: sx - tick-len / 2, dy: y, line(length: tick-len, stroke: strk))
      
      if mm-val < 25 {
        let half-y = y + 0.5mm
        place(top + left, dx: sx - 3pt, dy: half-y, line(length: 6pt, stroke: 0.15pt + rule-color))
      }

      if mm-val > 0 and mm-val <= 10 {
        let is-even = calc.rem(mm-val, 2) == 0
        let lx = if is-even { sx + tick-len / 2 + 1.5pt } else { sx - tick-len / 2 - 6.5pt }
        let txt-color = if calc.rem(mm-val, 5) == 0 { accent } else { ink }
        let txt-weight = if calc.rem(mm-val, 5) == 0 { "bold" } else { "regular" }
        place(top + left, dx: lx, dy: y - 2.5pt,
          text(size: 4.2pt, fill: txt-color, weight: txt-weight)[#mm-val]
        )
      } else if mm-val > 10 and calc.rem(mm-val, 5) == 0 {
        place(top + left, dx: sx + tick-len / 2 + 1.5pt, dy: y - 2.5pt,
          text(size: 4.5pt, fill: accent, weight: "bold")[#mm-val]
        )
      }
    }
    for (i-val, label-txt) in (
      (0.125in, "1/8"), (0.25in, "1/4"), (0.375in, "3/8"), (0.5in, "1/2"),
      (0.625in, "5/8"), (0.75in, "3/4"), (0.875in, "7/8"), (1.0in, "1\"")
    ) {
      let strk = if i-val == 0.5in or i-val == 1.0in { 0.5pt + guide-blue } else { 0.3pt + guide-blue }
      place(top + left, dx: sx + 10pt, dy: i-val, line(length: 7pt, stroke: strk))
      place(top + left, dx: sx + 18pt, dy: i-val - 2.5pt, text(size: 3.8pt, fill: guide-blue)[#label-txt])
    }
    place(top + left, dx: sx - 8pt, dy: 25mm + 1.5pt, text(size: 4.2pt, fill: accent, weight: "bold")[mm (TOP)])
  }

  // BOTTOM RULER (y = h - 25mm to h)
  for sx in h-stations {
    for mm-val in range(0, 26) {
      let y = h - (mm-val * 1mm)
      let tick-len = if calc.rem(mm-val, 10) == 0 { 16pt } else if calc.rem(mm-val, 5) == 0 { 11pt } else { 6pt }
      let strk = if calc.rem(mm-val, 10) == 0 { 0.6pt + ink } else if calc.rem(mm-val, 5) == 0 { 0.45pt + accent } else { 0.25pt + ink }
      place(top + left, dx: sx - tick-len / 2, dy: y, line(length: tick-len, stroke: strk))
      
      if mm-val < 25 {
        let half-y = y - 0.5mm
        place(top + left, dx: sx - 3pt, dy: half-y, line(length: 6pt, stroke: 0.15pt + rule-color))
      }

      if mm-val > 0 and mm-val <= 10 {
        let is-even = calc.rem(mm-val, 2) == 0
        let lx = if is-even { sx + tick-len / 2 + 1.5pt } else { sx - tick-len / 2 - 6.5pt }
        let txt-color = if calc.rem(mm-val, 5) == 0 { accent } else { ink }
        let txt-weight = if calc.rem(mm-val, 5) == 0 { "bold" } else { "regular" }
        place(top + left, dx: lx, dy: y - 2.5pt,
          text(size: 4.2pt, fill: txt-color, weight: txt-weight)[#mm-val]
        )
      } else if mm-val > 10 and calc.rem(mm-val, 5) == 0 {
        place(top + left, dx: sx + tick-len / 2 + 1.5pt, dy: y - 2.5pt,
          text(size: 4.5pt, fill: accent, weight: "bold")[#mm-val]
        )
      }
    }
    for (i-val, label-txt) in (
      (0.125in, "1/8"), (0.25in, "1/4"), (0.375in, "3/8"), (0.5in, "1/2"),
      (0.625in, "5/8"), (0.75in, "3/4"), (0.875in, "7/8"), (1.0in, "1\"")
    ) {
      let strk = if i-val == 0.5in or i-val == 1.0in { 0.5pt + guide-blue } else { 0.3pt + guide-blue }
      place(top + left, dx: sx + 10pt, dy: h - i-val, line(length: 7pt, stroke: strk))
      place(top + left, dx: sx + 18pt, dy: h - i-val - 2.5pt, text(size: 3.8pt, fill: guide-blue)[#label-txt])
    }
    place(top + left, dx: sx - 12pt, dy: h - 25mm - 6.5pt, text(size: 4.2pt, fill: accent, weight: "bold")[mm (BOTTOM)])
  }

  // Stations along vertical edges
  // LEFT RULER (x = 0 to 25mm)
  for sy in v-stations {
    for mm-val in range(0, 26) {
      let x = mm-val * 1mm
      let tick-len = if calc.rem(mm-val, 10) == 0 { 16pt } else if calc.rem(mm-val, 5) == 0 { 11pt } else { 6pt }
      let strk = if calc.rem(mm-val, 10) == 0 { 0.6pt + ink } else if calc.rem(mm-val, 5) == 0 { 0.45pt + accent } else { 0.25pt + ink }
      place(top + left, dx: x, dy: sy - tick-len / 2, line(angle: 90deg, length: tick-len, stroke: strk))
      
      if mm-val < 25 {
        let half-x = x + 0.5mm
        place(top + left, dx: half-x, dy: sy - 3pt, line(angle: 90deg, length: 6pt, stroke: 0.15pt + rule-color))
      }

      if mm-val > 0 and mm-val <= 10 {
        let is-even = calc.rem(mm-val, 2) == 0
        let ly = if is-even { sy + tick-len / 2 + 1.5pt } else { sy - tick-len / 2 - 6.5pt }
        let txt-color = if calc.rem(mm-val, 5) == 0 { accent } else { ink }
        let txt-weight = if calc.rem(mm-val, 5) == 0 { "bold" } else { "regular" }
        place(top + left, dx: x - 2.5pt, dy: ly,
          text(size: 4.2pt, fill: txt-color, weight: txt-weight)[#mm-val]
        )
      } else if mm-val > 10 and calc.rem(mm-val, 5) == 0 {
        place(top + left, dx: x - 2.5pt, dy: sy + tick-len / 2 + 1.5pt,
          text(size: 4.5pt, fill: accent, weight: "bold")[#mm-val]
        )
      }
    }
    for (i-val, label-txt) in (
      (0.125in, "1/8"), (0.25in, "1/4"), (0.375in, "3/8"), (0.5in, "1/2"),
      (0.625in, "5/8"), (0.75in, "3/4"), (0.875in, "7/8"), (1.0in, "1\"")
    ) {
      let strk = if i-val == 0.5in or i-val == 1.0in { 0.5pt + guide-blue } else { 0.3pt + guide-blue }
      place(top + left, dx: i-val, dy: sy + 10pt, line(angle: 90deg, length: 7pt, stroke: strk))
      place(top + left, dx: i-val - 3pt, dy: sy + 18pt, text(size: 3.8pt, fill: guide-blue)[#label-txt])
    }
    place(top + left, dx: 26mm, dy: sy - 4pt, text(size: 4.2pt, fill: accent, weight: "bold")[mm (LEFT)])
  }

  // RIGHT RULER (x = w - 25mm to w)
  for sy in v-stations {
    for mm-val in range(0, 26) {
      let x = w - (mm-val * 1mm)
      let tick-len = if calc.rem(mm-val, 10) == 0 { 16pt } else if calc.rem(mm-val, 5) == 0 { 11pt } else { 6pt }
      let strk = if calc.rem(mm-val, 10) == 0 { 0.6pt + ink } else if calc.rem(mm-val, 5) == 0 { 0.45pt + accent } else { 0.25pt + ink }
      place(top + left, dx: x, dy: sy - tick-len / 2, line(angle: 90deg, length: tick-len, stroke: strk))
      
      if mm-val < 25 {
        let half-x = x - 0.5mm
        place(top + left, dx: half-x, dy: sy - 3pt, line(angle: 90deg, length: 6pt, stroke: 0.15pt + rule-color))
      }

      if mm-val > 0 and mm-val <= 10 {
        let is-even = calc.rem(mm-val, 2) == 0
        let ly = if is-even { sy + tick-len / 2 + 1.5pt } else { sy - tick-len / 2 - 6.5pt }
        let txt-color = if calc.rem(mm-val, 5) == 0 { accent } else { ink }
        let txt-weight = if calc.rem(mm-val, 5) == 0 { "bold" } else { "regular" }
        place(top + left, dx: x - 2.5pt, dy: ly,
          text(size: 4.2pt, fill: txt-color, weight: txt-weight)[#mm-val]
        )
      } else if mm-val > 10 and calc.rem(mm-val, 5) == 0 {
        place(top + left, dx: x - 2.5pt, dy: sy + tick-len / 2 + 1.5pt,
          text(size: 4.5pt, fill: accent, weight: "bold")[#mm-val]
        )
      }
    }
    for (i-val, label-txt) in (
      (0.125in, "1/8"), (0.25in, "1/4"), (0.375in, "3/8"), (0.5in, "1/2"),
      (0.625in, "5/8"), (0.75in, "3/4"), (0.875in, "7/8"), (1.0in, "1\"")
    ) {
      let strk = if i-val == 0.5in or i-val == 1.0in { 0.5pt + guide-blue } else { 0.3pt + guide-blue }
      place(top + left, dx: w - i-val, dy: sy + 10pt, line(angle: 90deg, length: 7pt, stroke: strk))
      place(top + left, dx: w - i-val - 4pt, dy: sy + 18pt, text(size: 3.8pt, fill: guide-blue)[#label-txt])
    }
    place(top + left, dx: w - 26mm - 30pt, dy: sy - 4pt, text(size: 4.2pt, fill: accent, weight: "bold")[mm (RIGHT)])
  }

  // Cardinal Edge Indicators
  place(top + center, dy: 2pt, text(size: 5.5pt, weight: "bold", fill: highlight)[▲ TOP EDGE (y = 0) — Measure clip from top physical edge ▲])
  place(bottom + center, dy: -2pt, text(size: 5.5pt, weight: "bold", fill: highlight)[▼ BOTTOM EDGE (y = H) — Measure clip from bottom physical edge ▼])
  place(left + horizon, dx: 2pt, rotate(-90deg, text(size: 5.5pt, weight: "bold", fill: highlight)[▲ LEFT EDGE (x = 0) ▲]))
  place(right + horizon, dx: -2pt, rotate(90deg, text(size: 5.5pt, weight: "bold", fill: highlight)[▲ RIGHT EDGE (x = W) ▲]))

  // ---------------------------------------------------------------------------
  // CENTER CONTENT: SCALE CALIBRATION SQUARE + INSTRUCTIONS & FORM
  // ---------------------------------------------------------------------------

  let center-w = w - 62mm

  place(center + horizon, [
    #set align(center)
    #set text(font: label-font, size: 5pt, fill: ink)
    #block(
      width: center-w,
      stroke: 0.6pt + rule-color,
      inset: (x: 6pt, y: 6pt),
      fill: rgb("#fcfbf9"),
      radius: 3pt,
    )[
      #text(size: 8.5pt, weight: "bold", fill: accent)[PRINTER MARGIN & CLIP CALIBRATION]
      #v(0.5pt)
      #text(size: 6.8pt, weight: "bold", fill: ink)[#title]
      #if subtitle != none {
        v(0.5pt)
        text(size: 5pt, fill: rgb("#555"))[#subtitle]
      }
      
      #v(3pt)
      #line(length: 100%, stroke: 0.5pt + accent)
      #v(3pt)

      #if is-portrait [
        // PORTRAIT LAYOUT (5x8) — Clean vertical stack
        #set align(left)
        #text(size: 5.5pt, weight: "bold", fill: accent)[STEP 1: VERIFY PRINT SCALE (100%)]
        #v(1pt)
        #text(size: 4.6pt, fill: ink)[
          Measure the box below with a ruler: Outer = *2.00 in* (50.8 mm), Inner = *50.0 mm* (1.97 in).\
          If dimensions differ, disable "Fit to Page" and print at *100% / Actual Size*.
        ]
        
        #v(2.5pt)
        #align(center)[
          // Precision test square: 2.00 in outer (50.8 mm), 50.0 mm inner
          #box(
            width: 2.0in,
            height: 2.0in,
            stroke: 0.75pt + ink,
            fill: white,
            align(center + horizon)[
              #box(
                width: 50.0mm,
                height: 50.0mm,
                stroke: (dash: "densely-dashed", thickness: 0.5pt, paint: highlight),
                fill: rgb("#fff8f6"),
                align(center + horizon)[
                  #line(length: 24pt, stroke: 0.4pt + rule-color)
                  #place(center + horizon, line(angle: 90deg, length: 24pt, stroke: 0.4pt + rule-color))
                  #place(center + horizon, circle(radius: 7pt, stroke: 0.4pt + accent))
                  #v(2pt)
                  #text(size: 4.5pt, weight: "bold", fill: highlight)[50 mm × 50 mm]\
                  #text(size: 4pt, fill: ink)[Outer: 2.00 in × 2.00 in]
                ]
              )
            ]
          )
        ]

        #v(2.5pt)
        #line(length: 100%, stroke: 0.4pt + light-rule)
        #v(2pt)

        #text(size: 5.5pt, weight: "bold", fill: accent)[STEP 2: READ MEASURED CLIPS AT PAPER EDGES]
        #v(1pt)
        #text(size: 4.5pt, fill: ink)[
          Look at the four physical edges of the card. Find the first visible tick mark at each edge:
        ]
        #v(2pt)
        #table(
          columns: (auto, auto, auto, auto),
          stroke: none,
          column-gutter: (4pt, 16pt, 4pt),
          row-gutter: 3pt,
          align: (left + horizon, left + horizon, left + horizon, left + horizon),
          text(size: 4.6pt, font: text-font)[Top clip:], [#box[#blank(22pt)~mm]],
          text(size: 4.6pt, font: text-font)[Bottom clip:], [#box[#blank(22pt)~mm]],
          text(size: 4.6pt, font: text-font)[Left clip:], [#box[#blank(22pt)~mm]],
          text(size: 4.6pt, font: text-font)[Right clip:], [#box[#blank(22pt)~mm]],
        )

        #v(2.5pt)
        #line(length: 100%, stroke: 0.4pt + light-rule)
        #v(2pt)

        #text(size: 5.5pt, weight: "bold", fill: accent)[STEP 3: CALCULATE FILE MARGINS FOR src/layout/layouts.typ]
        #v(1pt)
        #text(size: 4.5pt, fill: ink)[
          Formula: *margin = clip + card-border* (card-border: L=0.121 in, R=0.117 in, T=0.539 in, B=0.121 in)
        ]
        #v(2pt)
        #table(
          columns: (38pt, 30pt, 55pt, 35pt),
          stroke: none,
          inset: (x: 0pt, y: 1.5pt),
          align: (left + horizon, left + horizon, left + horizon, left + horizon),
          text(size: 4.5pt, font: text-font)[Top:], [#box[#blank(18pt)~in]], [#box[\+ 0.539 in =]], text(size: 4.6pt, weight: "bold")[#box[#blank(20pt)~in]],
          text(size: 4.5pt, font: text-font)[Bottom:], [#box[#blank(18pt)~in]], [#box[\+ 0.121 in =]], text(size: 4.6pt, weight: "bold")[#box[#blank(20pt)~in]],
          text(size: 4.5pt, font: text-font)[Left:], [#box[#blank(18pt)~in]], [#box[\+ 0.121 in =]], text(size: 4.6pt, weight: "bold")[#box[#blank(20pt)~in]],
          text(size: 4.5pt, font: text-font)[Right:], [#box[#blank(18pt)~in]], [#box[\+ 0.117 in =]], text(size: 4.6pt, weight: "bold")[#box[#blank(20pt)~in]],
        )

        #v(2.5pt)
        #line(length: 100%, stroke: 0.4pt + light-rule)
        #v(2pt)

        #text(size: 5.5pt, weight: "bold", fill: accent)[STEP 4: UPDATE src/layout/layouts.typ]
        #v(1pt)
        #text(size: 4.5pt, fill: ink)[
          Paste the calculated margins into the `"5x8"` or `"8x5"` entry:
        ]
        #v(1pt)
        #block(
          width: 100%,
          fill: rgb("#f0ede8"),
          inset: 3pt,
          radius: 2pt,
          text(size: 4.2pt, font: label-font)[
            margin: (left: ...in, right: ...in, top: ...in, bottom: ...in)
          ]
        )
        #v(1pt)
        #text(size: 3.8pt, fill: rgb("#666"))[
          Quick mm to in: 1mm=0.039 in, 2mm=0.079 in, 3mm=0.118 in, 4mm=0.157 in, 5mm=0.197 in, 6mm=0.236 in
        ]
      ] else [
        // LANDSCAPE LAYOUT (8x5) — 3-column side-by-side
        #grid(
          columns: (1.1fr, auto, 1.3fr),
          gutter: 8pt,
          align: horizon,
          [
            #set align(left)
            #text(size: 5.5pt, weight: "bold", fill: accent)[STEP 1: VERIFY SCALE]
            #v(1pt)
            #text(size: 4.6pt, fill: ink)[
              Measure with a ruler:\
              • Outer = *1.85 in* (47.0 mm)\
              • Inner = *45.0 mm* (1.77 in)\
              Print at *100% / Actual Size*.
            ]
            #v(4pt)
            #text(size: 5.5pt, weight: "bold", fill: accent)[STEP 2: READ CLIPS]
            #v(1pt)
            #table(
              columns: (auto, auto),
              stroke: none,
              column-gutter: 4pt,
              row-gutter: 2.5pt,
              align: (left + horizon, left + horizon),
              text(size: 4.5pt, font: text-font)[Top clip:], [#box[#blank(20pt)~mm]],
              text(size: 4.5pt, font: text-font)[Bottom clip:], [#box[#blank(20pt)~mm]],
              text(size: 4.5pt, font: text-font)[Left clip:], [#box[#blank(20pt)~mm]],
              text(size: 4.5pt, font: text-font)[Right clip:], [#box[#blank(20pt)~mm]],
            )
          ],
          [
            // Precision test square for landscape
            #box(
              width: 1.85in,
              height: 1.85in,
              stroke: 0.75pt + ink,
              fill: white,
              align(center + horizon)[
                #box(
                  width: 45.0mm,
                  height: 45.0mm,
                  stroke: (dash: "densely-dashed", thickness: 0.5pt, paint: highlight),
                  fill: rgb("#fff8f6"),
                  align(center + horizon)[
                    #line(length: 20pt, stroke: 0.4pt + rule-color)
                    #place(center + horizon, line(angle: 90deg, length: 20pt, stroke: 0.4pt + rule-color))
                    #place(center + horizon, circle(radius: 6pt, stroke: 0.4pt + accent))
                    #v(1pt)
                    #text(size: 4.2pt, weight: "bold", fill: highlight)[45 mm × 45 mm]\
                    #text(size: 3.8pt, fill: ink)[Outer: 1.85 in × 1.85 in]
                  ]
                )
              ]
            )
          ],
          [
            #set align(left)
            #text(size: 5.5pt, weight: "bold", fill: accent)[STEP 3: FILE MARGINS]\
            #text(size: 4.2pt, fill: ink)[
              margin = *Clip* + *card-border*
            ]
            #v(2pt)
            #table(
              columns: (30pt, 48pt, 28pt),
              stroke: none,
              inset: (x: 0pt, y: 1.2pt),
              align: (left + horizon, left + horizon, left + horizon),
              text(size: 4.2pt, font: text-font)[Top:], [#box[\+ 0.539 in =]], text(size: 4.2pt, weight: "bold")[#box[#blank(18pt)~in]],
              text(size: 4.2pt, font: text-font)[Bottom:], [#box[\+ 0.121 in =]], text(size: 4.2pt, weight: "bold")[#box[#blank(18pt)~in]],
              text(size: 4.2pt, font: text-font)[Left:], [#box[\+ 0.121 in =]], text(size: 4.2pt, weight: "bold")[#box[#blank(18pt)~in]],
              text(size: 4.2pt, font: text-font)[Right:], [#box[\+ 0.117 in =]], text(size: 4.2pt, weight: "bold")[#box[#blank(18pt)~in]],
            )
            #v(2.5pt)
            #text(size: 5.5pt, weight: "bold", fill: accent)[STEP 4: UPDATE layouts.typ]\
            #block(
              width: 100%,
              fill: rgb("#f0ede8"),
              inset: 2.5pt,
              radius: 1.5pt,
              text(size: 3.8pt, font: label-font)[
                margin: (left: ...in, right: ...in, top: ...in, bottom: ...in)
              ]
            )
          ]
        )
      ]
    ]
  ])
}

// Render based on inputs
#if input-card == "auto" or input-card == "all" {
  // Render both 5x8 portrait (Placard / Portrait feed) and 8x5 landscape (Character / Action cards / Landscape feed)
  calibration-page(5in, 8in, "5\" x 8\" Portrait Card Calibration", "Placard Card / Portrait Paper Feed")
  calibration-page(8in, 5in, "8\" x 5\" Landscape Card Calibration", "Core Stats & Action Cards / Landscape Paper Feed")
} else if card-sizes.keys().contains(input-card) {
  let c = card-sizes.at(input-card)
  calibration-page(c.width, c.height, c.name + " Calibration", none)
} else {
  // Default to 5x8
  calibration-page(5in, 8in, "5\" x 8\" Card Calibration", none)
}
