# ZTARC Windows Client

The Windows client for ZTARC, built from [`fosrl/windows`](https://github.com/fosrl/windows)
— the Pangolin desktop client — which is pinned here as the `upstream/` submodule.

Rebranding happens in this repository, never inside `upstream/`. Keeping the
submodule pristine is what makes an upstream bump a one-line change instead of a
merge conflict against our own edits.

## Build

```bash
git submodule update --init
make build          # → build/Pangolin.exe
make upstream-version
```

Requires Go ≥ 1.25 and nothing else. **No Windows machine, VM, or Windows
container is involved**: the client is pure Go (no cgo — the Win32 API is reached
through `tailscale/walk` and `golang.org/x/sys/windows`, both pure Go), so
`GOOS=windows GOARCH=amd64 go build` cross-compiles it on Linux. A full build
from a cold module cache takes about 25 seconds; an incremental one, a few.

The result is a genuine PE32+ GUI executable:

```
build/Pangolin.exe: PE32+ executable for MS Windows 6.01 (GUI), x86-64
```

## What still needs Windows

Compiling does not. Three later steps do:

| Step | Needs | Note |
|---|---|---|
| **Run / test** | real Windows | it creates a WinTun adapter and a service — nothing to emulate on Linux |
| **MSI installer** | WiX Toolset | upstream ships `pangolin.wxs` and `scripts/build-msi.bat` |
| **Authenticode signing** | a code-signing certificate | unsigned, SmartScreen will warn every user |

For running and testing, this machine already has `ghcr.io/dockur/windows` and
KVM, which is a real Windows VM inside a container — adequate, and lighter to
manage than VirtualBox.

## Upstream

Pinned at `0.14.0`. To move:

```bash
git -C upstream fetch --tags && git -C upstream checkout <tag>
git add upstream && git commit
```
