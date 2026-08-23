#!/usr/bin/env bash
# Regenerate brand/icons/ from the ZTARC logo kept in ztarc-website.
#
# The results are committed, so this only needs running when the logo itself
# changes. Run it from the repository root.
set -euo pipefail

LOGO_DIR="${LOGO_DIR:-../ztarc-website/logo}"
OUT="brand/icons"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

MARK="$LOGO_DIR/ztarc_logo.png"                   # 1838x1800, ember on transparent
WORDMARK="$LOGO_DIR/ztarc_logo_text_Option1.png"  # 6300x1800

# The flat slate the tray falls back to while the tunnel is down. Upstream uses
# the same mark in two colours rather than two different marks, so the shape
# stays recognisable and only its state reads differently.
DISCONNECTED="#6f7378"

for f in "$MARK" "$WORDMARK"; do
    [ -f "$f" ] || { echo "missing $f — set LOGO_DIR" >&2; exit 1; }
done
mkdir -p "$OUT"

# Two marks, not one.
#
# The full logo is a bracket enclosing the letter. At 48px and up that frame is
# a few pixels thick and reads as intended; at 16px it collapses into a smudge
# around a letter too small to survive beside it — checked on both a light and a
# dark taskbar, not assumed. So the small sizes drop the bracket and carry the
# letter alone, which is what fits in 16 pixels. Windows picks whichever size it
# needs out of the same .ico, so the two live together in one file.
#
# 84% is where the crop clears the bracket: the letter and its dot are the only
# ink left inside it.
build_ico() {  # build_ico <output> [recolour args…]
    local out="$1"; shift
    local sizes_framed="256 128 64 48"
    local sizes_glyph="32 24 16"
    local files=()

    for s in $sizes_framed; do
        magick "$MARK" -trim +repage "$@" \
            -background none -gravity center \
            -resize "$((s * 92 / 100))x$((s * 92 / 100))" -extent "${s}x${s}" \
            "$TMP/framed-$s.png"
        files+=("$TMP/framed-$s.png")
    done

    for s in $sizes_glyph; do
        magick "$MARK" -trim +repage -gravity center -crop 84%x84%+0+0 +repage \
            -trim +repage "$@" \
            -background none -gravity center \
            -resize "${s}x${s}" -extent "${s}x${s}" \
            "$TMP/glyph-$s.png"
        files+=("$TMP/glyph-$s.png")
    done

    magick "${files[@]}" "$out"
}

echo "icon-orange.ico  (connected)"
build_ico "$OUT/icon-orange.ico"

echo "icon-gray.ico    (disconnected)"
build_ico "$OUT/icon-gray.ico" -fill "$DISCONNECTED" -colorize 100

# One wordmark for both themes. Upstream ships a black and a white variant
# because its lettering is black or white; the ZTARC wordmark is entirely ember,
# which reads on either background — so the two files are identical on purpose
# rather than by oversight. The names are upstream's and must not change.
echo "word_mark_black.png / word_mark_white.png"
magick "$WORDMARK" -trim +repage \
    -background none -gravity west \
    -resize 240x60 -extent 240x60 "$OUT/word_mark_black.png"
cp "$OUT/word_mark_black.png" "$OUT/word_mark_white.png"

magick identify "$OUT"/*
