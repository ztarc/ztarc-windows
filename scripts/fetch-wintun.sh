#!/usr/bin/env bash
# Put WireGuard LLC's signed wintun.dll where the installer expects it.
#
# Deliberately not vendored. It is a third-party signed binary that ends up in
# Program Files on somebody else's machine, so it comes from its own source with
# its hash checked, every time, rather than from whichever developer's disk
# happened to have a copy.
#
# Upstream's repo omits it for the same reason; upstream/dll/ holds only a README.
set -euo pipefail

VERSION="0.14.1"
SHA256="07c256185d6ee3652e09fa55c0b673e2624b565e02c4b9091c79ca7d2f24ef51"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/upstream/dll"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Fetching wintun $VERSION..."
curl -fsSL -o "$TMP/wintun.zip" "https://www.wintun.net/builds/wintun-$VERSION.zip"

echo "$SHA256  $TMP/wintun.zip" | sha256sum -c - || {
    echo "wintun archive does not match the expected hash — refusing to use it." >&2
    exit 1
}

# This runs on Fedora and on a GitHub windows runner, and they do not agree on
# which unzip exists: Git Bash ships no `unzip`, the runner image ships 7-Zip,
# Fedora ships the reverse. Pick whichever is there and say so if neither is.
# The licence comes out with the DLL, not as an afterthought. Wintun's prebuilt
# binaries are proprietary and its terms forbid stripping its notices, so the
# file that states them travels with the binary it covers — into this repo, and
# from there into the installer.
mkdir -p "$DEST" "$ROOT/third-party"
if command -v unzip >/dev/null; then
    unzip -joq "$TMP/wintun.zip" "wintun/bin/amd64/wintun.dll" -d "$DEST"
    unzip -joq "$TMP/wintun.zip" "wintun/LICENSE.txt" -d "$TMP"
elif command -v 7z >/dev/null; then
    7z e -y -o"$DEST" "$TMP/wintun.zip" "wintun/bin/amd64/wintun.dll" >/dev/null
    7z e -y -o"$TMP" "$TMP/wintun.zip" "wintun/LICENSE.txt" >/dev/null
else
    echo "neither unzip nor 7z is available to extract the archive" >&2
    exit 1
fi
mv -f "$TMP/LICENSE.txt" "$ROOT/third-party/wintun-LICENSE.txt"

[ -f "$DEST/wintun.dll" ] || { echo "wintun.dll was not extracted" >&2; exit 1; }
[ -f "$ROOT/third-party/wintun-LICENSE.txt" ] || { echo "wintun LICENSE.txt was not extracted" >&2; exit 1; }
echo "→ $DEST/wintun.dll"
echo "→ $ROOT/third-party/wintun-LICENSE.txt"
