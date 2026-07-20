"""Read-only structural checks for the NetworkTools application tree."""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path


APP_DIR = Path(__file__).resolve().parents[1]
VALID_STATUSES = {"implemented", "partial", "stub", "planned"}
RUNTIME_SUFFIXES = (".db", ".db-wal", ".db-shm", ".db-journal")
ABSOLUTE_PATH = re.compile(r"(?:[A-Za-z]:\\(?:Users|Program Files)\\|/(?:home|Users)/[^/\s]+/)")


def _tracked_files() -> list[str]:
    result = subprocess.run(
        ["git", "ls-files", "--", "."], cwd=APP_DIR, text=True, capture_output=True, check=False
    )
    return result.stdout.splitlines() if result.returncode == 0 else []


def check_feature_readmes(errors: list[str]) -> None:
    for directory in sorted(path for path in (APP_DIR / "features").rglob("*") if path.is_dir()):
        if directory.name in {"__pycache__", "templates", "tests"}:
            continue
        if any(path.suffix == ".py" for path in directory.iterdir()) or directory.parent == APP_DIR / "features":
            if not (directory / "README.md").is_file():
                errors.append(f"missing feature README: {directory.relative_to(APP_DIR)}")


def check_qmldir(errors: list[str]) -> None:
    qmldir = APP_DIR / "UI" / "qmldir"
    declared: set[str] = set()
    for line in qmldir.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith(("#", "module", "singleton")):
            if stripped.startswith("singleton"):
                parts = stripped.split()
                if len(parts) >= 4:
                    declared.add(parts[3])
            continue
        parts = stripped.split()
        if len(parts) >= 3:
            declared.add(parts[2])
    for relative in declared:
        if not (APP_DIR / "UI" / relative).is_file():
            errors.append(f"qmldir target does not exist: UI/{relative}")


def check_runtime_artifacts(errors: list[str]) -> None:
    for path in _tracked_files():
        if path.endswith(RUNTIME_SUFFIXES):
            errors.append(f"tracked runtime database: {path}")


def check_legacy_directories(errors: list[str]) -> None:
    for name in ("backend", "network_code", "template", "database"):
        if (APP_DIR / name).exists():
            errors.append(f"legacy directory still exists: {name}")


def check_absolute_paths(errors: list[str]) -> None:
    for root in (APP_DIR / "core", APP_DIR / "features", APP_DIR / "infrastructure"):
        for path in root.rglob("*.py"):
            if ABSOLUTE_PATH.search(path.read_text(encoding="utf-8", errors="ignore")):
                errors.append(f"machine-specific absolute path: {path.relative_to(APP_DIR)}")


def check_statuses(errors: list[str]) -> None:
    for path in (APP_DIR / "features").rglob("README.md"):
        if path.parent == APP_DIR / "features":
            continue
        text = path.read_text(encoding="utf-8").lower()
        if not any(status in text for status in VALID_STATUSES):
            errors.append(f"feature status missing/invalid: {path.relative_to(APP_DIR)}")


def main() -> int:
    errors: list[str] = []
    required = [
        "README.md", "bang_ke_hach_cua_viet/FUNCTION_MAP.md", "ARCHITECTURE_RULES.md", "core/README.md",
        "features/README.md", "infrastructure/README.md", "infrastructure/database/README.md",
        "infrastructure/network/README.md", "UI/README.md", "scripts/README.md", "data/README.md",
        "templates/README.md", "tests/README.md",
    ]
    for relative in required:
        if not (APP_DIR / relative).is_file():
            errors.append(f"missing required file: {relative}")
    check_feature_readmes(errors)
    check_qmldir(errors)
    check_runtime_artifacts(errors)
    check_legacy_directories(errors)
    check_absolute_paths(errors)
    check_statuses(errors)
    if errors:
        print("Structure validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    print("Structure validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
