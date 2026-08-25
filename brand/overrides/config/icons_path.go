//go:build windows

package config

import (
	"os"
	"path/filepath"
)

// resolveIconsPath finds the directory holding icon-*.ico and the word marks.
//
// Upstream looks in exactly one place, %PROGRAMFILES%\<AppName>\icons, and the
// tray icon is loaded from disk at runtime rather than embedded in the binary
// (ui/iconprovider.go, ui/tray.go). Copying the .exe somewhere by itself
// therefore produces an application with a blank tray icon and a login window
// missing its word mark — which reads as a broken build rather than as a
// missing folder, and cost an afternoon to diagnose once already.
//
// So look beside the executable first. For an installed client the two answers
// are the same directory, because the MSI puts ZTARC.exe and icons\ side by
// side under Program Files; nothing about a real installation changes. What it
// buys is that a plain copy of the build output works, which is how the client
// actually gets tested.
//
// Only image files are read through this path — never a DLL or anything
// executable — so it does not become a search-order that code can be planted in.
func resolveIconsPath() string {
	if exe, err := os.Executable(); err == nil {
		beside := filepath.Join(filepath.Dir(exe), "icons")
		if info, err := os.Stat(beside); err == nil && info.IsDir() {
			return beside
		}
	}
	return filepath.Join(os.Getenv("PROGRAMFILES"), AppName, "icons")
}
