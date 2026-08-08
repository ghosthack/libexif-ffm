#!/bin/sh
# Run from an MSYS2 MINGW64 shell. Prerequisites:
#   mingw-w64-x86_64-toolchain make diffutils curl tar bzip2
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${1:-$ROOT/build/libexif-0.6.26}"
PREFIX="$ROOT/build/prefix-windows-x64"
DEST="$ROOT/natives/src/main/resources/natives/windows-x64"

cd "$SRC"
./configure --prefix="$PREFIX" --host=x86_64-w64-mingw32 \
  --enable-shared --disable-static --disable-nls
make -j"$(nproc)"
make install

rm -rf "$DEST"
mkdir -p "$DEST"
SOURCE_LIB=$(find "$PREFIX/bin" -maxdepth 1 -type f -iname '*exif*.dll' | head -1)
[ -n "$SOURCE_LIB" ] || { echo "ERROR: libexif DLL was not installed"; exit 1; }
NAME=$(basename "$SOURCE_LIB")
cp "$SOURCE_LIB" "$DEST/$NAME"
chmod 644 "$DEST/$NAME"
echo "$NAME" > "$DEST/manifest.txt"

if objdump -p "$DEST/$NAME" | sed -n 's/.*DLL Name: //p' \
    | grep -viE '^(KERNEL32|msvcrt|ucrtbase|api-ms-win-|VCRUNTIME)' ; then
  echo "ERROR: staged DLL has a non-system dependency (above)"; exit 1
fi

cp "$SRC/COPYING" "$DEST/COPYING"
{
  echo "libexif 0.6.26 (windows-x64), built from unmodified source"
  echo "Source: https://github.com/libexif/libexif/releases/download/v0.6.26/libexif-0.6.26.tar.bz2"
  echo "License: LGPL-2.1-or-later and LGPL-2.0-or-later (see COPYING)"
  echo "configure: --host=x86_64-w64-mingw32 --enable-shared --disable-static --disable-nls"
} > "$DEST/BUILD-INFO.txt"

echo "Staged $(ls "$DEST" | wc -l | tr -d ' ') files into $DEST"
