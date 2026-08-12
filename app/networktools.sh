#!/usr/bin/env sh
set -eu

APP_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
TERMINAL_SOURCE="$APP_ROOT/vendor/alacritty"
TERMINAL_BINARY="$TERMINAL_SOURCE/target/release/networktools-terminal"
cd "$APP_ROOT"

prepare_environment() {
    expected_venv="$APP_ROOT/.venv"
    if [ -n "${VIRTUAL_ENV:-}" ] && [ "$VIRTUAL_ENV" != "$expected_venv" ]; then
        echo "Ignoring unrelated active virtual environment: $VIRTUAL_ENV"
        unset VIRTUAL_ENV
    fi

    if ! command -v cargo >/dev/null 2>&1; then
        rust_env="${CARGO_HOME:-${HOME:-}/.cargo}/env"
        if [ -f "$rust_env" ]; then
            # rustup installs this POSIX environment file for non-interactive shells.
            . "$rust_env"
        fi
    fi
}

prepare_environment

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

disable_cython_extension() {
    for extension in \
        features/devices/sync/_engine*.so \
        features/devices/sync/_engine*.pyd
    do
        [ -e "$extension" ] || continue
        mv -f -- "$extension" "$extension.disabled"
        echo "Disabled unusable extension: $extension"
    done
}

build_cython_optional() {
    if build_cython; then
        return 0
    fi

    echo >&2
    echo "WARNING: Optional Cython acceleration could not be built or loaded." >&2
    echo "NetworkTools will use the built-in Python sync engine instead." >&2
    disable_cython_extension
    uv run --extra speed python -c \
        "from pathlib import Path; from features.devices.sync import _engine; p=Path(_engine.__file__); print(f'sync engine fallback: {p}'); raise SystemExit(0 if p.suffix == '.py' else 1)"
}

check_cython() {
    require_uv
    uv run --extra speed python -c \
        "from pathlib import Path; from features.devices.sync import _engine; p=Path(_engine.__file__); print(f'sync engine: {p}'); raise SystemExit(0 if p.suffix in {'.so', '.pyd'} else 1)"
}

check_terminal() {
    configured=${NETWORKTOOLS_TERMINAL_BINARY:-}
    if [ -n "$configured" ]; then
        if [ ! -f "$configured" ]; then
            echo "ERROR: NETWORKTOOLS_TERMINAL_BINARY does not point to a file: $configured" >&2
            return 1
        fi
        if [ ! -x "$configured" ]; then
            echo "ERROR: NetworkTools Terminal is not executable: $configured" >&2
            return 1
        fi
        echo "NetworkTools Terminal: $configured"
        return 0
    fi

    discovered=$(command -v networktools-terminal 2>/dev/null || true)
    if [ -n "$discovered" ]; then
        echo "NetworkTools Terminal: $discovered"
        return 0
    fi

    if [ -x "$TERMINAL_BINARY" ]; then
        echo "NetworkTools Terminal: $TERMINAL_BINARY"
        return 0
    fi

    echo "ERROR: NetworkTools Terminal companion was not found." >&2
    echo "Build/install the Alacritty fork as 'networktools-terminal', or set:" >&2
    echo "  NETWORKTOOLS_TERMINAL_BINARY=/absolute/path/to/the/binary" >&2
    return 1
}

build_terminal() {
    if [ ! -f "$TERMINAL_SOURCE/Cargo.toml" ]; then
        echo "ERROR: Alacritty source was not found at $TERMINAL_SOURCE" >&2
        return 1
    fi
    if ! command -v cargo >/dev/null 2>&1; then
        echo "ERROR: Rust/Cargo is required to build NetworkTools Terminal." >&2
        echo "Install Rust from https://rustup.rs/ and run setup again." >&2
        return 1
    fi
    if command -v pkg-config >/dev/null 2>&1 \
        && ! pkg-config --exists fontconfig freetype2; then
        echo "ERROR: Native font development libraries are missing." >&2
        echo "On Fedora, install them with:" >&2
        echo "  sudo dnf install cmake freetype-devel fontconfig-devel libxcb-devel libxkbcommon-devel gcc-c++" >&2
        return 1
    fi
    echo "cargo: $(cargo --version)"
    echo "Building NetworkTools Terminal (release)..."
    cargo build \
        --release \
        --manifest-path "$TERMINAL_SOURCE/Cargo.toml" \
        --bin networktools-terminal
    check_terminal
}

build_terminal_optional() {
    if build_terminal; then
        return 0
    fi
    echo >&2
    echo "WARNING: NetworkTools Terminal could not be built." >&2
    echo "The main application can still run without device terminal windows." >&2
    return 0
}

check_terminal_optional() {
    if check_terminal; then
        return 0
    fi

    echo >&2
    echo "WARNING: The main NetworkTools app is ready, but device terminals" >&2
    echo "will stay unavailable until the companion binary is configured." >&2
    return 0
}

run_app() {
    require_uv
    echo "Starting NetworkTools..."
    uv run --extra speed python main.py
}

setup_all() {
    sync_environment
    build_cython_optional
    build_terminal_optional
    check_terminal_optional
}

show_menu() {
    echo
    echo "NetworkTools"
    echo "  1) Sync dependencies"
    echo "  2) Build and verify Cython"
    echo "  3) Full setup (sync + optional Cython + terminal build)"
    echo "  4) Check Cython status"
    echo "  5) Run application"
    echo "  6) Full setup and run"
    echo "  7) Check NetworkTools Terminal"
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
        7) check_terminal ;;
        0) exit 0 ;;
        *) echo "Invalid selection." >&2; exit 2 ;;
    esac
}

case "${1:-menu}" in
    sync) sync_environment ;;
    build) build_cython ;;
    setup) setup_all ;;
    check) check_cython ;;
    terminal-build) build_terminal ;;
    terminal-check) check_terminal ;;
    run) run_app ;;
    all) setup_all; run_app ;;
    menu) show_menu ;;
    *)
        echo "Usage: $0 [sync|build|setup|check|terminal-build|terminal-check|run|all]" >&2
        exit 2
        ;;
esac
