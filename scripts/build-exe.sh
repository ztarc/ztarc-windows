#!/usr/bin/env bash
# Compile the staged tree into build/ZTARC.exe.
#
# Called by `make build` and by .github/workflows/msi.yml, so the two cannot
# compile different things. Expects scripts/rebrand.sh and scripts/audit-brand.sh
# to have run already.
#
# Wails generates icon, manifest and VERSIONINFO in a single resource object.
# Separate resource objects cannot be linked: Go permits only one .rsrc section.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/build/src"

[ -f "$SRC/versioninfo.json" ] || { echo "nothing staged — run scripts/rebrand.sh" >&2; exit 1; }

echo "Building embedded frontend..."
(cd "$SRC/ui/frontend" && npm ci && npm run build)

echo "Compiling icon, manifest and version resources..."
(cd "$SRC" && CGO_ENABLED=0 go run github.com/wailsapp/wails/v3/cmd/wails3@v3.0.0-beta.26 generate syso \
    -manifest ztarc.manifest -icon icons/icon-orange.ico -info versioninfo.json -arch amd64 -out rsrc.syso)

echo "Building Windows executable (GUI mode)..."
(cd "$SRC" && GOOS=windows GOARCH=amd64 \
    go build -tags production -trimpath -ldflags="-s -w -H windowsgui" -o ../ZTARC.exe .)
