#!/bin/bash
# usage: ./create-sfx.sh /some/path/to/msys64 installer.exe
set -e

INPUT="$(realpath "$1")"
OUTPUT="$(realpath "$2")"
cd "$(dirname "$0")"

# Download and extract https://github.com/mcmilk/7-Zip-zstd
CHECKSUM="d140094f0277b49a4e895159bd734da03cd2b60fb73a65e4151edfedc612981e"
NAME="7z25.01-zstd-x64"
mkdir -p _cache
BASE="_cache/$NAME"
if [ ! -f "$BASE.exe" ]; then
  curl --fail -L "https://github.com/mcmilk/7-Zip-zstd/releases/download/v25.01-v1.5.7-R1/$NAME.exe" -o "$BASE.exe"
fi
echo "$CHECKSUM $BASE.exe" | sha256sum --quiet --check
7z e -o"$BASE" "_cache/$NAME.exe"
mv -f "$BASE"/7z.{exe,dll} .
rm -rf "$BASE"

# Create 7-zip
DIR="$(pwd)"
cd "$INPUT"
"$DIR/7z.exe" a "$DIR/Yunzai.7z" -ms1T -m0=zstd -mx22 *
cd "$DIR"
./7z.exe t Yunzai.7z

CHECKSUM="cbc3babd589d971e45971d787ff100be8aaa5eab15b2694497ec3e447009e1f2"
NAME="lzma2501"
BASE="_cache/$NAME"
if [ ! -f "$BASE.7z" ]; then
  curl --fail -L "https://www.7-zip.org/a/$NAME.7z" -o "$BASE.7z"
fi
echo "$CHECKSUM $BASE.7z" | sha256sum --quiet --check
7z x -o"$BASE" "$BASE.7z"

# Create SFX installer
TEMP="$OUTPUT.payload"
rm -rf "$TEMP"
"$BASE/bin/7zr.exe" a "$TEMP" -ms1T -mx9 install.ps1 7z.{exe,dll}
"$BASE/bin/7zr.exe" a "$TEMP" -mx0 Yunzai.7z
"$BASE/bin/7zr.exe" t "$TEMP"
cat "$BASE/bin/7zSD.sfx" - "$TEMP" > "$OUTPUT" << 'EOF'
;!@Install@!UTF-8!
ExecuteFile="powershell.exe"
ExecuteParameters="./install.ps1"
;!@InstallEnd@!
EOF
rm -rf 7z.exe Yunzai.7z "$TEMP" "$BASE"