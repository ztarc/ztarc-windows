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

# Exemptions, each with a reason:
#
#   github.com/fosrl/  — import paths and the newt/olm libraries. Code, not
#                        branding, and renaming them would break the build.
#   CLIWindow.tsx     — the unreachable UI for that same upstream CLI.
#   cli_installer.go   — it downloads the upstream vendor's CLI from their own
#                        GitHub releases, so their product name is the correct
#                        name to use there. The menu entry that reaches this
#                        code is hidden by brand/patches/, so none of it runs.
hits="$(grep -rEin "$PATTERN" "$DST" --exclude-dir=node_modules --exclude-dir=dist --include='*.go' --include='*.wxs' --include='*.manifest' --include='*.json' --include='*.ts' --include='*.tsx' --include='*.css' --include='*.html' \
    | grep -v 'github\.com/fosrl/' \
    | grep -v '/managers/cli_installer\.go:' \
    | grep -v '/ui/frontend/src/cli/CLIWindow\.tsx:' || true)"

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
    "config/config.go|return resolveIconsPath\(\)|legacy icon lookups would lose the adjacent-file fallback"
    "config/config.go|AppName[[:space:]]+= \"ZTARC\"|the Windows service name, config folder and tunnel adapter are all derived from AppName"
    "config/config.go|DefaultHostname[[:space:]]+= \"https://console.ztarc.io\"|the login window would default to the upstream vendor's hosted service"
    # Results of brand/patches/. `git apply` was found to exit 0 while changing
    # nothing — build/src sits inside this work tree, so it resolved paths
    # against the repository root — and every build since had shipped the cloud
    # button and the dead legal links. Nothing else noticed for days.
    "ui/login.go|serverURL: config.DefaultHostname|new accounts would not default to the ZTARC console"
    "ui/frontend/src/prefs/AddAccountSheet.tsx|useState\(\"https://console.ztarc.io\"\)|the server input would not default to the console"
    "ui/frontend/src/prefs/AboutTab.tsx|urls.source.*Source code \(AGPL-3\)|the About tab would not offer corresponding source"
    "ui/menu.go|item\(menuIDSource, \"Source code \(AGPL-3\)\"|the tray would not offer corresponding source"
    "ui/actions.go|openURL\(urlSource\)|the tray source link would not work"
    "ui/frontend/src/lib.ts|source: \"https://github.com/ztarc/ztarc-windows\"|the source link would have the wrong destination"
    "config/config.go|DefaultAutoUpdateChecksEnabled[[:space:]]+= false|the client would poll the unavailable update host"
    "ui/services.go|Version: version.Display\(\)|About would hide the ZTARC build identity"
    "ui/services.go|url == \"https://github.com/ztarc/ztarc-windows\"|the backend would block the About source link"
    "ui/state.go|Version:[[:space:]]+version.Display\(\)|the tray would hide the ZTARC build identity"
)

# And the other half of the same check: results that must be ABSENT. A patch
# that half-applies, or a deletion that stops matching, leaves the thing it was
# supposed to remove.
# Format: <path under build/src>|<extended regex that must NOT match>|<why it must go>
FORBIDDEN=(
    "ui/frontend/src/prefs/AddAccountSheet.tsx|Terms of Service|ZTARC has no terms page"
    "ui/frontend/src/prefs/AddAccountSheet.tsx|Radio|the server sheet would offer a hosted-service choice"
    "ui/frontend/src/prefs/AboutTab.tsx|Privacy Policy|ZTARC has no privacy page"
    "ui/frontend/src/onboarding/OnboardingWindow.tsx|urls.terms|onboarding would link to a nonexistent terms page"
    "ui/frontend/src/onboarding/OnboardingWindow.tsx|urls.privacy|onboarding would link to a nonexistent privacy page"
    "ui/menu.go|item\(menuIDInstallCLI|the tray would offer the upstream CLI"
    "ui/menu.go|item\(menuIDTerms|the tray would offer a nonexistent terms page"
    "ui/menu.go|item\(menuIDPrivacy|the tray would offer a nonexistent privacy page"
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


# UI branding is embedded now; reject missing or stale raster assets as well.
for pair in "word_mark_black.png:ztarc_logo_light.png" "word_mark_white.png:ztarc_logo_dark.png" "app_icon.png:app_icon.png" "app_icon.png:tray_icon.png"; do
    IFS=: read -r original staged <<< "$pair"
    cmp "$ROOT/brand/icons/$original" "$DST/ui/frontend/src/assets/$staged" || exit 1
done

echo "brand audit clean"
