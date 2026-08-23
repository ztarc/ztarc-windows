//go:build windows

package version

// The ZTARC client tracks upstream's version and adds a build counter of its
// own, because the two move independently: a rebranding fix can ship without
// fosrl/windows changing at all.
//
// Number carries four components — upstream's three plus our counter — and that
// is deliberate. updater/versions.go compares versions component by component
// with ParseUint, so it reads four as happily as three. What it is NOT is an MSI
// upgrade trigger: Windows Installer compares only the first three fields of
// ProductVersion, so bumping Build alone will not make a new MSI replace an
// installed one. That is a limit of MSI, not of this numbering; a ZTARC-only fix
// has to be uninstalled and reinstalled, or wait for upstream to move.
const (
	// Upstream is the fosrl/windows tag this build is based on. It must match
	// the commit the upstream/ submodule is pinned to.
	Upstream = "0.14.0"
	// Build counts ZTARC releases made against that same upstream version.
	Build = "1"

	Number = Upstream + "." + Build
)

// Display is what a person should see: the upstream version they can look up,
// with our build marked separately rather than hidden in a fourth digit nobody
// would recognise.
func Display() string {
	return Upstream + " (ztarc." + Build + ")"
}
