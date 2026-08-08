#!/bin/sh
# Build libexif from unmodified source and stage the linux-x64 shared library.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${1:-$ROOT/build/libexif-0.6.26}"
PREFIX="$ROOT/build/prefix-linux-x64"
DEST="$ROOT/natives/src/main/resources/natives/linux-x64"

cd "$SRC"
./configure --prefix="$PREFIX" --enable-shared --disable-static --disable-nls
make -j"$(getconf _NPROCESSORS_ONLN)"
make install

rm -rf "$DEST"
mkdir -p "$DEST"
SOURCE_LIB=$(find "$PREFIX/lib" -maxdepth 1 -type f -name 'libexif.so.*' | head -1)
[ -n "$SOURCE_LIB" ] || { echo "ERROR: libexif shared library was not installed"; exit 1; }
NAME=$(basename "$SOURCE_LIB")
cp "$SOURCE_LIB" "$DEST/$NAME"
chmod 644 "$DEST/$NAME"
echo "$NAME" > "$DEST/manifest.txt"

if ldd "$DEST/$NAME" | grep '=>' | grep -vE 'libc\.so|libm\.so|ld-linux'; then
  echo "ERROR: staged library has a non-system dependency (above)"; exit 1
fi

cp "$SRC/COPYING" "$DEST/COPYING"
{
  echo "libexif 0.6.26 (linux-x64), built from unmodified source"
  echo "Source: https://github.com/libexif/libexif/releases/download/v0.6.26/libexif-0.6.26.tar.bz2"
  echo "License: LGPL-2.1-or-later and LGPL-2.0-or-later (see COPYING)"
  echo "configure: --enable-shared --disable-static --disable-nls"
} > "$DEST/BUILD-INFO.txt"

echo "Staged $(ls "$DEST" | wc -l | tr -d ' ') files into $DEST"
