//go:build windows

package updater

// Where the client looks for its own updates.
//
// None of this is live yet: static.ztarc.io does not exist, and no release
// signing key has been generated. Until both are true, config.go ships with
// DefaultAutoUpdateChecksEnabled set to false — a client polling a host that
// does not resolve would put a recurring error in front of every user.
//
// To turn it on: run upstream/scripts/generate-keys.sh (needs signify), paste
// the public key below, then follow upstream/BUILD_STEPS.md for the manifest
// and signature. The secret key never enters this repository.
const (
	// releasePublicKeyBase64 verifies the Ed25519 signature on the update
	// manifest. Empty on purpose — an update cannot be verified, so it must not
	// be applied.
	releasePublicKeyBase64 = ""
	// updateServerHost is the hostname of the update server.
	updateServerHost = "static.ztarc.io"
	// updateServerPort is the port number for the update server.
	updateServerPort = 443
	// updateServerUseHttps indicates whether to use HTTPS.
	updateServerUseHttps = true
	// latestVersionPath is the path to the latest version signature file.
	latestVersionPath = "/windows-client/latest.sig"
	// msiArchPrefix is the prefix for MSI filenames (use %s for architecture).
	msiArchPrefix = "ztarc-%s-"
	// msiSuffix is the suffix for MSI filenames.
	msiSuffix = ".msi"
)
