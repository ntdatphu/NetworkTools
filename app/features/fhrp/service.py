"""Validation and orchestration for multi-device FHRP configuration."""

from __future__ import annotations

import ipaddress
import sqlite3
from typing import Any

from .repository import FhrpRepository


LIMITS = {"hsrp": (0, 4095), "vrrp": (1, 255), "glbp": (0, 1023)}


class FhrpService:
    """Expose a compact frontend contract without leaking schema details."""

    MAX_HOSTS = 5

    def __init__(self, db: Any) -> None:
        self.db = db
        self.repository = FhrpRepository(db)

    def options(self) -> dict[str, Any]:
        return {"ok": True, "hosts": self.repository.connected_hosts()}

    def matching_interfaces(self, hosts: list[Any], gateway_text: str) -> dict[str, Any]:
        normalized_hosts = list(dict.fromkeys(str(host or "").strip() for host in hosts))
        normalized_hosts = [host for host in normalized_hosts if host]
        try:
            gateway = ipaddress.IPv4Address(str(gateway_text or "").strip())
        except ValueError:
            return {"ok": False, "message": "Default Gateway must be a valid IPv4 address.", "interfaces": []}
        interfaces = self.repository.matching_interfaces(normalized_hosts, gateway)
        return {
            "ok": True,
            "message": f"Found {len(interfaces)} matching interface(s).",
            "interfaces": interfaces,
        }

    def groups(self, host: str = "") -> dict[str, Any]:
        return {"ok": True, "groups": self.repository.list_groups(str(host or "").strip())}

    def save(self, payload: dict[str, Any]) -> dict[str, Any]:
        try:
            normalized = self._normalize(payload)
            fhrp_id = self.repository.save_group(normalized)
            hosts = [member["host"] for member in normalized["members"]]
            return {
                "ok": True,
                "fhrp_id": fhrp_id,
                "hosts": hosts,
                "message": f"Saved {normalized['protocol'].upper()} group for {len(hosts)} devices.",
            }
        except (ValueError, sqlite3.Error) as exc:
            return {"ok": False, "fhrp_id": 0, "hosts": [], "message": str(exc)}

    def delete(self, fhrp_id: int) -> dict[str, Any]:
        if fhrp_id <= 0:
            return {"ok": False, "hosts": [], "message": "Invalid FHRP group ID."}
        hosts = self.repository.mark_group_for_delete(fhrp_id)
        return {
            "ok": bool(hosts),
            "hosts": hosts,
            "message": f"Marked FHRP group for removal on {len(hosts)} devices.",
        }

    def _normalize(self, payload: dict[str, Any]) -> dict[str, Any]:
        protocol = str(payload.get("protocol") or "").strip().lower()
        if protocol not in LIMITS:
            raise ValueError("Protocol must be HSRP, VRRP or GLBP.")
        group_number = self.db._int_or_none(payload.get("group_number"))
        low, high = LIMITS[protocol]
        if group_number is None or not low <= group_number <= high:
            raise ValueError(f"{protocol.upper()} group must be between {low} and {high}.")
        gateway_text = str(
            payload.get("default_gateway") or payload.get("virtual_ip") or ""
        ).strip()
        try:
            gateway = ipaddress.IPv4Address(gateway_text)
        except ValueError as exc:
            raise ValueError("Default Gateway must be a valid IPv4 address.") from exc

        raw_members = [
            self.db._as_dict(item)
            for item in self.db._as_list(payload.get("members"))
        ]
        if len(raw_members) < 2:
            raise ValueError("FHRP requires at least two selected hosts.")
        if len(raw_members) > self.MAX_HOSTS:
            raise ValueError(
                f"FHRP supports at most {self.MAX_HOSTS} selected hosts."
            )
        hosts: set[str] = set()
        selected_interface_ids: set[int] = set()
        members: list[dict[str, Any]] = []
        candidates = self.repository.matching_interfaces(
            [str(item.get("host") or "").strip() for item in raw_members],
            gateway,
        )
        candidate_keys = {
            (row["host"], int(row["iface_id"])) for row in candidates
        }
        for raw in raw_members:
            host = str(raw.get("host") or "").strip()
            iface_id = self.db._int_or_none(raw.get("iface_id"))
            if not host or host in hosts:
                raise ValueError("Every FHRP member must use a unique host.")
            if iface_id is None or (host, iface_id) not in candidate_keys:
                raise ValueError(f"Selected interface on {host} does not reach {gateway}.")
            if iface_id in selected_interface_ids:
                raise ValueError("An interface can only be selected once.")
            priority = self.db._int_or_none(raw.get("priority"))
            if priority is None:
                priority = 100
            if not 1 <= priority <= 255:
                raise ValueError(f"Priority on {host} must be between 1 and 255.")
            auth_type = str(raw.get("auth_type") or "none").strip().lower()
            auth_secret = str(raw.get("auth_secret") or "").strip()
            if "\n" in auth_secret or "\r" in auth_secret:
                raise ValueError(
                    f"Authentication secret on {host} contains an invalid line break."
                )
            allowed_auth = (
                {"none", "plain"}
                if protocol == "vrrp"
                else {"none", "plain", "md5-key", "md5-keychain"}
            )
            if auth_type not in allowed_auth:
                raise ValueError(f"Unsupported {protocol.upper()} authentication on {host}.")
            if auth_type != "none" and not auth_secret:
                raise ValueError(f"Authentication secret is required on {host}.")
            member = dict(raw)
            member.update(
                {
                    "host": host,
                    "iface_id": iface_id,
                    "priority": priority,
                    "preempt": bool(raw.get("preempt")),
                    "shutdown": bool(raw.get("shutdown")),
                    "auth_type": auth_type,
                    "auth_secret": auth_secret,
                    "version": (
                        2
                        if protocol == "vrrp" and auth_type != "none"
                        else self.db._int_or_none(raw.get("version"))
                        or (3 if protocol == "vrrp" else 2)
                    ),
                    "tracks": self._tracks(raw.get("tracks")),
                }
            )
            hosts.add(host)
            selected_interface_ids.add(iface_id)
            members.append(member)
        return {
            "protocol": protocol,
            "group_number": group_number,
            "virtual_ip": str(gateway),
            "description": str(payload.get("description") or "").strip(),
            "members": members,
        }

    def _tracks(self, value: Any) -> list[dict[str, Any]]:
        tracks: list[dict[str, Any]] = []
        for item in self.db._as_list(value):
            row = self.db._as_dict(item)
            track_object = str(row.get("track_object") or "").strip()
            if not track_object:
                continue
            if "\n" in track_object or "\r" in track_object:
                raise ValueError("Track object contains an invalid line break.")
            decrement = self.db._int_or_none(row.get("decrement_value")) or 10
            if not 1 <= decrement <= 254:
                raise ValueError("Track decrement must be between 1 and 254.")
            tracks.append(
                {"track_object": track_object, "decrement_value": decrement}
            )
        return tracks
