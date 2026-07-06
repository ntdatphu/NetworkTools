from __future__ import annotations

from typing import Any


def text_or_none(value: Any) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    return text or None


def text_or_default(value: Any, default: str) -> str:
    text = text_or_none(value)
    return text if text is not None else default


def option_action_cfg(current: dict[str, Any], submitted: dict[str, Any]) -> str:
    fields = ("defaut", "dns", "lease")
    bits = ["1" if str(current.get(field) or "") != str(submitted.get(field) or "") else "0" for field in fields]
    return "".join(bits)


def pool_identity_changed(current: dict[str, Any], submitted: dict[str, Any]) -> bool:
    return any(
        str(current.get(field) or "") != str(submitted.get(field) or "")
        for field in ("pool", "network", "subnetmask")
    )
