#!/usr/bin/env bash
set -euo pipefail
mkdir -p build
typst compile main.typ build/networktools.pdf
echo "Built: build/networktools.pdf"
