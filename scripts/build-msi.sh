#!/usr/bin/env bash
# Build the installer with WiX.
#
# This only runs on Windows. WiX is not cross-platform, whatever its NuGet
# packaging suggests: BundleValidator.GetCanonicalRelativePath hardcodes `C:\`
# and tests it with Path.GetFullPath, so on Linux every Directory/@Name is
# rejected as "not a relative path" — a minimal one-directory .wxs fails just as
# ours does. ShortName is not a way around it either; WIX0037 requires Name.
# WiX prints "The WiX Toolset only supports Windows. All behavior after this
# point is undefined" on startup, and it means it.
#
# So the MSI is built by .github/workflows/msi.yml on windows-latest, which is
# also where Authenticode signing will eventually belong.
#
# WiX is pinned to 5.0.2 deliberately: v6 introduced the Open Source Maintenance
# Fee and v7 refuses to run until its EULA is accepted, which for an organisation
# over $10k/yr means sponsoring the wixtoolset project. That is a licensing
# decision, not a build detail — moving off 5.0.2 is a choice to make on purpose.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# shellcheck source=scripts/version.sh
. "$ROOT/scripts/version.sh"
VERSION="$(ztarc_version "$ROOT/brand/overrides/version/version.go")"

# Refuse early and by name. If wix ever does land on PATH here, the failure it
# produces is "WIX0389: 'ZTARC' is not a relative path", which reads like a
# mistake in ztarc.wxs and is not one.
case "$(uname -s)" in
    MINGW* | MSYS* | CYGWIN* | Windows_NT) ;;
    *)
        echo "WiX only runs on Windows — see the comment at the top of this file." >&2
        echo "The MSI is built by .github/workflows/msi.yml." >&2
        exit 1
        ;;
esac

command -v wix >/dev/null || {
    echo "wix not found. On Windows:" >&2
    echo "  dotnet tool install --global wix --version 5.0.2" >&2
    exit 1
}

[ -f build/ZTARC.exe ] || {
    echo "build/ZTARC.exe is missing — run scripts/build-exe.sh first" >&2
    exit 1
}

[ -f build/src/dll/wintun.dll ] || {
    echo "build/src/dll/wintun.dll is missing." >&2
    echo "wintun.dll is WireGuard LLC's signed binary and ships inside our" >&2
    echo "installer, so it is fetched from wintun.net and hash-checked rather" >&2
    echo "than vendored. See scripts/fetch-wintun.sh." >&2
    exit 1
}

# Paths stay relative to the repository root: wix.exe is a native Windows
# program, and an absolute path produced by MSYS bash (/d/a/...) means nothing
# to it.
echo "Building installer..."
wix build build/src/ztarc.wxs \
    -arch x64 \
    -d ProjectDir=build/src \
    -d BuildDir=build \
    -o "build/ztarc-amd64-$VERSION.msi"

echo "→ build/ztarc-amd64-$VERSION.msi"
