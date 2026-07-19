"""Compatibility wrapper; use :mod:`scripts.build_databases`."""

from scripts.build_databases import *  # noqa: F401,F403
from scripts.build_databases import main


if __name__ == "__main__":
    raise SystemExit(main())
