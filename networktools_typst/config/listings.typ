// Helper hiển thị code/lệnh.
// Typst hỗ trợ raw block trực tiếp bằng ```lang ... ```.

#let codebox(code, caption: none) = {
  block(
    width: 100%,
    inset: 10pt,
    radius: 4pt,
    stroke: 0.5pt,
    fill: luma(248),
    code,
  )
  if caption != none {
    align(center, text(size: 10pt)[#caption])
  }
}
