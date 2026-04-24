from dataclasses import dataclass


@dataclass(frozen=True)
class LoginConfig:
    connect_timeout: int = 8
    read_timeout: int = 8
    retries: int = 1
    verify_restconf_ssl: bool = False


DEFAULT_PORTS = {
    "SSH": 22,
    "TELNET": 23,
    "NETCONF": 830,
    "RESTCONF": 443,
}
