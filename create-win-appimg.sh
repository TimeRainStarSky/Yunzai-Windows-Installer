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

cd "$(dirname "$0")"
# 神秘 Windows 执行 runner.exe 会弹出 Gameing Overlay
cp -f runner/target/release/runner.exe "$INPUT/run.exe"
URL="https://github.com/TRSSo/win-appimg/releases/download"
CHECKSUM="7a2a2deff26c923de0bddbc72ae4f5739d1057b898a18117e41009605462d071"
NAME="win-appimg-cli-windows-x64.exe"
mkdir -p _cache
BASE="_cache/$NAME"
if [ ! -f "$BASE" ]; then
  curl --fail -L "$URL/v0.0.3/$NAME" -o "$BASE"
fi
echo "$CHECKSUM $BASE" | sha256sum --quiet --check
"$BASE" "$INPUT" "$OUTPUT" -- run.exe
