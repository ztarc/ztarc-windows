#!/usr/bin/env bash
# Refuse to build anything that still calls itself Pangolin.
#
# This exists because of one specific failure: a substitution in brand/rules.sed
# stops matching after an upstream bump, nothing errors, and we ship a
# ZTARC-named binary that greets people as Pangolin. An unmatched rule is
# invisible; a failed build is not.
#
# Same idea as `npm run audit:allowlist` in ztarc-console — make the drift that
# would otherwise go unnoticed into the thing that stops the build.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DST="$ROOT/build/src"

[ -d "$DST" ] || { echo "nothing staged — run scripts/rebrand.sh" >&2; exit 1; }

# Case-insensitive, because the lowercase spellings are the ones that matter
# most: named pipes and mutexes. Two clients on one machine contending for
# \\.\pipe\<name> is a real fault, not a cosmetic one.
PATTERN='pangolin|fossorial'

# Two exemptions, each for a reason, not for convenience:
#
#   github.com/fosrl/  — import paths and the newt/olm libraries. Code, not
#                        branding, and renaming them would break the build.
#   cli_installer.go   — it downloads the upstream vendor's CLI from their own
#                        GitHub releases, so their product name is the correct
#                        name to use there. The menu entry that reaches this
#                        code is hidden by brand/patches/, so none of it runs.
hits="$(grep -rEin "$PATTERN" "$DST" --include='*.go' --include='*.wxs' --include='*.manifest' --include='*.json' \
    | grep -v 'github\.com/fosrl/' \
    | grep -v '/managers/cli_installer\.go:' || true)"

if [ -n "$hits" ]; then
    echo "brand audit failed — upstream naming survived the rebrand:" >&2
    echo "$hits" | sed 's|^'"$DST"'/|  |' >&2
    echo >&2
    echo "Add a rule to brand/rules.sed, or an override, then rebuild." >&2
    exit 1
fi

echo "brand audit clean"
