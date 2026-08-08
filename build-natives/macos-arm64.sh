#!/bin/sh
# Build libexif from unmodified source with no external runtime dependencies,
# then stage the dylib for the macos-arm64 classifier jar.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${1:-$ROOT/build/libexif-0.6.26}"
PREFIX="$ROOT/build/prefix-macos-arm64"
DEST="$ROOT/natives/src/main/resources/natives/macos-arm64"

cd "$SRC"
./configure --prefix="$PREFIX" --enable-shared --disable-static --disable-nls
make -j"$(sysctl -n hw.ncpu)"
make install

rm -rf "$DEST"
mkdir -p "$DEST"
SOURCE_LIB=$(find "$PREFIX/lib" -maxdepth 1 -type f -name 'libexif.*.dylib' | head -1)
[ -n "$SOURCE_LIB" ] || { echo "ERROR: libexif dylib was not installed"; exit 1; }
NAME=$(basename "$SOURCE_LIB")
cp "$SOURCE_LIB" "$DEST/$NAME"
chmod 644 "$DEST/$NAME"
install_name_tool -id "@loader_path/$NAME" "$DEST/$NAME"
echo "$NAME" > "$DEST/manifest.txt"

if otool -L "$DEST/$NAME" | tail -n +2 | grep -vE '@loader_path/|/usr/lib/|/System/Library/'; then
  echo "ERROR: staged dylib has a non-system dependency (above)"; exit 1
fi

cp "$SRC/COPYING" "$DEST/COPYING"
{
  echo "libexif 0.6.26 (macos-arm64), built from unmodified source"
  echo "Source: https://github.com/libexif/libexif/releases/download/v0.6.26/libexif-0.6.26.tar.bz2"
  echo "License: LGPL-2.1-or-later and LGPL-2.0-or-later (see COPYING)"
  echo "configure: --enable-shared --disable-static --disable-nls"
} > "$DEST/BUILD-INFO.txt"

echo "Staged $(ls "$DEST" | wc -l | tr -d ' ') files into $DEST"
