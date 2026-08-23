# ZTARC Windows Client

The Windows client for ZTARC, built from [`fosrl/windows`](https://github.com/fosrl/windows)
— the upstream Pangolin desktop client — pinned here as the `upstream/` submodule
and rebranded at build time.

## Build

```bash
git submodule update --init
make build          # → build/ZTARC.exe
make icons          # regenerate brand/icons from the logo (rarely needed)
make upstream-version
```

Requires Go ≥ 1.25 and nothing else. **No Windows machine, VM, or Windows
container is involved**: the client is pure Go (no cgo — the Win32 API is reached
through `tailscale/walk` and `golang.org/x/sys/windows`, both pure Go), so
`GOOS=windows GOARCH=amd64` cross-compiles it on Linux. About 25 seconds from a
cold module cache. Rebuilds are byte-identical.

```
build/ZTARC.exe: PE32+ executable for MS Windows 6.01 (GUI), x86-64
```

## How the rebranding works

`upstream/` is read, never written — so `git -C upstream status` stays clean and
moving to a new upstream release is a checkout, not a merge against our own
edits. Everything happens in a staged copy under `build/src`:

```
upstream/  ──stage──▶  build/src  ──▶  audit  ──▶  go build
             patches → sed → overrides → assets
```

Four layers, ordered from most to least tolerant of upstream drift:

| Layer | Where | For |
|---|---|---|
| `brand/patches/*.patch` | applied first, against pristine upstream | structural removals — the hosted-service button, dead legal links, the upstream CLI installer entry |
| `brand/rules.sed` | every `.go` file | names, URLs, pipe and log identifiers |
| `brand/overrides/` | whole files | `version/version.go`, `updater/constants.go`, the manifest, the `.wxs` |
| `brand/icons/` | copied over `icons/` | tray icons and wordmark |

**`scripts/audit-brand.sh` is the guard, and it is the reason this is safe.** A
sed rule that stops matching after an upstream bump fails silently — nothing
errors, and a ZTARC-named binary greets people under the old name. The audit
turns that into a failed build. It has exactly two exemptions, each with its
reason written beside it in the script.

Two things it deliberately does not touch:

- `github.com/fosrl/newt` and `.../olm` — dependencies, not branding.
- `PANGOLIN_TEST_REQ` / `PANGOLIN_TEST_RSP` inside newt. These are hole-punch
  probe magic bytes that both ends of the wire must agree on. Renaming them
  would break connectivity, not rebrand anything.

## What changed for a user

| | Upstream | ZTARC |
|---|---|---|
| Executable | `Pangolin.exe` | `ZTARC.exe` |
| Service | `PangolinManager` | `ZTARCManager` |
| Config | `%LOCALAPPDATA%\Pangolin\pangolin.json` | `%LOCALAPPDATA%\ZTARC\ztarc.json` |
| Tunnel adapter | `Pangolin` | `ZTARC` |
| Named pipes | `\\.\pipe\pangolin-*` | `\\.\pipe\ztarc-*` |
| Log | `pangolin.log` | `ztarc.log` |
| Sign-in | cloud button, or a server URL | server URL only, prefilled `https://console.ztarc.io` |
| Links | docs / terms / privacy | Documentation only, `https://ztarc.io` |

The pipe and adapter names are not cosmetic: sharing them with an installed
Pangolin client would put two processes on one pipe.

## Versioning

The version lives in **one** place, `brand/overrides/version/version.go`, and is
read back out by `scripts/rebrand.sh` for the installer and the executable's
own properties, so those cannot drift from it.

```
Upstream = "0.14.0"   the fosrl/windows tag this is built from
Build    = "1"        ZTARC releases against that same upstream version
                      → version.Number  "0.14.0.1"   (updater, MSI, filenames)
                      → version.Display "0.14.0 (ztarc.1)"  (what a person sees)
```

Four components on purpose: `updater/versions.go` compares component by
component with `ParseUint`, so it reads four as happily as three.

**Windows Installer, however, compares only the first three fields of
ProductVersion.** Bumping `Build` alone will not make a new MSI replace an
installed one — a ZTARC-only fix has to be uninstalled and reinstalled, or wait
for upstream to move. That is a limit of MSI, not of this numbering.

`Upstream` must match the tag `upstream/` is pinned to. To move:

```bash
git -C upstream fetch --tags && git -C upstream checkout <tag>
# update Upstream in brand/overrides/version/version.go, reset Build to "1"
make build          # the audit and the patches will say if anything drifted
git add upstream brand/overrides/version/version.go && git commit
```

## What still needs Windows

Compiling does not. Three later steps do:

| Step | Needs | Note |
|---|---|---|
| **Run / test** | real Windows | it creates a WinTun adapter and a service — nothing to emulate on Linux |
| **MSI installer** | WiX Toolset | `brand/overrides/ztarc.wxs` is ready; `dll/wintun.dll` is **not in the repo** and must be fetched from wintun.net first |
| **Authenticode signing** | a code-signing certificate | unsigned, SmartScreen warns every user |

For running and testing, this machine already has `ghcr.io/dockur/windows` and
KVM — a real Windows VM inside a container, lighter to manage than VirtualBox.

## Auto-update is off

`static.ztarc.io` does not exist and no release signing key has been generated,
so `DefaultAutoUpdateChecksEnabled` ships `false` — a client polling a host that
does not resolve would put a recurring error in front of every user. Turning it
on means standing up that host, running `upstream/scripts/generate-keys.sh`
(needs `signify`), and pasting the public key into
`brand/overrides/updater/constants.go`.
