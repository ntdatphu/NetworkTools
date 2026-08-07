// Các helper dùng lặp lại trong báo cáo.

#let front-heading(title) = {
  pagebreak(weak: true)
  heading(level: 1, numbering: none, outlined: true)[#title]
}

#let appendix-heading(title) = {
  pagebreak(weak: true)
  heading(level: 1, numbering: none, outlined: true)[#title]
}

#let report-note(body) = block(
  width: 100%,
  inset: 10pt,
  radius: 4pt,
  stroke: 0.5pt,
  fill: luma(245),
  body,
)

#let todo(body) = block(
  width: 100%,
  inset: 8pt,
  stroke: 0.5pt,
  [*TODO:* #body],
)
