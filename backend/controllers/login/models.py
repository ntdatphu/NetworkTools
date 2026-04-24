from dataclasses import dataclass, asdict
from typing import Any, Dict, Optional


@dataclass
class Device:
    host: str
    device_name: Optional[str] = None
    method: Optional[str] = None
    portnumber: Optional[int] = None
    username: Optional[str] = None
    password: Optional[str] = None
    os: Optional[str] = None
    role: Optional[str] = None
    success: Optional[int] = None

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "Device":
        return cls(
            host=(data.get("host") or "").strip(),
            device_name=data.get("device_name"),
            method=(data.get("method") or "").strip().upper() or None,
            portnumber=data.get("portnumber"),
            username=data.get("username"),
            password=data.get("password"),
            os=data.get("os"),
            role=data.get("role"),
            success=data.get("success"),
        )

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


@dataclass
class LoginResult:
    ok: bool
    message: str
    detected_os: Optional[str] = None
    detected_role: Optional[str] = None
    raw_version: Optional[str] = None
    raw_config: Optional[str] = None
    route_detected: bool = False
    vlan_detected: bool = False

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)
