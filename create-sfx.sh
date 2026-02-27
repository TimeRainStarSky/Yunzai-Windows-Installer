#!/bin/bash
# usage: ./create-sfx.sh pkgdir pkgname installer.exe
set -e

INPUT="$(realpath "$1")"
PKGNAME="$2"
OUTPUT="$(realpath "$3")"
cd "$(dirname "$0")"
DIR="$PWD"

# Download and extract https://github.com/mcmilk/7-Zip-zstd
URL="https://github.com/mcmilk/7-Zip-zstd/releases/download"
CHECKSUM="5a55a8b6abb09d4b5ddd64c95f22a5270cb46752fb7a5353073508922b141596"
NAME="7z25.01-zstd-x64"
mkdir -p _cache
BASE="_cache/$NAME"
if [ ! -f "$BASE.exe" ]; then
  curl --fail -L "$URL/v25.01-v1.5.7-R4/$NAME.exe" -o "$BASE.exe"
fi
echo "$CHECKSUM $BASE.exe" | sha256sum --quiet --check
7z e -o"$BASE" "_cache/$NAME.exe"
mv -f "$BASE"/7z.{exe,dll} .
rm -rf "$BASE"

CHECKSUM="b3a748d6863d5f34a927d1a2bc562afc916780498cc8cbe559848b8bd1087e28"
NAME="Sfx-Setup-x64"
BASE="_cache/$NAME"
if [ ! -f "$BASE.7z" ]; then
  curl --fail -L "$URL/v25.01-v1.5.7-R3/$NAME.7z" -o "$BASE.7z"
fi
echo "$CHECKSUM $BASE.7z" | sha256sum --quiet --check
7z x -o"$BASE" "$BASE.7z"

# Create SFX installer
cd "$INPUT"
"$DIR/7z.exe" a "$DIR/$PKGNAME" -ms1T -m0=zstd -mx22 *
cd "$DIR"
TEMP="$OUTPUT.payload"
rm -rf "$TEMP"
"./7z.exe" a "$TEMP" -ms1T -m0=zstd -mx22 install.ps1 7z.{exe,dll}
"./7z.exe" a "$TEMP" -mx0 "$PKGNAME"
"./7z.exe" t "$TEMP"
cat "$BASE/7zSD.sfx" - "$TEMP" > "$OUTPUT" << 'EOF'
;!@Install@!UTF-8!
ExecuteFile="powershell.exe"
ExecuteParameters="-ExecutionPolicy Bypass .\install.ps1"
;!@InstallEnd@!
EOF
rm -rf 7z.{exe,dll} "$TEMP" "$PKGNAME" "$BASE"