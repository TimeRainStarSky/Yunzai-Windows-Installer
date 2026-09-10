#!/bin/bash
# usage: ./create-win-appimg.sh pkgdir win-appimg.exe
set -e

INPUT="$(realpath "$1")"
OUTPUT="$(realpath "$2")"
cd "$INPUT"

sed -i '/if \[ ! -d "${HOME}" \]; then/,/^fi$/c\
if [ ! -d "${HOME}" ]; then\
  HOME="$(cygpath -u "$USERPROFILE")"\
fi' etc/profile
rm -rf etc/post-install/*mtab*
cmd //c msys2_shell.cmd -defterm -here -no-start -ucrt64 -c "pacman -Scc --noconfirm"
mv -f ../start.cmd .

cd "$(dirname "$0")"
URL="https://github.com/TRSSo/win-appimg/releases/download"
CHECKSUM="c8475325a17f8e2da109ad4bfeef724349a8344c43b7708533ecc26044a452ba"
NAME="win-appimg-cli-windows-x64.exe"
mkdir -p _cache
BASE="_cache/$NAME"
if [ ! -f "$BASE" ]; then
  curl --fail -L "$URL/v0.0.2/$NAME" -o "$BASE"
fi
echo "$CHECKSUM $BASE" | sha256sum --quiet --check
"$BASE" "$INPUT" "$OUTPUT" --external -- cmd //c start "" {}\\start.cmd
