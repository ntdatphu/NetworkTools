from __future__ import annotations

from typing import Any


def text_or_none(value: Any) -> str | None:
    """Chuẩn hóa giá trị text rỗng thành None trước khi ghi DB."""
    if value is None:
        return None
    text = str(value).strip()
    return text or None


def text_or_default(value: Any, default: str) -> str:
    """Chuẩn hóa text và trả về giá trị mặc định khi dữ liệu rỗng."""
    text = text_or_none(value)
    return text if text is not None else default


def option_action_cfg(current: dict[str, Any], submitted: dict[str, Any]) -> str:
    """Tính bit action_Cfg cho các option DHCP có thể ghi đè trực tiếp."""
    fields = ("defaut", "dns", "lease")
    bits = ["1" if str(current.get(field) or "") != str(submitted.get(field) or "") else "0" for field in fields]
    return "".join(bits)


def pool_identity_changed(current: dict[str, Any], submitted: dict[str, Any]) -> bool:
    """Kiểm tra các trường định danh pool có cần replace row hay không."""
    return any(
        str(current.get(field) or "") != str(submitted.get(field) or "")
        for field in ("pool", "network", "subnetmask")
    )


def table_name(db: Any, conn: Any, legacy: str, numbered: str) -> str:
    """Chọn tên bảng numbered nếu tồn tại, fallback về bảng legacy."""
    if hasattr(db, "_table_exists") and db._table_exists(conn, numbered):
        return numbered
    return legacy


def interface_table_info(db: Any, conn: Any) -> tuple[str, str]:
    """Lấy tên bảng và cột interface đang dùng trong schema hiện tại."""
    table = table_name(db, conn, "interface_name", "t02_interface_name")
    column = "t02_interface_name" if table == "t02_interface_name" else "interface_name"
    return table, column
