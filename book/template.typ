// The pdp64 manual: a Typst template in the contract of buildabook (book-title, running-title, fm-pages, body-pages,
// chapter(path, token, part, toc), pgan(id), pageof(id), cmarker's render), forked from buildabook's template/book.typ for a
// technical reference: letter pages, a serif text face, a monospace face for code, small tables, no ornaments.
// tools/mkbook.py appends one #chapter(...) call per outline entry below the marker at the end.

#import "@preview/cmarker:0.1.8": render

#let book-title     = "The pdp64 Architecture Manual"
#let book-subtitle  = "A 64-bit extension of the PDP-11"
#let book-tagline   = "Digital Equity Collective's Pragmatic Digital Processor, 64 bit"
#let book-author    = "David Walther"
#let book-year      = "2026"

#set document(title: book-title, author: book-author)

#let pgan(id) = [#metadata(none)#label("pg-" + id)]
#let pageof(id) = context {
  str(counter(page).at(locate(label("pg-" + id))).first())
}

#let md-title(src) = {
  let line = src.split("\n").find(l => l.starts-with("# "))
  if line != none { line.slice(2).trim() } else { "" }
}
#let md-body(src) = {
  let lines = src.split("\n")
  let idx   = lines.position(l => l.starts-with("# "))
  if idx != none { lines.slice(idx + 1).join("\n") } else { src }
}
#let md-short-title(src) = {
  let full  = md-title(src)
  let parts = full.split(" — ")
  if parts.len() > 1 { parts.slice(1).join(" — ") } else { full }
}

#let running-title = state("running-title", "")

#set page(width: 8.5in, height: 11in, margin: (top: 0.9in, bottom: 0.9in, inside: 1in, outside: 0.8in))
#set text(font: "EB Garamond", size: 10.5pt, lang: "en")
#set par(justify: true, leading: 0.6em, spacing: 0.75em)
#set list(indent: 0.8em, body-indent: 0.5em)
#show raw: set text(font: "DejaVu Sans Mono", size: 0.82em)
#show raw.where(block: true): it => block(width: 100%, fill: luma(246), inset: 6pt, radius: 2pt, breakable: true, text(size: 7.2pt, it))
#show raw.where(block: false): set text(size: 0.84em)
#set table(stroke: 0.4pt + luma(150), inset: (x: 4pt, y: 3pt))
#show table: set text(size: 8.6pt)
#show table: set par(justify: false, leading: 0.5em)
#show table: set block(above: 0.9em, below: 0.9em)
#show line: _ => v(0.4em)
#show quote.where(block: true): it => pad(left: 1.2em, right: 1.2em, text(style: "italic", it.body))
#show link: set text(fill: rgb("#1a4f8b"))
#set image(width: 92%)
#show image: it => block(above: 0.8em, below: 0.9em, breakable: false, align(center, it))

// Part title
#show heading.where(level: 1): it => {
  pagebreak(weak: true)
  v(2.2in)
  align(center, text(size: 26pt, weight: "regular", tracking: 0.02em, it.body))
  v(0.8in)
}
// Chapter title
#show heading.where(level: 2): it => {
  pagebreak(weak: true)
  v(0.6in)
  text(size: 21pt, weight: "regular", it.body)
  v(0.35in)
}
// Section (markdown ##)
#show heading.where(level: 3): it => block(above: 1.5em, below: 0.6em, sticky: true, text(size: 13pt, weight: "bold", it.body))
// Entry or subsection (markdown ###)
#show heading.where(level: 4): it => block(above: 1.3em, below: 0.5em, sticky: true, text(size: 11.5pt, weight: "bold", it.body))
#show heading.where(level: 5): it => block(above: 1em, below: 0.4em, sticky: true, text(size: 10.5pt, style: "italic", it.body))

#let body-pages(doc) = {
  set page(
    header: context {
      let n = counter(page).at(here()).first()
      set text(size: 8.5pt, tracking: 0.05em)
      if calc.odd(n) { align(right, smallcaps(running-title.at(here()))) } else { align(left, smallcaps(book-title)) }
    },
    footer: context { align(center, text(size: 9.5pt, str(counter(page).at(here()).first()))) },
    numbering: "1",
  )
  doc
}
#let fm-pages(doc) = {
  set page(header: none, footer: context { align(center, text(size: 9.5pt, counter(page).display("i"))) }, numbering: "i")
  doc
}

#let chapter(path, token: none, part: false, toc: true) = {
  let src  = read(path)
  running-title.update(md-short-title(src))
  heading(level: if part { 1 } else { 2 }, outlined: toc, numbering: none)[#md-title(src)]
  if token != none { pgan(token.split(":").last()) }
  render(md-body(src), h1-level: 2, scope: (render: render, pgan: pgan, pageof: pageof, image: (path, ..args) => image(path, ..args)))
}

// Title page
#page(header: none, footer: none, numbering: none)[
  #v(2.4in)
  #align(center)[
    #text(size: 30pt, weight: "regular", tracking: 0.02em, book-title)
    #v(0.5em)
    #text(size: 15pt, style: "italic", book-subtitle)
    #v(1em)
    #line(length: 2.2in, stroke: 0.4pt)
    #v(1em)
    #text(size: 11pt, tracking: 0.04em, book-tagline)
    #v(2.6em)
    #text(size: 14pt, book-author)
  ]
]
// Licence page
#page(header: none, footer: none, numbering: none)[
  #v(1fr)
  #set text(size: 9.5pt)
  #set par(first-line-indent: 0em, leading: 0.7em)
  Copyright #sym.copyright #book-year #book-author. Released under the BSD 2-Clause licence (the file `COPYING` of the repository).

  The source of this book is https://github.com/moebiusV/pdp64 (`docs/streamlined/`); the instruction dictionary is generated from the machine-readable specification. Typeset with Typst in EB Garamond and DejaVu Sans Mono.
]

#show: fm-pages
#counter(page).update(1)
#v(0.4in)
#align(center, text(size: 14pt, tracking: 0.18em, upper[Contents]))
#v(0.5in)
#show outline.entry.where(level: 1): set text(weight: "bold")
#show outline.entry: set par(first-line-indent: 0em, leading: 0.9em)
#outline(title: none, depth: 2, indent: 1.2em)

// {{FRONT-MATTER}}

#show: body-pages
#counter(page).update(1)

// Chapter list appended below by tools/mkbook.py — DO NOT EDIT BELOW THIS LINE
