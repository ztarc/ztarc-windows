#!/usr/bin/env bash
# The version, read out of the one file that declares it.
#
# Sourced by rebrand.sh and build-msi.sh so the installer filename, the MSI's
# ProductVersion and the executable's own properties cannot drift apart.
# `Number` in version.go is a concatenation expression rather than a literal, so
# the two halves are extracted and rejoined here.
ztarc_version() {
    local file="$1" upstream build
    upstream="$(sed -n 's/.*Upstream[[:space:]]*=[[:space:]]*"\([0-9.]*\)".*/\1/p' "$file")"
    build="$(sed -n 's/.*Build[[:space:]]*=[[:space:]]*"\([0-9]*\)".*/\1/p' "$file")"
    [ -n "$upstream" ] && [ -n "$build" ] || {
        echo "cannot read version from $file" >&2
        return 1
    }
    echo "$upstream.$build"
}
