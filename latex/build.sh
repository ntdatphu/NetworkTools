#!/usr/bin/env bash
set -e

OUT_DIR="build"
FILE="main.tex"
CLEAN=false
CLEAN_ALL=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --clean) CLEAN=true; shift ;;
    --clean-all) CLEAN_ALL=true; shift ;;
    --file) FILE="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if $CLEAN_ALL; then
  latexmk -C -outdir="$OUT_DIR" "$FILE"
  rm -rf "$OUT_DIR"
  exit 0
fi

if $CLEAN; then
  latexmk -c -outdir="$OUT_DIR" "$FILE"
  exit 0
fi

mkdir -p "$OUT_DIR"

if [[ ! -f "$FILE" ]]; then
  echo "Không tìm thấy file: $FILE"
  exit 1
fi

echo "Building: $FILE"

latexmk -xelatex -interaction=nonstopmode -halt-on-error -outdir="$OUT_DIR" "$FILE"

PDF_NAME="$(basename "${FILE%.tex}").pdf"
PDF_PATH="$OUT_DIR/$PDF_NAME"

if [[ -f "$PDF_PATH" ]]; then
  cp "$PDF_PATH" "./$PDF_NAME"
  echo "Done: $PDF_NAME"
else
  echo "Không tìm thấy PDF: $PDF_PATH"
  exit 1
fi