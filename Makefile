# Build the Windows client from the pinned upstream submodule.
#
# The whole thing is pure Go — no cgo, no Windows SDK — so this cross-compiles
# on Linux and the .exe never needs a Windows machine to exist. Verify with
# `grep -rl 'import "C"' upstream` returning nothing before assuming otherwise.
#
# Output is copied here rather than built here: upstream's Makefile writes into
# its own tree, and keeping the submodule pristine is what lets `git status`
# stay honest about which commit we are actually shipping.

UPSTREAM := upstream
BUILD    := build
BINARY   := Pangolin.exe

.PHONY: build clean upstream-version

build:
	@$(MAKE) -C $(UPSTREAM) build
	@mkdir -p $(BUILD)
	@cp $(UPSTREAM)/$(BUILD)/$(BINARY) $(BUILD)/$(BINARY)
	@echo "→ $(BUILD)/$(BINARY)  ($$(git -C $(UPSTREAM) describe --tags --always))"

clean:
	@$(MAKE) -C $(UPSTREAM) clean
	@rm -rf $(BUILD)

# Which upstream commit this tree is pinned to.
upstream-version:
	@git -C $(UPSTREAM) describe --tags --always
