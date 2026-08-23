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

.PHONY: build stage clean upstream-version icons

build: stage
	@echo "Compiling resources (icon, manifest, version)..."
	@cd $(SRC) && go run github.com/josephspurrier/goversioninfo/cmd/goversioninfo@latest \
		-o resource.syso versioninfo.json
	@echo "Building Windows executable (GUI mode)..."
	@cd $(SRC) && GOOS=windows GOARCH=amd64 \
		go build -trimpath -ldflags="-s -w -H windowsgui" -o ../$(BINARY) .
	@echo "→ $(BUILD)/$(BINARY)  (ZTARC $$(sed -n 's/.*Upstream[[:space:]]*=[[:space:]]*"\([0-9.]*\)".*/\1/p' brand/overrides/version/version.go).$$(sed -n 's/.*Build[[:space:]]*=[[:space:]]*"\([0-9]*\)".*/\1/p' brand/overrides/version/version.go), upstream $$(git -C upstream describe --tags --always))"

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
