#!/bin/sh
set -eu
cd -- "$(dirname -- "$0")"
exec typst compile \
  --root . \
  --font-path assets/fonts \
  --ignore-system-fonts \
  --package-path vendor/packages \
  main.typ "${1:-thesis.pdf}"
