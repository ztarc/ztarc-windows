#!/usr/bin/env bash
# Compile the staged tree into build/ZTARC.exe.
#
# Called by `make build` and by .github/workflows/msi.yml, so the two cannot
# compile different things. Expects scripts/rebrand.sh and scripts/audit-brand.sh
# to have run already.
#
# goversioninfo replaces upstream's rsrc: one tool for the icon, the manifest and
# the VERSIONINFO block a person sees under Properties → Details.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/build/src"

[ -f "$SRC/versioninfo.json" ] || { echo "nothing staged — run scripts/rebrand.sh" >&2; exit 1; }

echo "Compiling resources (icon, manifest, version)..."
(cd "$SRC" && go run github.com/josephspurrier/goversioninfo/cmd/goversioninfo@latest \
    -o resource.syso versioninfo.json)

echo "Building Windows executable (GUI mode)..."
(cd "$SRC" && GOOS=windows GOARCH=amd64 \
    go build -trimpath -ldflags="-s -w -H windowsgui" -o ../ZTARC.exe .)
