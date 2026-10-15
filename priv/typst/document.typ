// A business document of the shop (#17): letterhead, recipient, details,
// a table of items, sums and a footer. Mercator.Pdf writes data.json next
// to this file; all texts arrive formatted and translated.

#let data = json("data.json")

#set document(title: data.title, author: data.brand.name)
#set page(
  paper: "a4",
  margin: (top: 2cm, bottom: 2.4cm, x: 2cm),
  footer: context [
    #set text(size: 7.5pt, fill: luma(110))
    #data.brand.name
    #h(1fr)
    #data.title · #counter(page).display("1 / 1", both: true)
  ],
)
#set text(font: ("Noto Sans", "DejaVu Sans", "Liberation Sans"), size: 9.5pt, lang: data.lang)
#set par(leading: 0.55em)

#let muted(body) = text(fill: luma(100), body)

// letterhead
#grid(
  columns: (1fr, auto),
  align: (left + top, right + top),
  if data.brand.logo != none { image(data.brand.logo, height: 1.8cm) },
  {
    set text(size: 8pt)
    strong(data.brand.name)
    for line in data.brand.lines [ \ #muted(line) ]
  },
)
#line(length: 100%, stroke: 0.5pt + luma(200))
#v(0.8cm)

// recipient and details
#grid(
  columns: (1fr, auto),
  column-gutter: 1cm,
  data.recipient.join(linebreak()),
  grid(
    columns: 2,
    column-gutter: 0.8em,
    row-gutter: 0.45em,
    align: (right, right),
    ..data.meta.map(((label, value)) => (muted(label), value)).flatten(),
  ),
)

#v(1cm)
#text(size: 16pt, weight: "bold", data.title)

#if data.at("intro", default: none) != none {
  v(0.3em)
  data.intro
}

#v(0.6cm)

// items: a cell is a text, or a dictionary with a title and detail lines
#let cell(value) = if type(value) == dictionary {
  strong(value.title)
  for line in value.details [ \ #text(size: 8pt, muted(line)) ]
} else { value }

#table(
  columns: data.columns.map(c => if c.at("wide", default: false) { 1fr } else { auto }),
  align: data.columns.map(c => if c.align == "right" { right } else { left }),
  stroke: (x, y) => (bottom: if y == 0 { 0.8pt + luma(160) } else { 0.4pt + luma(220) }),
  inset: (x: 4pt, y: 5pt),
  table.header(..data.columns.map(c => text(size: 8pt, muted(c.label)))),
  ..data.rows.map(row => row.map(cell)).flatten(),
)

// sums
#align(right, block(width: 7cm, breakable: false, {
  set par(leading: 0.4em)
  grid(
    columns: (1fr, auto),
    column-gutter: 1em,
    row-gutter: 0.5em,
    align: (left, right),
    ..data.sums
      .map(sum => if sum.at("strong", default: false) {
        (
          grid.hline(stroke: 0.8pt + luma(160)),
          strong(sum.label),
          strong(sum.value),
        )
      } else { (sum.label, sum.value) })
      .flatten(),
  )
}))

#v(1fr)
#set text(size: 8pt)
#for paragraph in data.footer [
  #muted(paragraph)

]
