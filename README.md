# ZTARC Windows Client

The Windows client for ZTARC, built from [`fosrl/windows`](https://github.com/fosrl/windows)
— the upstream Pangolin desktop client — pinned here as the `upstream/` submodule
and rebranded at build time.

## Build

```bash
git submodule update --init
make build          # → build/ZTARC.exe
make msi            # → build/ztarc-amd64-0.14.0.1.msi   (see Installer)
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

## Installer

`make build` produces an executable, not an installer, and running that
executable directly is not a supported deployment. Two things only the MSI does:

- **Registers the `ZTARCManager` service.** Creating a WinTun adapter needs
  administrator rights; without the service the tunnel cannot come up.
- **Places `icons/` next to the executable.** The tray icon and the login
  window's word mark are read from disk at runtime, not embedded — see below.

WiX v4+ is a .NET tool, so the MSI builds on Linux like everything else here:

```bash
sudo dnf install dotnet-sdk-8.0
dotnet tool install --global wix          # then put ~/.dotnet/tools on PATH
```

`upstream/dll/wintun.dll` is **not in the repo** and the build refuses to
continue without it. It is WireGuard LLC's signed binary and it ships inside our
installer, so take it from the source and check it:

```bash
curl -O https://www.wintun.net/builds/wintun-0.14.1.zip
sha256sum wintun-0.14.1.zip
# expect 07c256185d6ee3652e09fa55c0b673e2624b565e02c4b9091c79ca7d2f24ef51
unzip -j wintun-0.14.1.zip 'wintun/bin/amd64/wintun.dll' -d upstream/dll/
```

The output is named `ztarc-amd64-<version>.msi` because that is the pattern
`updater/versions.go` looks for, so releases are shaped correctly even while
auto-update is off.

Still missing: an Authenticode signature. Until there is a code-signing
certificate, SmartScreen warns every person who runs the installer.

## Why the tray icon is a file, not a resource

The icon compiled into `ZTARC.exe` is only the one Explorer shows for the file
itself. The **tray** icon, the two connection states, and the login window's word
mark are loaded at runtime from `GetIconsPath()` — upstream's
`%PROGRAMFILES%\<AppName>\icons`. Copy the `.exe` somewhere on its own and it
runs with a blank tray icon and an empty login header, which reads as a broken
build rather than a missing folder.

`brand/overrides/config/icons_path.go` makes it look beside the executable first.
For an installed client that is the same directory, so nothing about a real
installation changes; what it buys is that the build output can be copied to a
test VM as-is. Only image files are read through that path, never a DLL, so it is
not a search order that code can be planted in.

That substitution is one of the entries `scripts/audit-brand.sh` asserts must
still be present. A rule that stops matching leaves no upstream name behind to
find, so the forbidden-word check cannot catch it — the tree would compile, still
say ZTARC everywhere, and silently lose the fix.

## What still needs Windows

Compiling does not. Three later steps do:

| Step | Needs | Note |
|---|---|---|
| **Run / test** | real Windows | it creates a WinTun adapter and a service — nothing to emulate on Linux |
| **MSI installer** | nothing — builds here | `make msi`, once `wix` and `wintun.dll` are in place. See Installer above |
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
