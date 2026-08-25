# Build the ZTARC Windows client from the pinned upstream submodule.
#
# The executable cross-compiles here: the client is pure Go — no cgo, no Windows
# SDK — so `GOOS=windows GOARCH=amd64` produces a real PE32+ on Linux. Verify
# with `grep -rl 'import "C"' upstream` returning nothing before assuming
# otherwise.
#
# The *installer* does not. WiX only runs on Windows; see scripts/build-msi.sh
# for exactly why, and .github/workflows/msi.yml for where it runs instead.
#
# upstream/ is read, never written. Branding is applied to a staged copy under
# build/src by scripts/rebrand.sh, and scripts/audit-brand.sh refuses to build
# anything that still calls itself by the upstream name.
#
# Every target here is a thin call into scripts/, because the CI job runs the
# same scripts. Two copies of the build would drift; one cannot.

BUILD := build

.PHONY: build msi stage clean upstream-version icons wintun version

build: stage
	@./scripts/build-exe.sh
	@echo "→ $(BUILD)/ZTARC.exe  (ZTARC $$(. ./scripts/version.sh && ztarc_version brand/overrides/version/version.go), upstream $$(git -C upstream describe --tags --always))"

# Present so the target exists where you would look for it. It will not work
# here, and says so rather than failing obscurely three steps in.
msi: build
	@./scripts/build-msi.sh

stage:
	@./scripts/rebrand.sh
	@./scripts/audit-brand.sh

# Fetch WireGuard LLC's signed wintun.dll into upstream/dll/, hash-checked.
# Only needed to build the installer.
wintun:
	@./scripts/fetch-wintun.sh

# Regenerate brand/icons from the logo in ztarc-website. Committed output, so
# this is only needed when the logo itself changes.
icons:
	@./scripts/make-icons.sh

version:
	@. ./scripts/version.sh && ztarc_version brand/overrides/version/version.go

clean:
	@rm -rf $(BUILD)

# Which upstream commit this tree is pinned to.
upstream-version:
	@git -C upstream describe --tags --always
