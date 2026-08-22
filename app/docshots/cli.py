"""Command-line interface for the NetworkTools documentation renderer."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import Sequence

from .environment import configure_qt_environment
from .shots import SHOT_REGISTRY, resolve_shots


APP_DIR = Path(__file__).resolve().parents[1]
REPOSITORY_ROOT = APP_DIR.parent
DEFAULT_OUTPUT_DIR = REPOSITORY_ROOT / "book" / "figures" / "gui"


def _positive_int(value: str) -> int:
    parsed = int(value)
    if parsed <= 0:
        raise argparse.ArgumentTypeError("must be greater than zero")
    return parsed


def _positive_scale(value: str) -> float:
    parsed = float(value)
    if parsed <= 0:
        raise argparse.ArgumentTypeError("must be greater than zero")
    return parsed


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Render deterministic NetworkTools QML screenshots as PNG files."
    )
    parser.add_argument(
        "shot",
        choices=(*SHOT_REGISTRY.keys(), "all"),
        help="registered screenshot name, or 'all'",
    )
    parser.add_argument("--width", type=_positive_int, default=1600)
    parser.add_argument("--height", type=_positive_int, default=1000)
    parser.add_argument("--scale", type=_positive_scale, default=2.0)
    parser.add_argument("--theme", choices=("light", "dark"), default="light")
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=DEFAULT_OUTPUT_DIR,
        help=f"PNG destination (default: {DEFAULT_OUTPUT_DIR})",
    )
    return parser


def ensure_output_directory(path: Path) -> Path:
    resolved = path.expanduser().resolve()
    resolved.mkdir(parents=True, exist_ok=True)
    return resolved


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    configure_qt_environment()

    # Qt and main.py must only be imported after the headless/DPI variables exist.
    from .runtime import DocshotError, RenderRequest, render_shot

    output_dir = ensure_output_directory(args.output_dir)
    request = RenderRequest(
        width=args.width,
        height=args.height,
        scale=args.scale,
        theme=args.theme,
        output_dir=output_dir,
    )
    try:
        for shot in resolve_shots(args.shot):
            result = render_shot(shot, request)
            print(f"{shot.name}: {result.path} ({result.width}x{result.height})")
    except (DocshotError, OSError, ValueError) as exc:
        print(f"docshots: {exc}", file=sys.stderr)
        return 1
    return 0


__all__ = [
    "APP_DIR",
    "DEFAULT_OUTPUT_DIR",
    "REPOSITORY_ROOT",
    "build_parser",
    "ensure_output_directory",
    "main",
]
