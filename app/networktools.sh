#!/usr/bin/env sh
set -eu

APP_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$APP_ROOT"

require_uv() {
    if ! command -v uv >/dev/null 2>&1; then
        echo "ERROR: uv is not installed or is not available in PATH." >&2
        echo "Install uv from https://docs.astral.sh/uv/ and run this script again." >&2
        exit 1
    fi
    echo "uv: $(uv --version)"
}

sync_environment() {
    require_uv
    echo "Synchronizing application and Cython build dependencies..."
    uv sync --extra speed
}

build_cython() {
    require_uv
    echo "Building optional Cython acceleration modules..."
    uv run --extra speed python setup_cython.py build_ext --inplace --force
    check_cython
}

check_cython() {
    require_uv
    uv run --extra speed python -c \
        "from pathlib import Path; from features.devices.sync import _engine; p=Path(_engine.__file__); print(f'sync engine: {p}'); raise SystemExit(0 if p.suffix in {'.so', '.pyd'} else 1)"
}

run_app() {
    require_uv
    echo "Starting NetworkTools..."
    uv run --extra speed python main.py
}

setup_all() {
    sync_environment
    build_cython
}

show_menu() {
    echo
    echo "NetworkTools"
    echo "  1) Sync dependencies"
    echo "  2) Build and verify Cython"
    echo "  3) Full setup (sync + Cython)"
    echo "  4) Check Cython status"
    echo "  5) Run application"
    echo "  6) Full setup and run"
    echo "  0) Exit"
    printf "Select: "
    read -r choice
    case "$choice" in
        1) sync_environment ;;
        2) build_cython ;;
        3) setup_all ;;
        4) check_cython ;;
        5) run_app ;;
        6) setup_all; run_app ;;
        0) exit 0 ;;
        *) echo "Invalid selection." >&2; exit 2 ;;
    esac
}

case "${1:-menu}" in
    sync) sync_environment ;;
    build) build_cython ;;
    setup) setup_all ;;
    check) check_cython ;;
    run) run_app ;;
    all) setup_all; run_app ;;
    menu) show_menu ;;
    *)
        echo "Usage: $0 [sync|build|setup|check|run|all]" >&2
        exit 2
        ;;
esac
