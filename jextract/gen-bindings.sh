#!/bin/sh
# Generate the libexif FFM stubs from a from-source build, then re-point the
# generated SYMBOL_LOOKUP at the runtime loader (LibExifLibs).
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
JX="$ROOT/tools/jextract-22/bin/jextract"
PREFIX="$ROOT/build/prefix-macos-arm64"
OUT="$ROOT/core/src/main/java"
PKG="io.github.ghosthack.libexifffm.libexif"
SDK=$(xcrun --show-sdk-path)

[ -x "$JX" ] || { echo "jextract not found at $JX"; exit 1; }
[ -d "$PREFIX/include" ] || { echo "run build-natives/macos-arm64.sh first"; exit 1; }

GEN_DIR="$OUT/$(echo "$PKG" | tr . /)"
rm -rf "$GEN_DIR"

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# Ask jextract which declarations came from libexif itself, then feed exactly
# that set back as an argfile. This keeps every public libexif declaration while
# excluding stdint/stdarg and platform SDK implementation details.
"$JX" --output "$TMP_DIR/probe" --dump-includes "$TMP_DIR/includes" \
  -t probe -I "$SDK/usr/include" -I "$PREFIX/include" \
  "$ROOT/jextract/libexif_api.h" >/dev/null 2>&1
awk -v prefix="$PREFIX/include/libexif/" '
  /^--include-/ && index($0, "# header: " prefix) {
    # Opaque/private records intentionally have no usable layout. Their public
    # typedefs and every function accepting their pointers remain included.
    if ($2 !~ /Private$/ && $2 != "_ExifMem" && $2 != "_ExifLog" &&
        $2 != "_ExifMnoteData" && $2 != "_ExifLoader") print $1, $2
  }
' "$TMP_DIR/includes" > "$TMP_DIR/public-api.args"

"$JX" @"$TMP_DIR/public-api.args" --output "$OUT" -t "$PKG" \
  --header-class-name LibExif \
  -I "$SDK/usr/include" \
  -I "$PREFIX/include" \
  -l ":$PREFIX/lib/libexif.dylib" \
  "$ROOT/jextract/libexif_api.h"

# libexif exposes one C `unsigned long` field. Its ABI is 32-bit on Win64 and
# 64-bit on macOS/Linux, so make that generated carrier choose at runtime.
perl "$ROOT/jextract/portable-exif-entry.pl" "$GEN_DIR/_ExifEntry.java"
# jextract leaves an extra blank line at EOF; keep checked-in output clean.
perl -0777 -pi -e 's/\n+\z/\n/' "$GEN_DIR"/*.java

# Replace the baked absolute-path lookup with the runtime loader.
perl -0777 -pi -e \
  's/static final SymbolLookup SYMBOL_LOOKUP = .*?;/static final SymbolLookup SYMBOL_LOOKUP = io.github.ghosthack.libexifffm.LibExifLibs.lookup();/s' \
  "$GEN_DIR/LibExif.java"

if grep -rn "$PREFIX" "$GEN_DIR" >/dev/null; then
  echo "ERROR: build-prefix paths survived in generated stubs"; exit 1
fi
grep -q "LibExifLibs.lookup()" "$GEN_DIR/LibExif.java" || { echo "ERROR: lookup patch did not apply"; exit 1; }

echo "Generated $(ls "$GEN_DIR" | wc -l | tr -d ' ') files into $GEN_DIR"
