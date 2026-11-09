#!/usr/bin/env bash
# Makes the release zip for CurseForge: dist/Healpad-<version>.zip.
# The zip holds one folder, Healpad, with the addon and the license.
#   scripts/package.sh
set -euo pipefail
cd "$(dirname "$0")/.."
toc=addon/Healpad/Healpad.toc
version=$(sed -n 's/^## Version: //p' "$toc" | tr -d '\r')
if [ -z "$version" ]; then
  echo "error: no version in $toc" >&2
  exit 1
fi
# Every file that the TOC loads must be in the zip.
for file in $(grep -v '^#' "$toc" | tr -d '\r' | grep .); do
  if [ ! -f "addon/Healpad/$file" ]; then
    echo "error: the TOC loads $file, but it is not there" >&2
    exit 1
  fi
done
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cp -r addon/Healpad "$work/"
cp LICENSE "$work/Healpad/"
mkdir -p dist
out="$(pwd)/dist/Healpad-$version.zip"
rm -f "$out"
(cd "$work" && python3 -m zipfile -c "$out" Healpad)
echo "packaged $version in $out"
