// Thiết lập trình bày chung cho báo cáo NCKH.

#let report-style(body) = {
  set page(
    paper: "a4",
    margin: (
      left: 3cm,
      right: 2cm,
      top: 2.5cm,
      bottom: 2.5cm,
    ),
    numbering: "1",
    number-align: center + bottom,
  )

  set text(
    font: "Times New Roman",
    size: 13pt,
    lang: "vi",
  )

  set par(
    justify: true,
    first-line-indent: 1.27cm,
    leading: 0.65em,
  )

  set heading(numbering: "1.1.1")

  // Cỡ chữ theo cấp tiêu đề.
  show heading.where(level: 1): set text(size: 16pt, weight: "bold")
  show heading.where(level: 2): set text(size: 14pt, weight: "bold")
  show heading.where(level: 3): set text(size: 13pt, weight: "bold")

  // Tên hình/bảng tiếng Việt.
  show figure.where(kind: image): set figure(supplement: [Hình])
  show figure.where(kind: table): set figure(supplement: [Bảng])

  body
}
