#!/bin/bash
# Build the Markdown preview renderer bundle into Resources/Preview.
#
# The built output IS committed — the app build never needs Node. Re-run this
# script (needs node + npm) after changing anything under scripts/preview-src.
set -euo pipefail

SRC="$(cd "$(dirname "$0")/preview-src" && pwd)"
OUT="$(cd "$SRC/../.." && pwd)/Resources/Preview"

if [ ! -d "$SRC/node_modules" ]; then
  echo "Installing renderer dependencies…"
  (cd "$SRC" && npm install --no-audit --no-fund)
fi

mkdir -p "$OUT"
rm -rf "${OUT:?}"/*

ESBUILD="$SRC/node_modules/.bin/esbuild"

# JS: one classic-script bundle. Dynamic imports (Mermaid's lazy diagram
# loaders) are inlined because splitting is off.
"$ESBUILD" "$SRC/src/index.js" \
  --bundle --minify --format=iife \
  --target=safari16 \
  --outfile="$OUT/preview.js" \
  --log-level=warning

# CSS: bundles our theme + KaTeX. Only woff2 fonts are emitted (they are the
# first source in every KaTeX @font-face, so the fallbacks never load).
"$ESBUILD" "$SRC/src/preview.css" \
  --bundle --minify \
  --outfile="$OUT/preview.css" \
  --loader:.woff2=file --loader:.woff=empty --loader:.ttf=empty \
  --asset-names="fonts/[name]" \
  --log-level=warning

cp "$SRC/src/preview.html" "$OUT/preview.html"

echo "Built $(du -sh "$OUT" | cut -f1) into $OUT"
ls -lh "$OUT"
