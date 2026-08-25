#!/usr/bin/env bash
# Stage a ZTARC-branded copy of the upstream client.
#
# upstream/ is never written to. Everything happens in build/src, which is
# disposable, so `git -C upstream status` stays clean and an upstream bump is a
# one-line change instead of a merge against our own edits.
#
# Order is load-bearing:
#
#   1. patches  — context must match pristine upstream, so they run first
#   2. sed      — string substitutions, indifferent to line numbers
#   3. overrides— whole files that are ours outright
#   4. assets   — icons, and the version stamped into the installer
#
# Run scripts/audit-brand.sh afterwards; it is what turns a rule that silently
# stopped matching into a failed build.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/upstream"
DST="$ROOT/build/src"

[ -f "$SRC/go.mod" ] || {
    echo "upstream/ is empty — run: git submodule update --init" >&2
    exit 1
}

rm -rf "$DST"
mkdir -p "$(dirname "$DST")"
cp -a "$SRC" "$DST"
rm -rf "$DST/.git" "$DST/build" "$DST/rsrc.syso"

# 1. Structural changes.
for patch in "$ROOT"/brand/patches/*.patch; do
    [ -e "$patch" ] || continue
    echo "patch  $(basename "$patch")"
    git -C "$DST" apply --unsafe-paths --directory=. -p1 "$patch"
done

# 2. String substitutions across every Go file.
echo "sed    brand/rules.sed"
find "$DST" -name '*.go' -print0 | xargs -0 sed -i -f "$ROOT/brand/rules.sed"

# 3. Files that are ours outright.
echo "override"
cp "$ROOT/brand/overrides/version/version.go"     "$DST/version/version.go"
cp "$ROOT/brand/overrides/updater/constants.go"   "$DST/updater/constants.go"
cp "$ROOT/brand/overrides/config/icons_path.go"   "$DST/config/icons_path.go"
cp "$ROOT/brand/overrides/ztarc.manifest"         "$DST/ztarc.manifest"
rm -f "$DST/pangolin.manifest" "$DST/pangolin.wxs"

# 4. Assets, and the version the installer must agree with.
echo "assets"
cp "$ROOT"/brand/icons/* "$DST/icons/"

# The version lives in exactly one place — version.go — and is read back out
# here so the installer and the executable's own properties cannot drift from it.
version="$(sed -n 's/.*Upstream[[:space:]]*=[[:space:]]*"\([0-9.]*\)".*/\1/p' "$ROOT/brand/overrides/version/version.go")"
build="$(sed -n 's/.*Build[[:space:]]*=[[:space:]]*"\([0-9]*\)".*/\1/p' "$ROOT/brand/overrides/version/version.go")"
full="$version.$build"
[ -n "$version" ] && [ -n "$build" ] || { echo "cannot read version from version.go" >&2; exit 1; }

sed "s|@@VERSION@@|$full|" "$ROOT/brand/overrides/ztarc.wxs" > "$DST/ztarc.wxs"

# VERSIONINFO for the .exe itself: the number a person finds under Properties →
# Details when they right-click the file, which is the first thing anyone checks
# when asked "which build are you running?".
IFS=. read -r major minor patchv rev <<< "$full"
cat > "$DST/versioninfo.json" <<JSON
{
  "FixedFileInfo": {
    "FileVersion":    {"Major": $major, "Minor": $minor, "Patch": $patchv, "Build": $rev},
    "ProductVersion": {"Major": $major, "Minor": $minor, "Patch": $patchv, "Build": $rev},
    "FileFlagsMask": "3f", "FileFlags": "00", "FileOS": "040004",
    "FileType": "01", "FileSubType": "00"
  },
  "StringFileInfo": {
    "CompanyName":      "ZTARC",
    "FileDescription":  "ZTARC",
    "FileVersion":      "$full",
    "InternalName":     "ZTARC.exe",
    "LegalCopyright":   "© ZTARC",
    "OriginalFilename": "ZTARC.exe",
    "ProductName":      "ZTARC",
    "ProductVersion":   "$full"
  },
  "VarFileInfo": {"Translation": {"LangID": "0409", "CharsetID": "04B0"}},
  "IconPath":     "icons/icon-orange.ico",
  "ManifestPath": "ztarc.manifest"
}
JSON

echo "staged  $DST  (ZTARC $full)"
