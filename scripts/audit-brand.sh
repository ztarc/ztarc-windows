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

# Note on scope: only source and packaging files are scanned. LICENSE.txt and
# NOTICE.txt carry the upstream copyright holder's name because AGPL-3 requires
# that attribution — removing it would be the violation, not the fix.

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

# The mirror image of the check above.
#
# Absence of the upstream name proves nothing on its own: a substitution that
# targets a *behaviour* rather than a name can stop matching without leaving any
# forbidden word behind. The tree still compiles, still says ZTARC everywhere,
# and quietly loses the change. So each such rule is paired with an assertion
# that its result is actually present, in the file it was meant to land in.
#
# Format: <path under build/src>|<extended regex that must match>|<what breaks without it>
# Matched loosely on purpose — gofmt's column alignment is not something a
# correctness check should depend on.
REQUIRED=(
    "config/config.go|return resolveIconsPath\(\)|GetIconsPath would look only in Program Files, so a copied .exe shows a blank tray icon"
    "config/config.go|AppName[[:space:]]+= \"ZTARC\"|the Windows service name, config folder and tunnel adapter are all derived from AppName"
    "config/config.go|DefaultHostname[[:space:]]+= \"https://console.ztarc.io\"|the login window would default to the upstream vendor's hosted service"
    # Results of brand/patches/. `git apply` was found to exit 0 while changing
    # nothing — build/src sits inside this work tree, so it resolved paths
    # against the repository root — and every build since had shipped the cloud
    # button and the dead legal links. Nothing else noticed for days.
    "ui/login_window.go|selfHostedURL := config.DefaultHostname|the server field would be empty although the console is the only way in"
    "ui/preferences/about_tab.go|sourceLinkLabel|the About tab would not link to the source, which AGPL-3 obliges us to offer"
    "ui/tray.go|cliInstallAction.SetVisible\(false\)|the tray would offer to install the upstream vendor's CLI"
    "ui/tray.go|sourceAction|the tray menu would not link to the source, which AGPL-3 obliges us to offer"
)

# And the other half of the same check: results that must be ABSENT. A patch
# that half-applies, or a deletion that stops matching, leaves the thing it was
# supposed to remove.
# Format: <path under build/src>|<extended regex that must NOT match>|<why it must go>
FORBIDDEN=(
    "ui/login_window.go|Terms of Service|ztarc.io has no such page; the link 404s"
    "ui/preferences/about_tab.go|Privacy Policy|ztarc.io has no such page; the link 404s"
    "ui/tray.go|Terms of Service|ztarc.io has no such page; the tray entry would go nowhere"
    "ui/login_window.go|cloudButton.SetVisible\(showHostingSelection\)|there is no ZTARC hosted service to offer"
)

missing=""
for entry in "${REQUIRED[@]}"; do
    IFS='|' read -r file needle why <<< "$entry"
    if ! grep -qE -- "$needle" "$DST/$file" 2>/dev/null; then
        missing="$missing\n  $file: expected \"$needle\"\n      without it, $why"
    fi
done

for entry in "${FORBIDDEN[@]}"; do
    IFS='|' read -r file needle why <<< "$entry"
    if grep -qE -- "$needle" "$DST/$file" 2>/dev/null; then
        missing="$missing\n  $file: still contains \"$needle\"\n      it must go because $why"
    fi
done

if [ -n "$missing" ]; then
    echo "brand audit failed — a rule or patch stopped taking effect:" >&2
    printf '%b\n' "$missing" >&2
    echo >&2
    echo "Upstream probably moved the code. Update brand/rules.sed or the patch." >&2
    exit 1
fi

echo "brand audit clean"
