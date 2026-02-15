#!/bin/bash
# usage: ./create-sfx.sh msys64.tar.zst installer.exe
set -e

INPUT="$(realpath "$1")"
OUTPUT="$(realpath "$2")"
cd "$(dirname "$0")"

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
TEMP="$OUTPUT.payload"
rm -rf "$TEMP"
"./7z.exe" a "$TEMP" -ms1T -mx9 install.ps1 7z.{exe,dll}
mv -f "$INPUT" Yunzai.tar.zst
"./7z.exe" a "$TEMP" -mx0 Yunzai.tar.zst
mv -f Yunzai.tar.zst "$INPUT"
"./7z.exe" t "$TEMP"
cat "$BASE/7zSD.sfx" - "$TEMP" > "$OUTPUT" << 'EOF'
;!@Install@!UTF-8!
ExecuteFile="powershell.exe"
ExecuteParameters="-ExecutionPolicy Bypass .\install.ps1"
;!@InstallEnd@!
EOF
rm -rf 7z.{exe,dll} Yunzai.7z "$TEMP" "$BASE"