// ==========================================================
// BÁO CÁO NCKH SINH VIÊN - NETWORKTOOLS (TYPST)
// Chuyển từ cấu trúc LaTeX modular sang Typst.
// ==========================================================

#import "config/settings.typ": report-style
#import "config/commands.typ": *
#import "config/info.typ": *
#import "config/images.typ": *
#import "config/listings.typ": *

#show: report-style

// ----------------------------------------------------------
// TRANG BÌA
// ----------------------------------------------------------
// Nếu có cover/bia.pdf và muốn dùng bìa PDF riêng, có thể chèn thủ công
// ở đây sau khi kiểm tra bố cục. Mặc định project không phụ thuộc file bìa.

// ----------------------------------------------------------
// PHẦN ĐẦU
// ----------------------------------------------------------
#set page(numbering: "i")
#counter(page).update(1)

#include "chapters/00_loi_cam_doan.typ"
#include "chapters/00_loi_cam_on.typ"
#include "chapters/00_tom_tat.typ"
#include "chapters/00_danh_muc_tu_viet_tat.typ"

#pagebreak()
#outline(title: [Mục lục], depth: 3)

#pagebreak()
#outline(
  title: [Danh mục hình],
  target: figure.where(kind: image),
)

#pagebreak()
#outline(
  title: [Danh mục bảng],
  target: figure.where(kind: table),
)

// ----------------------------------------------------------
// NỘI DUNG CHÍNH
// ----------------------------------------------------------
#pagebreak()
#set page(numbering: "1")
#counter(page).update(1)

#include "chapters/01_tong_quan.typ"
#include "chapters/02_co_so_ly_thuyet.typ"
#include "chapters/03_phan_tich_thiet_ke.typ"
#include "chapters/04_xay_dung_phan_mem.typ"
#include "chapters/05_thu_nghiem_danh_gia.typ"
#include "chapters/06_ket_luan_huong_phat_trien.typ"

// ----------------------------------------------------------
// TÀI LIỆU THAM KHẢO
// ----------------------------------------------------------
#pagebreak()
#bibliography(
  "networktools_references.bib",
  title: [Tài liệu tham khảo],
  style: "ieee",
)

// ----------------------------------------------------------
// PHỤ LỤC
// ----------------------------------------------------------
#include "appendix/appendix_a_huong_dan_cai_dat.typ"
#include "appendix/appendix_b_cau_truc_du_an.typ"
#include "appendix/appendix_c_kiem_thu.typ"
