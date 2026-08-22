"""Backward-compatible imports for the Qt Syslog adapter."""

from .qt.manager import SyslogManager, _variant_dict

__all__ = ["SyslogManager", "_variant_dict"]
