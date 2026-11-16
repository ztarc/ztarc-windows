# Windows 0.16.0.1 candidate validation

Date: 16 November 2026. Status: source candidate verified locally; release gates open.
Reference: `ztarc-console/deploy/pangolin-1.26.0-production-upgrade-plan.md`, B3/B4.

| Requirement | Evidence / status |
|---|---|
| Upstream repository and version | `.gitmodules`: `fosrl/windows-linux`; gitlink `b805ba7fe28bfa6e3e372a581ee61bb208e0d7cf`, tag `windows-0.16.0` |
| Source and package version | `make version`: `0.16.0.1`; rebrand stamps EXE VERSIONINFO and MSI source from that value |
| Module and toolchain | Module remains `github.com/fosrl/windows`; Go 1.26; Wails beta.26; Node 22 |
| Embedded libraries | `go version -m build/ZTARC.exe`: Newt 1.19.0, Olm 1.10.2; Olm version linker flag retained |
| Branding and identities | `make build` passes branding, icon, console login, onboarding filter and service/config/pipe audit; upstream remains clean |
| Updater | Patch disables effective settings plus check/load/install entry points; audit rejects a deliberately re-enabled check; upstream constants override contains all target fields |
| Local build | `make build` passes frontend typecheck/Vite and Windows amd64 cross-compilation; `file` confirms PE32+ GUI x86-64 |
| CI tag lookup | Windows build explicitly fetches `windows-${version%.*}` before staging, because submodule checkout may omit tags |
| Dependency audit | `npm audit --omit=dev`: zero findings; full audit: two high findings in Vite 8.3.1/source-map-js 1.2.1 build tooling; remediation/review pending |
| Signing and MSI | Pending manual signed Windows workflow; no tag pushed or release published |
| W01/W02/W03 | Pending real Windows clean install, upgrade, reboot, network and identity recovery acceptance |
| Old MSI and downgrade | Pending retained signed 0.15.1.1 MSI and tested uninstall/reinstall with endpoint checkpoint |
| Distribution B4 / D01 | Pending console pin/cache/download rollback verification before publication |

The local EXE is unsigned development output, not an installer or released artifact.
Its current SHA256 is `71cca51973350be416f1ba2139809a2dae10d9afa8dc6e7879a11f7d386c4fba`.
Signing changes the hash; release SHA256SUMS must be generated after signing.

No Windows container is running on this host (`docker ps` is empty), and
`/dev/kvm` is absent. Windows runtime acceptance cannot be inferred from the
cross-build. Follow the Windows checklist in README before publication.
