import re
from typing import Any, Dict, List


def parse_acl_payload(raw_text: str, host: str) -> Dict[str, Any]:
    text = raw_text or ""
    acls: List[Dict[str, Any]] = []

    # access-list 10 permit 10.0.0.0 0.0.0.255
    std_pattern = re.compile(
        r"^\s*access-list\s+(\d+)\s+(permit|deny)\s+(.+?)\s*$",
        re.IGNORECASE | re.MULTILINE,
    )

    std_rules = []
    seq = 10
    for m in std_pattern.finditer(text):
        acl_num = m.group(1)
        action = m.group(2).lower()
        rest = m.group(3).strip()
        if not acl_num.isdigit() or int(acl_num) > 99:
            continue
        if " " in rest:
            source, wildcard = rest.split(" ", 1)
        else:
            source, wildcard = rest, None
        std_rules.append(
            {
                "sequence": seq,
                "action": action,
                "source": source,
                "wildcard": wildcard,
            }
        )
        seq += 10

    if std_rules:
        acls.append(
            {
                "acl_name": "STD_PARSED",
                "acl_type": "standard",
                "description": "parsed from access-list lines",
                "rules": std_rules,
            }
        )

    # Named extended ACL block parser (basic)
    ext_block_pattern = re.compile(
        r"ip\s+access-list\s+extended\s+(\S+)(.*?)(?=^\S|\Z)",
        re.IGNORECASE | re.MULTILINE | re.DOTALL,
    )

    for ext_m in ext_block_pattern.finditer(text):
        acl_name = ext_m.group(1)
        block = ext_m.group(2)
        rules = []
        seq_num = 10
        for line in block.splitlines():
            line = line.strip()
            if not line:
                continue
            parts = line.split()
            if len(parts) < 5:
                continue
            action = parts[0].lower()
            protocol = parts[1].lower()
            source = parts[2]
            destination = parts[-1]
            rules.append(
                {
                    "sequence": seq_num,
                    "action": action,
                    "protocol": protocol,
                    "source": source,
                    "src_wildcard": None,
                    "src_port": None,
                    "destination": destination,
                    "dst_wildcard": None,
                    "dst_port": None,
                }
            )
            seq_num += 10

        if rules:
            acls.append(
                {
                    "acl_name": acl_name,
                    "acl_type": "extended",
                    "description": "parsed from named extended ACL",
                    "rules": rules,
                }
            )

    return {"host": host, "acls": acls}
