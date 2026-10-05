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
make version        # 0.15.1.1
make icons          # regenerate brand/icons from the logo (rarely needed)
make upstream-version
```

`make msi` exists but only runs on Windows — see Installer.

Requires Go ≥ 1.26 and Node.js 22 with npm. The UI now uses Wails v3 and
React; `npm ci` installs the locked frontend dependencies, then TypeScript and
Vite build the assets embedded in the executable. The `production` build tag
turns off Wails' development server and developer tools.

The executable cross-compiles on Linux with `GOOS=windows GOARCH=amd64`.
No Windows machine or container is needed to compile it. The MSI and runtime
checks still require Windows. Wails generates the icon/manifest resources with
its expected resource IDs and VERSIONINFO in one resource object. The Wails
generator is pinned in `scripts/build-exe.sh` and runs without cgo on Linux.

```
build/ZTARC.exe: PE32+ executable for MS Windows 6.01 (GUI), x86-64
```

## How the rebranding works

`upstream/` is read, never written — so `git -C upstream status` stays clean and
moving to a new upstream release is a checkout, not a merge against our own
edits. Everything happens in a staged copy under `build/src`:

```
upstream/  ──stage──▶  build/src  ──▶  audit  ──▶  npm build → go build
             patches → sed → overrides → assets
```

Four layers, ordered from most to least tolerant of upstream drift:

| Layer | Where | For |
|---|---|---|
| `brand/patches/*.patch` | applied first, against pristine upstream | structural removals — the hosted-service choice, dead legal links, the upstream CLI installer entry |
| `brand/rules.sed` | Go and frontend source files | names, URLs, pipe and log identifiers |
| `brand/overrides/` | whole files | `version/version.go`, `updater/constants.go`, the manifest, the `.wxs` |
| `brand/icons/` | copied over `icons/` | embedded tray icons, app icon and wordmark |

**`scripts/audit-brand.sh` is the guard, and it is the reason this is safe.** A
sed rule that stops matching after an upstream bump fails silently — nothing
errors, and a ZTARC-named binary greets people under the old name. The audit
turns that into a failed build. Its exemptions cover dependency import paths
and the unreachable upstream CLI installer/UI; their reasons are written beside
them in the script.

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
| Sign-in | cloud button, or a server URL | direct login to `https://console.ztarc.io`, without a URL prompt |
| Links | docs / terms / privacy | Documentation only, `https://ztarc.io` |

The internal `ztarc onboarding` organization is hidden from the organization menu
and its count, and cannot be selected through the client menu.

The pipe and adapter names are not cosmetic: sharing them with an installed
Pangolin client would put two processes on one pipe.

## Versioning

The version lives in **one** place, `brand/overrides/version/version.go`, and is
read back out by `scripts/rebrand.sh` for the installer and the executable's
own properties, so those cannot drift from it.

```
Upstream = "0.15.1"   the fosrl/windows tag this is built from
Build    = "1"        ZTARC releases against that same upstream version
                      → version.Number  "0.15.1.1"   (updater, MSI, filenames)
                      → version.Display "0.15.1 (ztarc.1)"  (what a person sees)
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
executable directly is not a supported deployment. The MSI prepares the Windows installation:

- **Registers the `ZTARCManager` service.** Creating a WinTun adapter needs
  administrator rights; without the service the tunnel cannot come up.
- **Installs WebView2 when missing.** The Wails UI requires Microsoft’s
  Evergreen WebView2 Runtime. `scripts/fetch-webview2.ps1` downloads the
  bootstrapper from Microsoft and requires a valid Microsoft Authenticode
  signature before it is staged and bundled in the MSI.
- **Places `icons/` and licence notices next to the executable.** UI assets
  are also embedded, so copied executables retain their branding.

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
something different from what a developer builds locally. Release tag builds
use SSL.com eSigner to Authenticode sign and timestamp `ZTARC.exe` before WiX
packages it, then sign the MSI. CI verifies the publisher, timestamp, and the
EXE extracted from the MSI before producing checksums. Signing or verification
failure stops the release. SmartScreen can still warn while reputation develops.

PRs and ordinary pushes to `main` build unsigned artifacts. To test production
signing without publishing a release, choose Actions → msi → Run workflow on
`main` and enable **sign**. The `code-signing` environment must allow branch
`main` and tags `v*`, and contain secrets `SSL_USERNAME`, `SSL_PASSWORD`,
`SSL_CREDENTIAL_ID`, `SSL_TOTP_SECRET`, plus variable `SSL_CERT_SHA1` with the
production leaf certificate thumbprint (colon separators are accepted).
The `unsigned-ci` environment contains no signing credentials.

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
make version                      # 0.15.1.1 — version.go is the source of truth
git tag v0.15.1.1
git push --tags
```

The job **refuses a tag that disagrees with**
`brand/overrides/version/version.go`. A release whose page, filename and file
properties state three different numbers is worse than no release, and the
version already lives in exactly one file. To publish a fix on the same upstream
base, bump `Build` in `version.go` first, then tag the new number.

`SHA256SUMS` ships with every release and is computed after signing, so it
describes the final EXE and MSI. The release notes include the `Get-FileHash`
command for checking downloaded files against it.

The release is cut with the `gh` CLI already present on the runner rather than a
third-party action. This is the step that hands a binary to other people, and
not the place to take on a supply-chain dependency for convenience. The workflow
token is read-only during builds. A separate publish job has write permission
and runs only after a successful signed build from a release tag push.

## Embedded UI branding

Starting with upstream 0.15.1, tray icons are embedded from `icons/`, and the
onboarding wordmarks and app icon are bundled by Vite. `scripts/rebrand.sh`
copies the ZTARC assets before either build, and `scripts/audit-brand.sh` checks
both text branding and those assets against `brand/icons/`.

`brand/icons/app_icon.png` is the 256px frame of the committed connected icon.
`make icons` regenerates it along with the ICO files and wordmarks.

The installer continues to ship the existing icon files for compatibility.
`brand/overrides/config/icons_path.go` retains the adjacent-file fallback for
any code that still uses `GetIconsPath()`.

## What still needs Windows

Compiling does not. Three later steps do:

| Step | Needs | Note |
|---|---|---|
| **Run / test** | real Windows | it creates a WinTun adapter and a service — nothing to emulate on Linux |
| **MSI installer** | a Windows runner | `.github/workflows/msi.yml`. WiX does not run on Linux — see Installer above |
| **Authenticode verification** | Windows trust APIs | CI checks SSL.com signatures and the EXE packaged inside the MSI |

For running and testing, this machine already has `ghcr.io/dockur/windows` and
KVM — a real Windows VM inside a container, lighter to manage than VirtualBox.

## Auto-update is off

`static.ztarc.io` does not exist and no release signing key has been generated,
so `DefaultAutoUpdateChecksEnabled` ships `false` — a client polling a host that
does not resolve would put a recurring error in front of every user. Turning it
on means standing up that host, running `upstream/scripts/generate-keys.sh`
(needs `signify`), and pasting the public key into
`brand/overrides/updater/constants.go`.
