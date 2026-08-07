// Helper chèn hình.
// Ví dụ:
// #insert-image("figures/gui/main_window.png", caption: [Giao diện chính]) <fig-main>

#let insert-image(path, caption: none, width: 80%) = {
  figure(
    image(path, width: width),
    caption: caption,
  )
}
