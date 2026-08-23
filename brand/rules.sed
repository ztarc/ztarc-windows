# Turn upstream's Pangolin strings into ZTARC ones.
#
# Applied to every .go file in the staging tree by scripts/rebrand.sh, then
# checked by scripts/audit-brand.sh — anything these rules miss fails the build
# rather than shipping. Order matters: the URL rules must run before the general
# name rule, or "pangolin.net" becomes "ZTARC.net".

# ── URLs ──────────────────────────────────────────────────────────────────────
# ZTARC has no hosted service, so the cloud endpoint becomes the console. The
# documentation, terms and privacy pages do not exist yet; every one of them
# points at the marketing site until they do, and the links that would have
# 404'd are removed outright by brand/patches/.
s|https://app\.pangolin\.net|https://console.ztarc.io|g
s|https://docs\.pangolin\.net[^"'`]*|https://ztarc.io|g
s|https://pangolin\.net/[a-z]*|https://ztarc.io|g

# ── Identifiers that are not prose ────────────────────────────────────────────
s|pangolin-windows-%s|ztarc-windows-%s|g
s|"pangolin\.json"|"ztarc.json"|g
s|pangolin\.json|ztarc.json|g

# The version shown to a person is not the version the updater compares. See
# brand/overrides/version/version.go.
s|versionValueLabel\.SetText(version\.Number)|versionValueLabel.SetText(version.Display())|
s|fmt\.Sprintf("Version: %s", version\.Number)|fmt.Sprintf("Version: %s", version.Display())|

# Auto-update points at a host that does not exist yet; checking it would put a
# recurring error in front of every user. Re-enable in the same breath as
# standing up static.ztarc.io.
s|DefaultAutoUpdateChecksEnabled      = true|DefaultAutoUpdateChecksEnabled      = false|

# ── Ownership ─────────────────────────────────────────────────────────────────
s|Fossorial, Inc\.|ZTARC|g
s|Fossorial|ZTARC|g

# ── The name itself ───────────────────────────────────────────────────────────
# Skipping lines that mention the upstream module keeps import paths and the
# newt/olm dependencies intact — those are code, not branding.
/github\.com\/fosrl/! s|Pangolin|ZTARC|g
/github\.com\/fosrl/! s|pangolinDir|ztarcDir|g

# ── Internal identifiers ──────────────────────────────────────────────────────
# Named pipes and mutexes are not cosmetic: leaving upstream's names means a
# machine running both clients has two processes contending for one pipe. Log
# filenames move with them so a support bundle is unambiguous about which client
# wrote it.
s|pangolin-manager-cli-secrets|ztarc-manager-cli-secrets|g
s|pangolin-manager-ui-launch|ztarc-manager-ui-launch|g
s|pangolin-olm|ztarc-olm|g
s|"pangolin\.log"|"ztarc.log"|g
s|pangolin-%s\.log|ztarc-%s.log|g
s|pangolin-log-%s\.txt|ztarc-log-%s.txt|g
s|"pangolin-"|"ztarc-"|g
s|"pangolin-tunnel"|"ztarc-tunnel"|g
s|PANGOLIN_ALLOW_DEV_UPDATES|ZTARC_ALLOW_DEV_UPDATES|g
s|"ZTARC: pangolin-windows"|"ZTARC: ztarc-windows"|g
s|(pangolin format)|(upstream format)|g
s|'pangolin' command|'ztarc' command|g
