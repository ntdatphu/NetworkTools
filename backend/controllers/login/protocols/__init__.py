from .ssh_adapter import login_ssh
from .telnet_adapter import login_telnet
from .restconf_adapter import login_restconf
from .netconf_adapter import login_netconf


SUPPORTED_METHODS = {
    "SSH": login_ssh,
    "TELNET": login_telnet,
    "RESTCONF": login_restconf,
    "NETCONF": login_netconf,
}
