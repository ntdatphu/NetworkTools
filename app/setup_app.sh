#!/usr/bin/env bash
set -euo pipefail

PYTHON_VERSION="${PYTHON_VERSION:-3.11}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$SCRIPT_DIR"

if ! command -v uv >/dev/null 2>&1; then
    echo "uv is not installed or not in PATH."
    echo "Install uv first: https://docs.astral.sh/uv/getting-started/installation/"
    exit 1
fi

if [ ! -f "$APP_DIR/pyproject.toml" ]; then
    echo "Cannot find app/pyproject.toml at: $APP_DIR"
    exit 1
fi

cd "$APP_DIR"

echo "Using Python $PYTHON_VERSION"
echo "Creating virtual environment in .venv ..."
uv venv .venv --python "$PYTHON_VERSION"

echo "Installing dependencies from pyproject.toml ..."
uv sync

echo
echo "Setup complete."
echo "Run the app with:"
echo "  uv run python main.py"
