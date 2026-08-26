# ZTARC Windows Client

The Windows client for ZTARC, built from [`fosrl/windows`](https://github.com/fosrl/windows)
— the upstream Pangolin desktop client — pinned here as the `upstream/` submodule
and rebranded at build time.

## Licence

**AGPL-3.** This is a modified build of [`fosrl/windows`](https://github.com/fosrl/windows),
whose LICENSE states that files without a licence header are AGPL-3 — and no
file in that tree carries one. A derivative is therefore AGPL-3 too, and anyone
we give a binary to is entitled to the corresponding source: this repository at
the commit it was built from, plus `upstream/` at its recorded submodule commit.
The client links to it from the tray's More menu and from Preferences → About.

`LICENSE` is the licence, `NOTICE` records what was changed and when, and the
third-party inventory. Both are installed beside the executable, not merely kept
here — the person who runs the installer is the one entitled to them, and they
may never see a git repository.

One component is not free software. `wintun.dll` is WireGuard LLC's, licensed
and not sold, and may not be modified or reverse engineered. Redistribution is
permitted "insofar as the Software is distributed alongside other software that
uses the Software only via the Permitted API", which is what this client does.
It is aggregated with the program, not part of it; its licence ships beside it.

## Build

```bash
git submodule update --init
make build          # → build/ZTARC.exe
make version        # 0.14.0.1
make icons          # regenerate brand/icons from the logo (rarely needed)
make upstream-version
```

`make msi` exists but only runs on Windows — see Installer.

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

**The MSI is built by `.github/workflows/msi.yml` on a Windows runner, and it
cannot be built here.** That is not a preference. WiX ships as a .NET tool and
installs happily on Linux, but it is not cross-platform:

```csharp
// BundleValidator.GetCanonicalRelativePath
const string root = @"C:\";
var normalizedPath = Path.GetFullPath(root + relativePath);  // on Linux: "/cwd/C:\ZTARC"
if (normalizedPath.StartsWith(root))                         // → false, always
```

The drive letter is hardcoded, so **every** `Directory/@Name` is rejected as
"not a relative path" — verified against a minimal one-directory `.wxs`, in
v5, v6 and v7 alike. `ShortName` is not a way around it (`WIX0037` requires
`Name`). WiX prints *"The WiX Toolset only supports Windows. All behavior after
this point is undefined"* on startup and means it, which is also why building
the artifact that installs a service and a driver DLL onto other people's
machines with a knowingly-unsupported toolchain would be the wrong trade even if
the bug were worked around.

The CI job runs the same `scripts/` the Makefile does, so it cannot compile
something different from what a developer builds locally. It is also where
Authenticode signing will belong once there is a certificate. Until then
SmartScreen warns every person who runs the installer.

WiX is pinned to **5.0.2**, the last release before the
[Open Source Maintenance Fee](https://github.com/orgs/wixtoolset/discussions/9239).
v6 introduced the fee and v7 refuses to run until its EULA is accepted, which
for an organisation earning over $10k/yr means sponsoring the wixtoolset
project. Moving off 5.0.2 is a licensing decision to make deliberately, not a
version bump.

`wintun.dll` is deliberately not vendored. It is WireGuard LLC's signed binary
and it ships inside our installer, so it comes from its own source with its hash
checked — `scripts/fetch-wintun.sh`, run by CI and available locally as
`make wintun`. Upstream omits it for the same reason; `upstream/dll/` holds only
a README, and upstream's `.gitignore` covers `*.dll`, so fetching it there does
not dirty the submodule.

## Releasing

Testers should not need a GitHub account, and Actions artifacts require one and
expire after 90 days. Tagging publishes the installer as a release asset
instead — a permanent public URL on a public repository:

```bash
make version                      # 0.14.0.1 — version.go is the source of truth
git tag v0.14.0.1
git push --tags
```

The job **refuses a tag that disagrees with**
`brand/overrides/version/version.go`. A release whose page, filename and file
properties state three different numbers is worse than no release, and the
version already lives in exactly one file. To publish a fix on the same upstream
base, bump `Build` in `version.go` first, then tag the new number.

`SHA256SUMS` ships with every release. That is not housekeeping while the
installer is unsigned: Windows cannot name the publisher, so a checksum
published next to the source is the only means a tester has of establishing that
what they downloaded is what CI built. The release notes say so, and give the
`Get-FileHash` command to check against.

The release is cut with the `gh` CLI already present on the runner rather than a
third-party action. This is the step that hands a binary to other people, and
not the place to take on a supply-chain dependency for convenience. The workflow
token is read-only for branches and pull requests; only the release step writes,
and only on a tag.

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
| **MSI installer** | a Windows runner | `.github/workflows/msi.yml`. WiX does not run on Linux — see Installer above |
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
