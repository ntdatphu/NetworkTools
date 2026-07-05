#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$SCRIPT_DIR/app"

if ! command -v uv >/dev/null 2>&1; then
    echo "uv is not installed or not in PATH."
    echo "Run app/setup_app.sh first, or install uv: https://docs.astral.sh/uv/getting-started/installation/"
    exit 1
fi

if [ ! -f "$APP_DIR/main.py" ]; then
    echo "Cannot find app/main.py at: $APP_DIR/main.py"
    exit 1
fi

cd "$APP_DIR"
uv run python main.py
