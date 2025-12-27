#let makecoverpage(
  title: none,
  subtitle: none,
  name: none,
  main-titlebox-fill: color.rgb(
    0,
    0,
    0,
  ),
) = context {
  let pw = page.width
  let ph = page.height
  // set image(width: pw, height: ph, fit: "cover")
  set page(margin: 0pt)
  set par(first-line-indent: 0pt, justify: false, leading: 1.5em)

  place(left + horizon, dx: 12pt, rotate(-90deg, origin: center, reflow: true)[
    #text(fill: black, font: "Roboto Slab")[Delft University of Technology]])


  place(center, dy: 5cm, rect(width: 80%, inset: 20pt, fill: main-titlebox-fill)[
    #align(left, text(fill: white, size: 100pt, font: "Roboto Slab", weight: "extralight", [#title]))
  ])

  if subtitle != none {
    place(left, dx: 2.5cm, dy: 4.3cm, text(size: 15pt, font: "Roboto Slab", weight: "light", emph(subtitle)))
  }

  place(
    dx: 3cm,
    dy: 2cm,
    scale(image("robot.png"), 75%),
  )

  place(bottom + left, pad(1.3cm, emph(text(size: 20pt, font: "Roboto Slab", weight: "extralight", name))))
}
