# Build the ZTARC Windows client from the pinned upstream submodule.
#
# The whole thing is pure Go — no cgo, no Windows SDK — so this cross-compiles
# on Linux and the .exe never needs a Windows machine to exist. Verify with
# `grep -rl 'import "C"' upstream` returning nothing before assuming otherwise.
#
# upstream/ is read, never written. Branding is applied to a staged copy under
# build/src by scripts/rebrand.sh, and scripts/audit-brand.sh refuses to build
# anything that still calls itself by the upstream name.

BINARY := ZTARC.exe
BUILD  := build
SRC    := $(BUILD)/src

# Read back out of version.go rather than repeated here — the same reason
# scripts/rebrand.sh does it. `Number` is a concatenation expression, not a
# literal, so the two halves are extracted and rejoined.
VERSION_GO := brand/overrides/version/version.go
VERSION := $(shell sed -n 's/.*Upstream[[:space:]]*=[[:space:]]*"\([0-9.]*\)".*/\1/p' $(VERSION_GO)).$(shell sed -n 's/.*Build[[:space:]]*=[[:space:]]*"\([0-9]*\)".*/\1/p' $(VERSION_GO))

.PHONY: build msi stage clean upstream-version icons

build: stage
	@echo "Compiling resources (icon, manifest, version)..."
	@cd $(SRC) && go run github.com/josephspurrier/goversioninfo/cmd/goversioninfo@latest \
		-o resource.syso versioninfo.json
	@echo "Building Windows executable (GUI mode)..."
	@cd $(SRC) && GOOS=windows GOARCH=amd64 \
		go build -trimpath -ldflags="-s -w -H windowsgui" -o ../$(BINARY) .
	@echo "→ $(BUILD)/$(BINARY)  (ZTARC $(VERSION), upstream $$(git -C upstream describe --tags --always))"

# The installer. Everything the client needs at runtime lives in Program Files —
# the icons especially, which are read from disk, not embedded (see
# brand/overrides/config/icons_path.go) — plus the Windows service that lets the
# tunnel create a WireGuard adapter at all. A bare .exe has neither.
#
# WiX v4+ is a .NET tool, so this builds on Linux like everything else here.
# Two things must exist first, and neither is something the build can fetch:
#
#   dotnet tool install --global wix        (needs dotnet-sdk-8.0 or newer)
#   upstream/dll/wintun.dll                 from https://www.wintun.net/
#
# wintun.dll is absent from the upstream repo by design — it is WireGuard LLC's
# signed binary, and it ends up in Program Files, so fetch it from wintun.net
# and check its hash rather than copying it off whichever machine happens to
# have one.
#
# The filename is the one updater/versions.go looks for (msiArchPrefix +
# version + msiSuffix), so releases are already shaped correctly even though
# auto-update ships disabled.
msi: build
	@command -v wix >/dev/null || { \
		echo "wix not found. Install it with:"; \
		echo "  sudo dnf install dotnet-sdk-8.0"; \
		echo "  dotnet tool install --global wix   # then add ~/.dotnet/tools to PATH"; \
		exit 1; }
	@test -f $(SRC)/dll/wintun.dll || { \
		echo "$(SRC)/dll/wintun.dll is missing."; \
		echo "Download the amd64 wintun.dll from https://www.wintun.net/,"; \
		echo "verify its hash, and place it at upstream/dll/wintun.dll."; \
		exit 1; }
	@echo "Building installer..."
	@wix build $(SRC)/ztarc.wxs \
		-arch x64 \
		-d ProjectDir=$(CURDIR)/$(SRC) \
		-d BuildDir=$(CURDIR)/$(BUILD) \
		-o $(BUILD)/ztarc-amd64-$(VERSION).msi
	@echo "→ $(BUILD)/ztarc-amd64-$(VERSION).msi"

stage:
	@./scripts/rebrand.sh
	@./scripts/audit-brand.sh

# Regenerate brand/icons from the logo in ztarc-website. Committed output, so
# this is only needed when the logo itself changes.
icons:
	@./scripts/make-icons.sh

clean:
	@rm -rf $(BUILD)

# Which upstream commit this tree is pinned to.
upstream-version:
	@git -C upstream describe --tags --always
